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

if ! /usr/bin/security find-identity -v -p codesigning 2> /dev/null | grep -qF "$identity"; then
  echo "mlx-signing: no '$identity' code-signing identity on this host — skipping."
  echo "mlx-signing: create it once (see hosts/common/mlx-cluster-signing.nix), then re-run darwin-rebuild."
  exit 0
fi

mkdir -p "$stable_dir"

signed=0
skipped=0

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
  if /usr/bin/codesign --force --sign "$identity" \
    --identifier "dev.jacobpevans.mlx-cluster.$name" \
    --options runtime "$target" 2> /dev/null; then
    echo "mlx-signing: signed $name"
    signed=$((signed + 1))
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
