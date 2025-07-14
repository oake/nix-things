{
  pkgs,
  lib,
  inputs,
  ...
}:
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
    inputs.nix-things.overlays.default
  ];
}
