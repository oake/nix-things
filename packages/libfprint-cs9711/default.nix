{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    lib
    stdenv
    fetchFromGitHub
    pkg-config
    meson
    ninja
    python3
    gobject-introspection
    udevCheckHook
    glib
    gusb
    pixman
    cairo
    libgudev
    openssl
    opencv4
    doctest
    ;
in
stdenv.mkDerivation {
  inherit pname;
  version = "0-unstable-2026-10-18";

  src = fetchFromGitHub {
    owner = "archeYR";
    repo = "libfprint-CS9711";
    rev = "3c93fc2da6347624fc9c2d2f36a38fec64f99835";
    hash = "sha256-cZItBY2VEvuOimT8IP4SaZaNlzXtc+d+Fw3Tk3Lx5+s=";
  };

  postPatch = ''
    patchShebangs \
      tests/unittest_inspector.py \
      tests/virtual-image.py \
      tests/umockdev-test.py \
      tests/test-generated-hwdb.sh
  '';

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
    python3
    gobject-introspection
    udevCheckHook
  ];

  buildInputs = [
    glib
    gusb
    pixman
    cairo
    libgudev
    openssl
    opencv4
    doctest
  ];

  mesonFlags = [
    "-Ddrivers=all"
    "-Ddoc=false"
    "-Dgtk-examples=false"
    "-Dinstalled-tests=false"
    "-Dudev_rules=enabled"
    "-Dudev_rules_dir=${placeholder "out"}/lib/udev/rules.d"
    "-Dudev_hwdb=enabled"
    "-Dudev_hwdb_dir=${placeholder "out"}/lib/udev/hwdb.d"
  ];

  doCheck = false;
  doInstallCheck = true;

  nativeInstallCheckInputs = [
    (python3.withPackages (p: with p; [ pygobject3 ]))
  ];

  installCheckPhase = ''
    runHook preInstallCheck
    ninjaCheckPhase
    runHook postInstallCheck
  '';

  passthru.updateScript = pkgs.nix-update-script {
    extraArgs = [
      "--version=branch"
    ];
  };

  meta = {
    homepage = "https://github.com/archeYR/libfprint-CS9711";
    description = "libfprint with a driver for the Chipsailing CS9711 fingerprint reader";
    license = lib.licenses.lgpl21Only;
    platforms = lib.platforms.linux;
  };
}
