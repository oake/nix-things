{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      utils,
      nixpkgs,
      nix-darwin,
      ...
    }:
    {
      overlays.default = import ./pkgs/overlay.nix;
    }
    // utils.lib.eachDefaultSystem (
      system:
      let
        pkgs =
          (
            if (nixpkgs.lib.strings.hasSuffix "darwin" system) then
              import nix-darwin.inputs.nixpkgs
            else
              import nixpkgs
          )
            {
              inherit system;
              overlays = [ self.overlays.default ];
              config.allowUnfree = true;
            };
      in
      {
        packages = utils.lib.filterPackages system (self.overlays.default pkgs pkgs);
      }
    );
}
