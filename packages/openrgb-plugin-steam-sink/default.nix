{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    lib
    stdenv
    fetchFromGitHub
    ;
  inherit (pkgs.qt6Packages) qtbase qmake wrapQtAppsHook;
  version = "0.1.0";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "anna-oake";
    repo = "openrgb-steam-sink";
    tag = "v${version}";
    hash = "sha256-kitty8tlNg0SsaDHYhaF2Kp83Y66xVaGbGB0ig6AkcQ=";
  };

  nativeBuildInputs = [
    qmake
    wrapQtAppsHook
  ];

  buildInputs = [
    qtbase
  ];

  OPENRGB_SOURCE_DIR = pkgs.openrgb.src;

  installPhase = ''
    runHook preInstall

    install -D -m 0644 build/libOpenRGBSteamSinkPlugin.so \
      $out/lib/openrgb/plugins/libOpenRGBSteamSinkPlugin.so

    runHook postInstall
  '';

  meta = {
    homepage = "https://github.com/anna-oake/openrgb-steam-sink";
    description = "Steam front light bar sink plugin for OpenRGB";
    license = lib.licenses.wtfpl;
    platforms = lib.platforms.linux;
  };
}
