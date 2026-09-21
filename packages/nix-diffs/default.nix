{
  pkgs,
  pname,
}:
pkgs.buildGoModule (finalAttrs: {
  inherit pname;
  version = "0.2.0";

  src = pkgs.fetchFromGitHub {
    owner = "anna-oake";
    repo = "nix-diffs";
    tag = "v${finalAttrs.version}";
    hash = "sha256-32a11TMU7hCOUNoRxjp2TgsxZJ3o2nOM4eJiF+hOSmw=";
  };

  vendorHash = null;
  nativeCheckInputs = [ pkgs.git ];

  meta = {
    description = "Browse and compare saved Nix closure snapshots";
    homepage = "https://github.com/anna-oake/nix-diffs";
    mainProgram = "nix-diffs";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
})
