{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    stdenv
    fetchFromGitHub
    lib
    ;
in
stdenv.mkDerivation {
  inherit pname;
  version = "0-unstable-2025-05-01";

  src = fetchFromGitHub {
    owner = "maeve-oake";
    repo = "Lion";
    rev = "ff37e0273a73e3a9ca19ff45e02e4f5786ee72a5";
    sha256 = "sha256-4oqWTdyxABEsmsit3hh5hwuIJ0n5SXJcQ6VUWovD1yI=";
  };

  installPhase = ''
    mkdir -p $out/share/themes/Lion
    cp -r * $out/share/themes/Lion/.
  '';

  passthru.updateScript = pkgs.nix-update-script {
    extraArgs = [
      "--version=branch"
    ];
  };

  meta = {
    platforms = lib.platforms.linux;
  };
}
