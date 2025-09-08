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
      isNormalUser = true;
      createHome = false;
      description = "System deploy user";
      uid = 2000;
      openssh.authorizedKeys.keys = config.deploy.sshKeys;
    };

    security.sudo.extraRules = [
      {
        users = [ "deploy" ];
        commands = [
          {
            command = "/nix/store/*-activatable-nixos-system-*/activate-rs";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/rm /tmp/deploy-rs-canary-*";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    nix.settings.trusted-users = [ "deploy" ];
  };
}
