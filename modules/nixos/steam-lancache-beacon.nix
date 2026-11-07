{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.steam-lancache-beacon;
in
{
  options.services.steam-lancache-beacon = {
    enable = lib.mkEnableOption "Steam shader profile reports at login and hourly while logged in";

    package = lib.mkPackageOption pkgs "steam-lancache-beacon" { };

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "maeve";
      description = "Restrict the user service to this user with ConditionUser. When unset, it runs for all users.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      example = "https://lancache.lan.al";
      description = "Base URL of the Steam LanCache manager.";
    };

    hostname = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "eule";
      description = "Reported hostname. When unset, the beacon detects the machine's hostname.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Steam state belongs to the desktop user, so collection runs in their user
    # manager with their home directory and Steam installation discovery.
    systemd.user.services.steam-lancache-beacon = {
      description = "Report Steam shader profiles to LanCache";
      wantedBy = [ "default.target" ];
      environment = {
        BASE_URL = cfg.baseUrl;
      }
      // lib.optionalAttrs (cfg.hostname != null) {
        BEACON_HOSTNAME = cfg.hostname;
      };
      unitConfig = {
        StartLimitIntervalSec = "10min";
        StartLimitBurst = 4;
      }
      // lib.optionalAttrs (cfg.user != null) {
        ConditionUser = cfg.user;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
        RestartSec = "1min";
        TimeoutStartSec = "1min";
        NoNewPrivileges = true;
      };
    };

    systemd.user.timers.steam-lancache-beacon = {
      description = "Report Steam shader profiles hourly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };
  };
}
