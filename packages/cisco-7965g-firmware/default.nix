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

  passthru.loadInformation = "SIP45.9-4-2SR4-3S";

  meta = {
    description = "SIP firmware files for the Cisco Unified IP Phones 7945G and 7965G";
    license = lib.licenses.unfreeRedistributableFirmware;
    platforms = lib.platforms.all;
  };
}
