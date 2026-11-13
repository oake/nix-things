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
  version = "1.7.2";
in
buildGoModule {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "Luzifer";
    repo = pname;
    tag = "v${version}";
    sha256 = "sha256-qagu83Cz/cQyRAAKBCffWVyOq+pF7GtcfWIgVwiK76Q=";
  };

  modRoot = "./cmd/streamdeck";

  vendorHash = "sha256-dzgCf+ZAI6OOLs5Umitd4iJnaQher7GNXMzgtEGT5J4=";

  patches = [
    ./fix-stderr.patch
  ];

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
