{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.beesly;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
  logLevel = types.enum [
    "Trace"
    "Debug"
    "Information"
    "Warning"
    "Error"
    "Critical"
    "None"
  ];
  entity = types.either types.str (
    types.submodule {
      options = {
        entityId = mkOption {
          type = types.str;
          description = "Home Assistant entity ID.";
        };
        name = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Display name; defaults to the Home Assistant friendly name.";
        };
        allowToggle = mkOption {
          type = types.bool;
          default = true;
          description = "Allow this entity to be controlled from the phone.";
        };
      };
    }
  );
  amiEnabled = cfg.ami.passwordFile != null;
in
{
  options.services.beesly = {
    enable = mkEnableOption "Beesly Cisco phone services";
    package = lib.mkPackageOption pkgs "beesly" { };
    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "HTTP listen address (IPv4).";
    };
    port = mkOption {
      type = types.port;
      default = 6971;
      description = "HTTP listen port.";
    };
    allowedHosts = mkOption {
      type = types.listOf types.str;
      default = [ "*" ];
      description = "Accepted HTTP Host names. This does not restrict client IP addresses.";
    };
    logLevel = mkOption {
      type = logLevel;
      default = "Information";
      description = "Application log level.";
    };
    frameworkLogLevel = mkOption {
      type = logLevel;
      default = "Warning";
      description = "ASP.NET framework log level.";
    };
    homeAssistant = {
      url = mkOption {
        type = types.str;
        description = "Home Assistant instance URL.";
      };
      tokenFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Runtime path to the HA token, loaded as a systemd credential.";
      };
      entities = mkOption {
        type = types.listOf entity;
        default = [ ];
        description = "Entities exposed on the phone: entity IDs or objects with entityId, name and allowToggle.";
      };
    };
    ami = {
      host = mkOption {
        type = types.str;
        description = "AMI server hostname. Required when passwordFile is set.";
      };
      port = mkOption {
        type = types.port;
        default = 5038;
        description = "AMI server port.";
      };
      username = mkOption {
        type = types.str;
        description = "AMI username. Required when passwordFile is set.";
      };
      passwordFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Runtime path to the AMI password. Setting this enables the BLF bridge.";
      };
      slots = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "BLF slots 01–24 mapped to enabled HA entity IDs. The lamp and air conditioner screens use slots 01 and 02.";
      };
    };
  };

  config = mkIf cfg.enable {
    services.cisco.protectedTCPPorts = [ cfg.port ];

    systemd.services.beesly = {
      description = "Beesly Cisco phone services";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
      ]
      ++ lib.optional config.networking.nftables.enable "nftables.service";
      requires = lib.optional config.networking.nftables.enable "nftables.service";
      environment = {
        LISTEN_ADDRESS = cfg.listenAddress;
        PORT = toString cfg.port;
        ALLOWED_HOSTS = lib.concatStringsSep ";" cfg.allowedHosts;
        LOG_LEVEL = cfg.logLevel;
        FRAMEWORK_LOG_LEVEL = cfg.frameworkLogLevel;
        HA_URL = cfg.homeAssistant.url;
        HA_ENTITIES = builtins.toJSON cfg.homeAssistant.entities;
        AMI_SLOTS = builtins.toJSON cfg.ami.slots;
      }
      // lib.optionalAttrs (cfg.homeAssistant.tokenFile != null) {
        HA_TOKEN_FILE = "%d/ha-token";
      }
      // lib.optionalAttrs amiEnabled {
        AMI_HOST = cfg.ami.host;
        AMI_PORT = toString cfg.ami.port;
        AMI_USERNAME = cfg.ami.username;
        AMI_PASSWORD_FILE = "%d/ami-password";
      };
      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        LoadCredential =
          lib.optional (cfg.homeAssistant.tokenFile != null) "ha-token:${cfg.homeAssistant.tokenFile}"
          ++ lib.optional amiEnabled "ami-password:${cfg.ami.passwordFile}";
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
      };
    };
  };
}
