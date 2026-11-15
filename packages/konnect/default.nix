{ pkgs, pname }:
pkgs.rustPlatform.buildRustPackage (finalAttrs: {
  inherit pname;
  version = "0.13.0-unstable-2026-11-02";

  src = pkgs.fetchFromGitHub {
    owner = "mixelpixx";
    repo = "Konnect";
    rev = "676efce43c9779f9f9e59a9181cb0746c6452650";
    hash = "sha256-X6xZeHuWb7+i+T5WApGt5rXI4heUCwm/ybbilx/NGEE=";
  };

  cargoHash = "sha256-q/cWeNORFjPp3YFoiICGQVGolL7hd+oCu3Fvj+8IhUc=";

  nativeBuildInputs = with pkgs; [
    cmake
    protobuf
    pkg-config
  ];

  buildInputs = with pkgs; [
    aws-lc
    sqlite
  ];

  env = {
    PROTOC = "${pkgs.protobuf}/bin/protoc";
    PROTOC_INCLUDE = "${pkgs.protobuf}/include";
    KONNECT_BUILD_COMMIT = finalAttrs.src.rev;
  };

  cargoBuildFlags = [
    "-p"
    "konnect"
    "--bin"
    "konnect"
  ];
  cargoTestFlags = [
    "-p"
    "konnect"
    "--lib"
    "--tests"
  ];

  preCheck = ''
    export KONNECT_STATE_DIR="$TMPDIR/konnect-state"
    mkdir -p "$KONNECT_STATE_DIR"
  '';

  passthru.updateScript = null;

  meta = {
    description = "KiCad schematic and PCB design MCP server";
    homepage = "https://github.com/mixelpixx/Konnect";
    license = pkgs.lib.licenses.agpl3Only;
    mainProgram = "konnect";
    platforms = pkgs.lib.platforms.unix;
  };
})
