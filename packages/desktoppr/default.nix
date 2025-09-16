{
  pname,
  pkgs,
}:
let
  inherit (pkgs)
    stdenvNoCC
    lib
    fetchzip
    ;
  version = "0.5-218";
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchzip {
    url = "https://github.com/scriptingosx/desktoppr/releases/download/v0.5/desktoppr-${version}.zip";
    hash = "sha256-JHnQS4ZL0GC4shBcsKtmPOSFBY6zLSV/IAFRb4+A++Q=";
  };

  installPhase = ''
    mkdir -p "$out/bin"
    cp -r desktoppr "$out/bin"
  '';

  meta = with lib; {
    description = "Simple command line tool to set the desktop picture on macOS";
    homepage = "https://github.com/scriptingosx/desktoppr";
    license = licenses.asl20;
    platforms = platforms.darwin;
  };
}
