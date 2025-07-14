{
  lib,
  ...
}:
{
  options.me = {
    username = lib.mkOption { type = lib.types.str; };
    email = lib.mkOption { type = lib.types.str; };
    sshKey = lib.mkOption { type = lib.types.str; };
  };
}
