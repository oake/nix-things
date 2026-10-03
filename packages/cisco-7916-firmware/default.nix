{
  pkgs,
  pname,
}:
let
  inherit (pkgs) stdenvNoCC lib;
in
stdenvNoCC.mkDerivation {
  inherit pname;
  version = "1.0.4.2";

  src = ./files;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R "$src"/. "$out/"
    runHook postInstall
  '';

  passthru.loadInformation = "B016-1-0-4-2";

  meta = {
    description = "Firmware files for the Cisco Unified IP Phone Expansion Module 7916";
    license = lib.licenses.unfreeRedistributableFirmware;
    platforms = lib.platforms.all;
  };
}
