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
in
buildGoModule {
  inherit pname;
  version = "1.7.2";

  src = fetchFromGitHub {
    owner = "Luzifer";
    repo = pname;
    rev = "122bd63cc98ec304788e655f377f71e21e5117d5";
    sha256 = "sha256-qagu83Cz/cQyRAAKBCffWVyOq+pF7GtcfWIgVwiK76Q=";
  };

  modRoot = "./cmd/streamdeck";

  vendorHash = "sha256-dzgCf+ZAI6OOLs5Umitd4iJnaQher7GNXMzgtEGT5J4=";

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
