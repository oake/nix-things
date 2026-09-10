{
  pkgs,
  pname,
}:
let
  inherit (pkgs) stdenvNoCC lib;
in
stdenvNoCC.mkDerivation {
  inherit pname;
  version = "9.4.2-sr4-3";

  src = ./files;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R "$src"/. "$out/"
    runHook postInstall
  '';

  passthru.loadInformation = "SIP75.9-4-2SR4-3S";

  meta = {
    description = "Firmware files for the Cisco Unified IP Phone 7975G";
    license = lib.licenses.unfreeRedistributableFirmware;
    platforms = lib.platforms.all;
  };
}
