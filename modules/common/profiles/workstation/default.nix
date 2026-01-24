{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.profiles.workstation.enable = lib.mkEnableOption "core workstation profile";

  config = lib.mkIf config.profiles.workstation.enable {
    environment.systemPackages = [
      pkgs.age-plugin-1p-pq
    ];
  };
}
