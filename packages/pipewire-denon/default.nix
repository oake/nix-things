{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    lib
    stdenv
    fetchFromGitHub
    meson
    ninja
    pkg-config
    pipewire
    systemd
    ;
  version = "0.1.0";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "anna-oake";
    repo = "pipewire-denon";
    rev = "v${version}";
    hash = "sha256-VqGpOk0JeZxNy2nub+sGUnl40DIsWWvMoZEUVgjQKvI=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];
  buildInputs = [
    pipewire
    systemd
  ];

  meta = {
    homepage = "https://github.com/anna-oake/pipewire-denon";
    description = "Native PipeWire sink with Denon AVR volume and mute control";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "pipewire-denon";
  };
}
