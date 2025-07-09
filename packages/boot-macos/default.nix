{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    writeShellApplication
    makeDesktopItem
    stdenvNoCC
    lib
    asahi-bless
    ;
  script = writeShellApplication {
    name = pname;
    text = builtins.readFile ./boot-macos.sh;

    runtimeInputs = [
      asahi-bless
    ];
  };

  desktop = makeDesktopItem {
    name = "Boot macOS";
    desktopName = "Boot macOS";
    comment = "Program that reboots into macOS";
    categories = [ "Utility" ];
    icon = ./apple-logo.png;
    exec = "pkexec ${lib.getExe script}";
  };
in
stdenvNoCC.mkDerivation {
  inherit pname;
  version = "0.0.1";

  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/applications/
    cp ${lib.getExe script} $out/bin
    cp ${desktop}/share/applications/* $out/share/applications
  '';

  meta = {
    platforms = [ "aarch64-linux" ];
  };
}
