{
  pkgs,
  pname,
}:
let
  inherit (pkgs) lib;

  # The Steam API shims are the upstream builds pinned by PartyDeck's build.rs.
  goldbergRelease = "release-2026_08_23";
  goldbergLinux = pkgs.fetchurl {
    url = "https://github.com/Detanup01/gbe_fork/releases/download/${goldbergRelease}/emu-linux-release.tar.bz2";
    hash = "sha256-rhqVDGUEZOPvpTOri6RG1XWWK48QRdTyifelQ5PlUoI=";
  };
  goldbergWindows = pkgs.fetchurl {
    url = "https://github.com/Detanup01/gbe_fork/releases/download/${goldbergRelease}/emu-win-release.7z";
    hash = "sha256-gS3V9u3T8XUhnMmDblXB70FUhUoA+wpv8ZclS4VXm68=";
  };

  gamescope-kbm = import ./gamescope-kbm.nix { inherit pkgs; };
in
# Adapted from https://github.com/KasielH/partydeck-nix/blob/9a0577d37bcc17e179fdc259ad84d9c1020480d9/flake.nix
pkgs.rustPlatform.buildRustPackage (finalAttrs: {
  inherit pname;
  version = "0.8.7-e";

  src = pkgs.fetchFromGitHub {
    owner = "partydeck";
    repo = "partydeck";
    tag = "v${finalAttrs.version}";
    hash = "sha256-P/MwImkwd5JKr9z7c++64Mbxz+8fN64qMUOI+/tqvuc=";
  };
  cargoHash = "sha256-Nmwi8FfNAC+C1oJUCX5sYHhWU+GsMsPoOKb4p8Jvw6M=";

  strictDeps = true;
  nativeBuildInputs = with pkgs; [
    _7zz
    makeBinaryWrapper
    patchelf
    pkg-config
  ];
  buildInputs = with pkgs; [
    fontconfig
    libGL
    libx11
    libxcursor
    libxi
    libxkbcommon
    libxrandr
    openssl
    wayland
  ];

  postPatch = ''
    substituteInPlace src/paths.rs \
      --replace-fail 'PathBuf::from("/usr/share/partydeck")' \
      "PathBuf::from(\"$out/share/partydeck\")"
  '';

  postInstall = ''
    resources="$out/share/partydeck"
    install -Dm644 res/*.js -t "$resources"
    install -Dm644 LICENSE COPYING.md -t "$out/share/licenses/partydeck"
    install -Dm644 res/icon.png "$out/share/icons/hicolor/256x256/apps/partydeck.png"
    install -Dm644 ${
      pkgs.makeDesktopItem {
        name = "partydeck";
        desktopName = "PartyDeck";
        exec = "partydeck";
        icon = "partydeck";
        categories = [ "Game" ];
      }
    }/share/applications/partydeck.desktop "$out/share/applications/partydeck.desktop"

    tar -xf ${goldbergLinux} release/regular/{x86,x64}/steamclient.so
    install -Dm644 release/regular/x86/steamclient.so "$resources/goldberg/linux32/steamclient.so"
    install -Dm644 release/regular/x64/steamclient.so "$resources/goldberg/linux64/steamclient.so"
    7zz x ${goldbergWindows} -o"$TMPDIR/goldberg" 'release/steamclient_experimental/*.dll'
    install -Dm644 "$TMPDIR"/goldberg/release/steamclient_experimental/{steamclient,steamclient64,GameOverlayRenderer,GameOverlayRenderer64}.dll \
      -t "$resources/goldberg/win"
  '';

  postFixup = ''
    # Keep the GUI's dlopen libraries out of the environment of launched games.
    patchelf --add-rpath "${lib.makeLibraryPath finalAttrs.buildInputs}:${pkgs.addDriverRunpath.driverLink}/lib" \
      "$out/bin/partydeck"

    wrapProgram "$out/bin/partydeck" \
      --prefix PATH : ${
        lib.makeBinPath (
          with pkgs;
          [
            bubblewrap
            fuse-overlayfs
            gamescope
            gamescope-kbm
            kdePackages.kwin
            umu-launcher
            util-linux
            xdg-utils
            xwayland
          ]
        )
      }

    makeWrapper "$out/bin/partydeck" "$out/bin/partydeck-gaming-mode" \
      --set HOMETEST_DESKTOP_SESSION plasma \
      --add-flags '--kwin --fullscreen'
  '';

  meta = {
    description = "Split-screen game launcher for Linux and SteamOS";
    homepage = "https://github.com/partydeck/partydeck";
    changelog = "https://github.com/partydeck/partydeck/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      lgpl3Only
    ];
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
    mainProgram = "partydeck";
    platforms = [ "x86_64-linux" ];
  };
})
