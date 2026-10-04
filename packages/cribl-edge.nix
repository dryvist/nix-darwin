{
  lib,
  stdenvNoCC,
  fetchurl,
  xar,
  cpio,
  gzip,
  homelab-contracts,
}:
let
  criblCatalog = builtins.fromJSON (
    builtins.readFile "${homelab-contracts}/ansible/roles/cribl_edge/files/cribl.json"
  );
  inherit (criblCatalog) version;
  releaseDir = builtins.head (lib.splitString "-" version);
in
stdenvNoCC.mkDerivation rec {
  pname = "cribl-edge";
  inherit version;

  src = fetchurl {
    url = "https://cdn.cribl.io/dl/${releaseDir}/cribl-${version}-darwin-universal.pkg";
    hash = "sha256-Mqlvmc3LP/1y8LU66BVow83k0EniHCUW4grx51ELqkA=";
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
