{ pkgs, pname }:
pkgs.rustPlatform.buildRustPackage {
  inherit pname;
  version = "2.2.0";

  src = pkgs.fetchFromGitHub {
    owner = "anna-oake";
    repo = "dix";
    rev = "e91791f649e787b6293ee05f88dbeb69c194fbdb";
    hash = "sha256-IQkKHDscEomnotKhz5BICz/UTFTTS5RWEti20w+xzDQ=";
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
