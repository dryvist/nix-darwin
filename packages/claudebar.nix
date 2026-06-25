{
  stdenvNoCC,
  fetchurl,
  undmg,
  lib,
}:

stdenvNoCC.mkDerivation rec {
  pname = "ClaudeBar";
  # managed by: nix-update (deps-update-flake.yml)
  version = "0.4.68";

  src = fetchurl {
    url = "https://github.com/tddworks/ClaudeBar/releases/download/v${version}/ClaudeBar-${version}.dmg";
    hash = "sha256-wNQDeyVmmBwIEq0nmOTHqSCCnNTupmWJKc/miEHlxAk=";
  };

  nativeBuildInputs = [ undmg ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    cp -r ClaudeBar.app $out/Applications/
    runHook postInstall
  '';

  meta = {
    description = "macOS menu bar app for AI coding assistant quota monitoring";
    homepage = "https://github.com/tddworks/ClaudeBar";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
  };
}
