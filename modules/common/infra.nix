{
  config,
  lib,
  hostName,
  ...
}:
let
  cfg = config.infra;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
in
{
  options.infra = {
    flakeRepo = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "anna-oake/nixos-config";
      description = "Flake repository in owner/repository form.";
    };
    hubUrl = mkOption {
      type = types.str;
      default = "https://infra.oa.ke";
      description = "Hub URL for the beacon and deployer.";
    };
    hubTokenFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Runtime file containing the shared hub bearer token.";
    };

    beacon.enable = mkEnableOption "the infra configuration beacon" // {
      default = true;
    };

    deploy = {
      enable = mkEnableOption "deployment access for this host" // {
        default = true;
      };
      auto = mkEnableOption "automatic boot staging";
      sshKeys = mkOption {
        type = types.listOf types.str;
        default = [ config.me.deployKey ];
        description = "SSH public keys authorized for the deploy user.";
      };
      fqdn = mkOption {
        type = types.addCheck (types.listOf types.str) (hosts: hosts != [ ]);
        default = [ ((lib.strings.removePrefix "lxc-" hostName) + "." + config.me.lanDomain) ];
        description = "Ordered deployment addresses. deploy-rs uses the first; infra-deployer tries subsequent addresses if unreachable.";
      };
    };
  };

  config = mkIf cfg.deploy.enable {
    users.users.deploy = {
      description = "System deploy user";
      uid = 2000;
      createHome = false;
      openssh.authorizedKeys.keys = cfg.deploy.sshKeys;
    };

    nix.settings.trusted-users = [ "deploy" ];
  };
}
