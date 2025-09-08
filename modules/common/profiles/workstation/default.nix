{
  lib,
  ...
}:
{
  options.profiles.workstation.enable = lib.mkEnableOption "core workstation profile";
}
