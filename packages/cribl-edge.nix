{
  lib,
  stdenvNoCC,
  fetchurl,
  xar,
  cpio,
  gzip,
}:
stdenvNoCC.mkDerivation rec {
  pname = "cribl-edge";
  version = "4.18.0-dfc74421"; # cribl-edge

  # Release directory is the semver portion of `version`. Renovate's
  # customManager only rewrites `version`, so the URL must derive the dir
  # from it — hardcoding `/dl/4.17.0/` once broke this on a 4.18 bump.
  releaseDir = lib.concatStringsSep "." [
    (lib.versions.major version)
    (lib.versions.minor version)
    (lib.versions.patch version)
  ];

  src = fetchurl {
    url = "https://cdn.cribl.io/dl/${releaseDir}/cribl-${version}-darwin-universal.pkg";
    hash = "sha256-szztWYz4F5E+T/gj7T2BU6TqMdQT3qa95IpUk3V3rtA=";
  };

  nativeBuildInputs = [
    xar
    cpio
    gzip
  ];

  unpackPhase = ''
    xar -xf $src
    cat Payload | gzip -d | cpio -id
  '';

  installPhase = ''
    mkdir -p $out/opt/cribl
    cp -r cribl/* $out/opt/cribl/
  '';

  meta = {
    description = "Cribl Edge — streaming observability agent";
    homepage = "https://cribl.io/cribl-edge/";
    license = lib.licenses.unfree;
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
  };
}
