{
  flake,
  lib,
  config,
  ...
}:
let
  hostPlatform = lib.systems.elaborate config.nixpkgs.hostPlatform;
in
{
  # flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # comfy extra args
  _module.args = {
    onlyArm = lib.optionals hostPlatform.isAarch64;
    onlyX86 = lib.optionals hostPlatform.isx86_64;
  };

  # auto gc
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };

  nix.registry.things.to = {
    type = "github";
    owner = "oake";
    repo = "nix-things";
  };

  # avoid building locally
  nix.settings.always-allow-substitutes = true;
}
