{
  pkgs,
  pname,
}:
pkgs.buildGoModule (finalAttrs: {
  inherit pname;
  version = "0.1.0";

  src = pkgs.fetchFromGitHub {
    owner = "anna-oake";
    repo = "nix-diffs";
    tag = "v${finalAttrs.version}";
    hash = "sha256-8paOY+p4ZLedcqtvSYpH8Cxvak4hLBTbkaOf3r9FLpE=";
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
