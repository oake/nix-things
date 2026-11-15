{
  pkgs,
  src,
  version,
}:
pkgs.rustPlatform.buildRustPackage {
  pname = "konnect-schematic-viewer";
  inherit src version;

  cargoRoot = "crates/schematic-viewer";
  buildAndTestSubdir = "crates/schematic-viewer";
  cargoHash = "sha256-pFaRwBj+x64CUeL+7b+4FiyiMvswlHvE9jQiRmDKz2g=";

  nativeBuildInputs = [ pkgs.pkg-config ];
  preCheck = ''
    export HOME="$TMPDIR/viewer-home"
    export KONNECT_STATE_DIR="$TMPDIR/konnect-state"
    mkdir -p "$HOME" "$KONNECT_STATE_DIR"
  '';
  buildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux (
    with pkgs;
    [
      glib
      gtk3
      libsoup_3
      webkitgtk_4_1
    ]
  );

  meta = {
    description = "Konnect live schematic viewer";
    homepage = "https://github.com/mixelpixx/Konnect";
    license = pkgs.lib.licenses.agpl3Only;
    mainProgram = "schematic-viewer";
    platforms = pkgs.lib.platforms.unix;
  };
}
