{ pkgs, pname }:
pkgs.rustPlatform.buildRustPackage {
  inherit pname;
  version = "2.2.0";

  src = pkgs.fetchFromGitHub {
    owner = "anna-oake";
    repo = "dix";
    rev = "69f91d6d29c26659fb482c628c7752e1eab30dc8";
    hash = "sha256-UMypc/8n4fuY2Qg6kHDek+at9DW3egxY8o/tYvg7pRM=";
  };

  cargoHash = "sha256-m2jRDMjZTJHKbe0Ep76SFT3tV1xytThvaRAt6A0CF3A=";

  nativeInstallCheckInputs = [ pkgs.versionCheckHook ];
  versionCheckProgram = "${placeholder "out"}/bin/dix";
  doInstallCheck = true;

  meta = {
    description = "Nix closure diffs with portable snapshots and offline comparison";
    homepage = "https://github.com/anna-oake/dix";
    license = pkgs.lib.licenses.gpl3Only;
    mainProgram = "dix";
    platforms = pkgs.lib.platforms.unix;
  };
}
