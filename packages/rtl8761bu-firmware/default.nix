{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    stdenvNoCC
    lib
    ;
in
stdenvNoCC.mkDerivation {
  inherit pname;
  version = "dcc6b3a8";

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/lib/firmware/rtl_bt
    cp ${./rtl8761bu_fw.bin} $out/lib/firmware/rtl_bt/rtl8761bu_fw.bin
  '';

  meta = with lib; {
    description = "Firmware for Realtek RTL8761bu";
    license = licenses.unfreeRedistributableFirmware;
    platforms = with platforms; linux;
  };
}
