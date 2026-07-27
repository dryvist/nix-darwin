# Give the MLX cluster's executables a code-signing identity that SURVIVES a
# rebuild, so their macOS privacy grants stop evaporating.
#
# THE PROBLEM, measured on 2026-07-25:
#
#   nix bash:    designated => cdhash H"51837d1122ccaa5f7809f9b321679906f1168608"
#   Apple bash:  designated => identifier "com.apple.bash" and anchor apple
#
# An ad-hoc signature's designated requirement IS the content hash, so every
# rebuild produces an executable macOS has never seen and every TCC grant made
# against the old one is void. Apple's binaries key on identifier + authority
# instead, which is why their grants persist across OS updates.
#
# A self-signed certificate gives our executables the second shape:
#
#   designated => identifier "dev.jacobpevans.mlx-cluster.<name>"
#                 and certificate leaf = H"<cert hash>"
#
# — independent of content. Re-signing after a rebuild preserves the identity,
# so ONE Local Network grant holds forever.
#
# What this cost before the fix: the Studio's cluster agents were denied Local
# Network, which macOS surfaces as `No route to host` rather than a permission
# error. The cluster could never self-form after a cold boot; it only ever
# worked hand-held from ssh, because an ssh session inherits sshd-session's
# grant. Four of five nix bash store paths were granted and the one the scripts
# actually named was not — and all five render as plain "bash" in System
# Settings, so the list is unusable for telling them apart.
#
# The identity is created once per host by an operator (it needs a keychain
# unlock and a trust decision, neither of which is automatable). Until then this
# script is a no-op that says so — it must never fail activation, because a
# missing signing identity is a normal state on a host that has not been set up
# yet, not an error.
set -o nounset

identity="$MLX_SIGNING_IDENTITY"
stable_dir="$MLX_SIGNING_STABLE_DIR"
sweep_roots="$MLX_SIGN_SWEEP_ROOTS"

# Shared prefix for every identifier this script mints (sign_at appends the
# per-target name). One definition used both when signing and, below, when
# sweeping for stale identities — so the two can never disagree about what
# "ours" means.
identifier_prefix="dev.jacobpevans.mlx-cluster."

if ! /usr/bin/security find-identity -v -p codesigning 2> /dev/null | grep -qF "$identity"; then
  echo "mlx-signing: no '$identity' code-signing identity on this host — skipping."
  echo "mlx-signing: create it once (see hosts/common/mlx-cluster-signing.nix), then re-run darwin-rebuild."
  exit 0
fi

mkdir -p "$stable_dir"

signed=0
skipped=0
# Space-separated, like the spec lists above: every real path we (re)sign
# this run, so the sweep below can skip them rather than fight itself.
current_targets=""

sign_at() {
  # $1 = path to sign in place, $2 = identifier suffix
  local target="$1" name="$2"
  if [ ! -e "$target" ]; then
    echo "mlx-signing: $name not present at $target — skipping"
    skipped=$((skipped + 1))
    return 0
  fi
  # --force because we re-sign the same path every activation; that is the whole
  # point (new content, same identity).
  #
  # Deliberately NOT --options runtime. The hardened runtime enables library
  # validation, which refuses to load any library whose Team ID differs from the
  # signing process. The uv-cached Python we sign here loads mlx's
  # core.cpython-*-darwin.so, which is ad-hoc/linker-signed with no Team ID — so
  # a hardened Python cannot load mlx at all:
  #   ImportError: dlopen(...mlx/core...so): code signature not valid for use in
  #   process: mapping process and mapped file (non-platform) have different
  #   Team IDs
  # That broke every rank start until it was found (drill 2026-07-25, FINDING 3).
  # The hardened runtime buys nothing here: this signature exists solely to give
  # the binary a STABLE IDENTITY so a macOS TCC grant survives rebuilds, and the
  # designated requirement that TCC keys on is
  # `identifier "..." and certificate leaf = H"..."` — set by the identity and
  # identifier below, not by the runtime flag.
  if /usr/bin/codesign --force --sign "$identity" \
    --identifier "$identifier_prefix$name" \
    "$target" 2> /dev/null; then
    echo "mlx-signing: signed $name"
    signed=$((signed + 1))
    current_targets="$current_targets $target"
  else
    # Never fatal: a signing failure leaves the previous signature in place and
    # the operator can still grant the old identity. Failing activation here
    # would be strictly worse than a stale signature.
    echo "mlx-signing: WARN could not sign $name at $target" >&2
    skipped=$((skipped + 1))
  fi
}

# 1. Executables that live at a writable, stable path already (the uv-managed
#    CPython the rank runs under). Signed in place — no copy, no indirection.
for spec in $MLX_SIGN_IN_PLACE; do
  name="${spec%%=*}"
  pattern="${spec#*=}"
  # Globbed deliberately: uv's interpreter path carries its CPython version, so
  # a pinned literal would silently stop matching on the next uv bump and the
  # rank would quietly lose its identity again. Unmatched globs expand to
  # themselves, which sign_at reports as "not present" rather than failing.
  matched=0
  for path in $pattern; do
    [ -e "$path" ] || continue
    matched=$((matched + 1))
    # Resolve first: uv's entry is a symlink into its python store, and the
    # signature has to land on the real file.
    real="$(/usr/bin/readlink -f "$path" 2> /dev/null || echo "$path")"
    sign_at "$real" "$name"
  done
  if [ "$matched" -eq 0 ]; then
    echo "mlx-signing: nothing matched $pattern for $name — skipping"
    skipped=$((skipped + 1))
  fi
done

# 2. Executables in the read-only nix store. Copied out to a stable path first,
#    because the store cannot be signed and its paths change every rebuild
#    anyway — the copy is what gets a durable identity.
for spec in $MLX_SIGN_COPIES; do
  name="${spec%%=*}"
  src="${spec#*=}"
  dst="$stable_dir/$name"
  if [ ! -e "$src" ]; then
    echo "mlx-signing: source for $name missing ($src) — skipping"
    skipped=$((skipped + 1))
    continue
  fi
  # Copy only when the content differs, so an unchanged rebuild does not
  # invalidate a warm signature for no reason.
  if [ ! -e "$dst" ] || ! /usr/bin/cmp -s "$src" "$dst"; then
    /bin/cp -f "$src" "$dst" || {
      echo "mlx-signing: WARN could not stage $name" >&2
      skipped=$((skipped + 1))
      continue
    }
    /bin/chmod u+w "$dst"
  fi
  sign_at "$dst" "$name"
done

# 3. Sweep: a target that moves (e.g. the pinned CPython minor bumps) leaves
#    its old file still carrying our identity, still satisfying the TCC grant
#    scoped to that identity, on an unbounded timeline nothing else clears.
#    Never --remove-signature (silently SIGKILLed on Apple Silicon) — ad-hoc
#    re-sign instead, which replaces the identity without leaving the file
#    unsigned. Scoped three ways: only the configured roots, only their
#    bin/ directories (the only shape sign_at has ever written into — a
#    recursive find over a whole Python tree costs thousands of stat calls
#    for zero payoff), and only a file whose OWN designated requirement
#    already names our prefix, so this can only un-brand what we branded.
#
#    Resolve symlinks BEFORE comparing or signing: bin/python and bin/python3
#    are aliases of bin/python3.14 in every uv-managed CPython, and codesign
#    follows a symlink to its real target regardless of which name it is
#    given. Comparing raw glob paths against current_targets (real paths,
#    same as sign_at above) would miss that "bin/python" IS the just-signed
#    target under another name — and then ad-hoc-resign it right back out,
#    undoing step 1 in the same run (caught by testing before this shipped).
stripped=0
for root in $sweep_roots; do
  [ -d "$root" ] || continue
  for file in "$root"/*/bin/*; do
    [ -f "$file" ] || continue
    real="$(/usr/bin/readlink -f "$file" 2> /dev/null || echo "$file")"
    case " $current_targets " in
      *" $real "*) continue ;;
    esac
    req="$(/usr/bin/codesign -d -r- "$real" 2> /dev/null || true)"
    # Scripts report a second, irrelevant "identifier" for their interpreter
    # (host => identifier "com.apple.sh"); only the designated clause is ours.
    designated="${req#*designated => }"
    case "$designated" in
      *"identifier \"$identifier_prefix"*)
        old_id="${designated#*identifier \"}"
        old_id="${old_id%%\"*}"
        if /usr/bin/codesign --force --sign - "$real" 2> /dev/null; then
          echo "mlx-signing: stripped stale identity ($old_id) from $real"
          stripped=$((stripped + 1))
        else
          echo "mlx-signing: WARN could not strip stale identity from $real" >&2
        fi
        ;;
    esac
  done
done
echo "mlx-signing: $stripped stale identities stripped"

echo "mlx-signing: $signed signed, $skipped skipped"

# Report the resulting requirement for one signed artifact, so an operator can
# see at a glance whether the identity is content-independent (good) or still a
# bare cdhash (means the signing silently did not take).
first="${MLX_SIGN_COPIES%% *}"
if [ -n "$first" ] && [ -e "$stable_dir/${first%%=*}" ]; then
  echo "mlx-signing: designated requirement now:"
  /usr/bin/codesign -d -r- "$stable_dir/${first%%=*}" 2>&1 | grep designated || true
fi
exit 0
