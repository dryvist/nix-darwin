# Durable code-signing identity for the MLX cluster executables
#
# WHY THIS EXISTS
#
# macOS keys a TCC grant (Local Network, and friends) to a binary's code-signing
# identity. Measured 2026-07-25:
#
#   nix bash:    designated => cdhash H"51837d1122ccaa5f7809f9b321679906f1168608"
#   Apple bash:  designated => identifier "com.apple.bash" and anchor apple
#
# An ad-hoc signature's designated requirement IS the content hash. So every
# nixpkgs bump produces an executable macOS has never seen, and every grant made
# against the previous one is void — the permission appears to "reset on every
# rebuild". Apple's binaries key on identifier + authority, which is why their
# grants survive OS updates.
#
# Signing with a self-signed certificate gives ours the same shape:
#
#   designated => identifier "dev.jacobpevans.mlx-cluster.<name>"
#                 and certificate leaf = H"<cert hash>"
#
# — content-independent. Re-signing after a rebuild keeps the identity, so ONE
# Local Network grant holds for good.
#
# WHAT IT COST WITHOUT THIS
#
# The Studio's cluster launchd agents were denied Local Network. macOS surfaces
# that as `No route to host`, never as a permission error, and the watcher's
# already-down branch was silent — so the cluster sat unable to form for 65
# minutes while `launchctl print` reported runs=115, last exit code 0. It only
# ever worked hand-held from ssh, because an ssh session inherits
# sshd-session's grant. Four of the five nix `bash` store paths on that host
# were granted and the one the scripts actually named was not; all five render
# as plain "bash" in System Settings, so the UI cannot tell them apart.
#
# ONE-TIME OPERATOR SETUP (per host)
#
# The identity needs a keychain unlock and a trust decision, neither of which a
# session can perform. Run once, in Terminal:
#
#   D=~/Library/Application\ Support/mlx-cluster/signing; mkdir -p "$D" && cd "$D" && \
#   openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 -nodes \
#     -subj "/CN=mlx-cluster-signing" -addext "extendedKeyUsage=codeSigning" \
#     -addext "basicConstraints=critical,CA:false" && \
#   openssl pkcs12 -export -out b.p12 -inkey key.pem -in cert.pem -passout pass:mlxcluster \
#     -name mlx-cluster-signing -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1 && \
#   security import b.p12 -k ~/Library/Keychains/login.keychain-db -P mlxcluster \
#     -T /usr/bin/codesign -A && \
#   security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
#     ~/Library/Keychains/login.keychain-db && \
#   security add-trusted-cert -r trustRoot -p codeSign \
#     -k ~/Library/Keychains/login.keychain-db cert.pem && \
#   rm -f b.p12 && security find-identity -v -p codesigning | grep mlx-cluster
#
# The legacy PKCS12 algorithms are required: OpenSSL 3 defaults to AES-256 +
# SHA-256, which macOS `security import` rejects with "MAC verification failed".
# The private key never leaves the host, and the certificate is trusted for code
# signing ONLY, in the user's login keychain rather than the system domain.
#
# Until that runs, the activation step is a no-op that says so. A host without
# the identity is a normal state, not an error, and must never fail activation.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.mlxClusterSigning;

  signPkg = pkgs.writeShellApplication {
    name = "sign-cluster-binaries";
    runtimeInputs = [ pkgs.coreutils ];
    runtimeEnv = {
      MLX_SIGNING_IDENTITY = cfg.identity;
      MLX_SIGNING_STABLE_DIR = cfg.stableDir;
      MLX_SIGN_IN_PLACE = lib.concatStringsSep " " (
        lib.mapAttrsToList (n: p: "${n}=${p}") cfg.signInPlace
      );
      MLX_SIGN_COPIES = lib.concatStringsSep " " (lib.mapAttrsToList (n: p: "${n}=${p}") cfg.copyAndSign);
    };
    text = builtins.readFile ./scripts/sign-cluster-binaries.sh;
  };
in
{
  options.programs.mlxClusterSigning = {
    enable = lib.mkEnableOption "durable code-signing identity for MLX cluster executables";

    identity = lib.mkOption {
      type = lib.types.str;
      default = "mlx-cluster-signing";
      description = ''
        Common name of the self-signed code-signing certificate, as it appears
        in `security find-identity -v -p codesigning`. Created once per host by
        the operator — see the header of this file.
      '';
    };

    stableDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Library/Application Support/mlx-cluster/bin";
      description = ''
        Where store-resident executables are staged so they have a path that
        does not change every rebuild. The nix store is read-only and its paths
        are content-addressed, so neither the file nor its location can carry a
        durable identity; the staged copy is what gets signed.
      '';
    };

    signInPlace = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        rank-python = "/Users/you/.local/share/uv/python/cpython-3.14-macos-aarch64-none/bin/python3.14";
      };
      description = ''
        name -> path, for executables that already live at a writable, stable
        path. Signed in place; symlinks are resolved first so the signature
        lands on the real file.

        The MLX rank's interpreter is the case that matters: uv manages it
        outside the nix store, so it is both stable and writable, and it is the
        process that actually opens the Thunderbolt sockets.
      '';
    };

    copyAndSign = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        cluster-bash = "/nix/store/...-bash-5.3p9/bin/bash";
      };
      description = ''
        name -> nix store path, for executables that cannot be signed where they
        live. Staged into stableDir and signed there. Copied only when the
        content differs, so an unchanged rebuild does not needlessly invalidate
        a warm signature.

        Consumers must then invoke the staged copy rather than the store path,
        or the signature buys nothing: TCC attributes the network call to
        whichever binary actually runs.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.signClusterBinaries = lib.hm.dag.entryAfter [
      "writeBoundary"
    ] "${signPkg}/bin/sign-cluster-binaries";
  };
}
