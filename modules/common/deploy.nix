{
  config,
  lib,
  hostName,
  ...
}:
{
  options.deploy = {
    enable = lib.mkEnableOption "enable deploy" // {
      default = true;
    };
    sshKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ config.me.deployKey ];
      description = "SSH keys for the deploy user";
    };
    fqdn = lib.mkOption {
      type = lib.types.str;
      default = (lib.strings.removePrefix "lxc-" hostName) + "." + config.me.lanDomain;
      description = "Fully qualified domain name used for deployment";
    };
  };

  config = lib.mkIf config.deploy.enable {
    users.users.deploy = {
      description = "System deploy user";
      uid = 2000;
      createHome = false;
      openssh.authorizedKeys.keys = config.deploy.sshKeys;
    };

    nix.settings.trusted-users = [ "deploy" ];
  };
}
