{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nix-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    blueprint = {
      url = "github:numtide/blueprint";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;

      blueprint = inputs.blueprint {
        inherit inputs;
        systems = [
          "aarch64-linux"
          "x86_64-linux"
          "aarch64-darwin"
        ];
        nixpkgs.config.allowUnfree = true;
      };

      mkModules =
        modules:
        modules
        // {
          default = {
            imports = lib.attrsets.attrValues modules;
          };
        };
    in
    {
      inherit (blueprint) checks packages;

      commonModules = mkModules blueprint.modules.common;
      nixosModules = mkModules blueprint.nixosModules;
      darwinModules = mkModules blueprint.darwinModules;

      overlays.default = import ./overlay.nix;
    };
}
