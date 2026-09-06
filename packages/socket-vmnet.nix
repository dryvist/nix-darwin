# Vendored copy of nixpkgs' `socket-vmnet` (pkgs/by-name/so/socket-vmnet).
#
# Not yet present in this repo's pinned nixpkgs-26.05-darwin branch (only in
# nixpkgs-unstable as of 2026-09), so it is vendored here rather than adding
# a second nixpkgs input just for one package — same pattern as
# ./cribl-edge.nix. Drop this file and switch callers back to `pkgs.socket-vmnet`
# once the pin picks it up.
{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "socket-vmnet";
  version = "1.2.2";

  src = fetchFromGitHub {
    owner = "lima-vm";
    repo = "socket_vmnet";
    tag = "v${finalAttrs.version}";
    hash = "sha256-D5Z4aml82h397ho48HFeXwR6y2XkopFIKjO09jUgFdo=";
  };

  # socket_vmnet is macOS-only, and its Makefile assumes system utilities
  # (logger, date) that aren't on the nixpkgs build sandbox's PATH.
  postPatch = ''
    substituteInPlace Makefile \
       --replace-fail "logger" "echo" \
       --replace-fail "-r $(SOURCE_DATE_EPOCH)" "-d @$(SOURCE_DATE_EPOCH)"
    substituteInPlace launchd/io.github.lima-vm.socket_vmnet{,.bridged.en0}.plist \
      --replace-fail "/opt/socket_vmnet/bin/socket_vmnet" "${placeholder "out"}/bin/socket_vmnet"
  '';

  dontConfigure = true;

  makeFlags = [
    "VERSION=${finalAttrs.version}"
    "SOURCE_DATE_EPOCH=0"
  ];

  installPhase = ''
    runHook preInstall
    make PREFIX=$out VERSION=${finalAttrs.version} SOURCE_DATE_EPOCH=0 install.bin install.doc
    runHook postInstall
  '';

  meta = {
    description = "Vmnet.framework support for unmodified rootless QEMU";
    homepage = "https://github.com/lima-vm/socket_vmnet";
    license = lib.licenses.asl20;
    mainProgram = "socket_vmnet";
    platforms = lib.platforms.darwin;
  };
})
