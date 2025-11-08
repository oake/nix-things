{
  flake,
  inputs,
}:
{
  pkgs,
  lib,
  ...
}:
let
  unstable = import inputs.nix-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  # allow unfree pkgs
  nixpkgs.config.allowUnfree = true;

  # flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # comfy extra args
  _module.args = with pkgs.stdenv.hostPlatform; {
    inherit unstable;
    onlyArm = lib.optionals isAarch64;
    onlyX86 = lib.optionals isx86_64;
  };

  # auto gc
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };

  # overlays
  nixpkgs.overlays = [
    flake.overlays.default
  ];

  # avoid building locally
  nix.settings.always-allow-substitutes = true;
}
