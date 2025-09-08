{
  lib,
  ...
}:
{
  options.profiles.server.enable = lib.mkEnableOption "core server profile";
}
