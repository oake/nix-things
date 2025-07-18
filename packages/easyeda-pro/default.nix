{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    stdenv
    fetchurl
    unzip
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook
    glib
    nss
    libdrm
    mesa
    alsa-lib
    libGL
    udev
    lib
    ;
  version = "2.2.39.2";

  buildInputs = [
    glib
    nss
    libdrm
    mesa
    alsa-lib
    libGL
    udev
  ];
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://image.easyeda.com/files/easyeda-pro-linux-x64-${version}.zip";
    sha256 = "sha256-Fr1+RTkcd3khLhyEP9Tpelp0BANsi/O1uKQwfdN5y2E=";
  };

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook
  ];

  inherit buildInputs;

  unpackPhase = ''
    unzip $src -d .
  '';

  installPhase = ''
    mkdir -p $out/opt/easyeda-pro $out/share/applications/ $out/bin
    cp -rfv easyeda-pro/* $out/opt/easyeda-pro
    chmod -R 777 $out/opt/easyeda-pro

    ln -s $out/opt/easyeda-pro/easyeda-pro $out/bin/easyeda-pro
    cp -v $out/opt/easyeda-pro/easyeda-pro.dkt $out/share/applications/easyeda-pro.desktop
    substituteInPlace $out/share/applications/easyeda-pro.desktop \
        --replace 'Exec=/opt/easyeda-pro/easyeda-pro %f' "Exec=easyeda-pro %f" \
        --replace "Icon=" "Icon=$out"
  '';

  postFixup = ''
    makeWrapper $out/opt/easyeda-pro/easyeda-pro $out/bin/easyeda-pro \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath buildInputs}:$out/opt/easyeda-pro
  '';

  meta = {
    description = "EasyEDA Pro Edition";
    homepage = "https://easyeda.com/";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
  };
}
