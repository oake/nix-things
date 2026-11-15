{ pkgs, pname }:
let
  server = import ./server.nix { inherit pkgs pname; };
  viewer = import ./viewer.nix {
    inherit pkgs;
    inherit (server) src version;
  };
in
pkgs.runCommand "${pname}-${server.version}"
  {
    inherit (server) version meta;
    nativeBuildInputs = with pkgs; [
      python3
      zip
      unzip
    ];
    passthru = {
      inherit server viewer;
      updateScript = null;
    };
  }
  ''
      # Use upstream's PCM assembly so the toolbar, native bridge, viewer and
      # platform-specific IPC manifest match the official full installation.
    mkdir source
    cp -R ${server.src}/plugin ${server.src}/packaging source/
    chmod -R u+w source
    bash source/packaging/build-pcm.sh \
      --version ${builtins.head (pkgs.lib.splitString "-" server.version)} \
        --binary ${server}/bin/konnect \
        --viewer ${viewer}/bin/schematic-viewer \
        --platform ${if pkgs.stdenv.hostPlatform.isDarwin then "macos" else "linux"} \
        --out "$TMPDIR/pcm"
      unzip -q "$TMPDIR"/pcm/*.zip -d "$TMPDIR/unpacked"
      mkdir -p $out/bin $out/share/kicad/plugins
      cp -R "$TMPDIR/unpacked/plugins" $out/share/kicad/plugins/konnect
      # Both binaries stay together: Konnect resolves the viewer via current_exe().
      ln -s $out/share/kicad/plugins/konnect/bin/konnect $out/bin/konnect
      ln -s $out/share/kicad/plugins/konnect/bin/schematic-viewer $out/bin/schematic-viewer

      PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s ${server.src}/plugin/tests
  ''
