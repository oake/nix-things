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
        description = "Main-menu entities only: IDs or objects with entityId, name and allowToggle. Does not configure touch views or AMI.";
      };
      views = mkOption {
        default = { };
        description = "Named touch UIs, served at /ha/touch.xml?view=<name>, independently of AMI and the main menu.";
        type = types.attrsOf (
          types.submodule {
            options = {
              title = mkOption {
                type = types.str;
                description = "Window title rendered by Beesly.";
              };
              type = mkOption {
                type = types.enum [
                  "lamp"
                  "aircon"
                  "multiple"
                ];
                description = "Control layout.";
              };
              entity = mkOption {
                type = types.nullOr entity;
                default = null;
                description = "Entity for a lamp or aircon view.";
              };
              entities = mkOption {
                type = types.listOf entity;
                default = [ ];
                description = "Controls for a multiple view, in display order; automatically paginated.";
              };
              swatch = {
                enable = mkEnableOption "colour swatches with independent light targets";
                entities = mkOption {
                  type = types.listOf entity;
                  default = [ ];
                  description = "Lights affected by colour and brightness when swatches are enabled. Need not be displayed controls.";
                };
              };
            };
          }
        );
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
        description = "BLF slots 01–24 mapped to controllable HA entity IDs, independently of menus and touch views.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = lib.mapAttrsToList (id: view: {
      assertion =
        (
          if view.type == "multiple" then
            view.entity == null && view.entities != [ ]
          else
            view.entity != null && view.entities == [ ]
        )
        && (!view.swatch.enable || view.swatch.entities != [ ]);
      message = "services.beesly.homeAssistant.views.${id}: use entity for lamp/aircon or entities for multiple; enabled swatches need targets.";
    }) cfg.homeAssistant.views;
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
        UI_VIEWS_FILE = toString (
          pkgs.writeText "beesly-views.json" (builtins.toJSON cfg.homeAssistant.views)
        );
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
