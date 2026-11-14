{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    lib
    buildGoModule
    fetchFromGitHub
    udev
    ;
  version = "2.0.3";
in
buildGoModule {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "Luzifer";
    repo = pname;
    tag = "v${version}";
    sha256 = "sha256-AAmlebHfHuq/DsMPtTeU/20+84pozcUumbvLGGKw5d4=";
  };

  modRoot = "./cmd/streamdeck";

  vendorHash = "sha256-VHkz8OIH5eV4Xt6AIIUBN3X67KlMOYqNRyEvXzunByg=";

  buildInputs = [
    udev
  ];

  meta = {
    description = "streamdeck is a library and management tool to use an Elgato StreamDeck on a Linux system written in Go.";
    homepage = "https://github.com/Luzifer/streamdeck";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "streamdeck";
  };
}
