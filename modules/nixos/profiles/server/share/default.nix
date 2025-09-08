{
  config,
  lib,
  ...
}:
{
  imports = [
    ./samba.nix
    ./sftp.nix
    ./users.nix
  ];

  options.profiles.server.share = {
    enable = lib.mkEnableOption "share server profile";
    secretsDomain = lib.mkOption {
      type = lib.types.str;
      default = "lxc-share";
      description = "The subpath for the agenix secrets.";
    };
  };

  config = lib.mkIf config.profiles.server.share.enable {
    profiles.server.enable = lib.mkForce true;
  };
}
