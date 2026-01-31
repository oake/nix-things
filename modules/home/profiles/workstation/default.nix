{
  lib,
  config,
  ...
}:
{
  options.profiles.workstation = {
    enable = lib.mkEnableOption "core workstation profile";
    personal.enable = lib.mkEnableOption "personal workstation profile" // {
      default = config.profiles.workstation.enable;
    };
  };
}
