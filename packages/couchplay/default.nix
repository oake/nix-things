{
  pkgs,
  pname,
}:
let
  inherit (pkgs) lib kdePackages;
  runtimePath = lib.makeBinPath [
    pkgs.bubblewrap
    pkgs.dbus
    pkgs.gamescope
  ];
in
pkgs.stdenv.mkDerivation (finalAttrs: {
  inherit pname;
  version = "0.7.0";

  src = pkgs.fetchFromGitHub {
    owner = "hikaps";
    repo = "couchplay";
    tag = "v${finalAttrs.version}";
    hash = "sha256-VITiDsqUTTbYRBnVil62S1eDBonSIOtluLrmeLf2RTo=";
  };

  # Opt-in Steam Controller Puck detection via COUCHPLAY_NATIVE_STEAM_CONTROLLERS=1.
  patches = [ ./native-steam-puck.patch ];

  strictDeps = true;
  nativeBuildInputs = [
    pkgs.cmake
    pkgs.makeWrapper
    pkgs.pkg-config
    pkgs.wayland-scanner
    kdePackages.extra-cmake-modules
    kdePackages.wrapQtAppsHook
  ];

  buildInputs = with kdePackages; [
    kconfig
    kcoreaddons
    kdbusaddons
    kglobalaccel
    ki18n
    kiconthemes
    kirigami
    qqc2-desktop-style
    qtbase
    qtdeclarative
    qtwayland
    pkgs.pipewire
    pkgs.wayland
  ];

  cmakeFlags = [ (lib.cmakeBool "BUILD_TESTING" false) ];

  postPatch = ''
    # The upstream shortcut generator only searches /usr.
    substituteInPlace src/core/SteamShortcutManager.cpp \
      --replace-fail 'QStringLiteral("/usr/local/bin/couchplay-gamemode")' \
      "QStringLiteral(\"$out/bin/couchplay-gamemode\")"

    # KWin uses --wayland-display for the parent display and --socket for clients.
    substituteInPlace scripts/couchplay-gamemode.sh \
      --replace-fail '--wayland-display "$CP_WAYLAND_DISPLAY"' '--socket "$CP_WAYLAND_DISPLAY"'
    patchShebangs scripts/couchplay-gamemode.sh
  '';

  qtWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    runtimePath
  ];

  postFixup = ''
    wrapProgram "$out/bin/couchplay-gamemode" \
      --prefix PATH : "$out/bin:${
        lib.makeBinPath [
          kdePackages.kwin
          pkgs.dbus
        ]
      }"
  '';

  meta = {
    description = "Split-screen launcher for Linux games with isolated player sessions";
    homepage = "https://github.com/hikaps/couchplay";
    changelog = "https://github.com/hikaps/couchplay/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    mainProgram = "couchplay";
    platforms = [ "x86_64-linux" ];
  };
})
