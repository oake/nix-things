{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.profiles.workstation = {
    enable = lib.mkEnableOption "core workstation profile";
    personal.enable = lib.mkEnableOption "personal workstation profile" // {
      default = config.profiles.workstation.enable;
    };
  };

  config = lib.mkIf config.profiles.workstation.enable {
    environment.systemPackages = [
      pkgs.age-plugin-1p-pq
    ];
  };
}
