{
  config,
  lib,
  ...
}:
{
  options.deploy.auto.enable = lib.mkEnableOption "automatic boot deployments of this host by services.deployer";

  config = lib.mkIf config.deploy.enable {
    users.users.deploy.isNormalUser = true;

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
  };
}
