{
  config,
  lib,
  ...
}:
let
  cfg = config.profiles.server.monitor;
  dataDir = "${cfg.storageDir}/victorialogs";
in
{
  options.profiles.server.monitor.victorialogs.retentionPeriod = lib.mkOption {
    type = lib.types.str;
    default = "5y";
    description = "How long VictoriaLogs keeps logs.";
  };

  config = lib.mkIf cfg.enable {
    users.users.victorialogs = {
      isSystemUser = true;
      group = "victorialogs";
      description = "VictoriaLogs daemon user";
    };
    users.groups.victorialogs = { };

    systemd.tmpfiles.rules = [
      "d '${dataDir}' 0700 victorialogs victorialogs - -"
    ];

    services = {
      victorialogs = {
        enable = true;
        extraOptions = [
          "-storageDataPath=${dataDir}"
          "-retentionPeriod=${cfg.victorialogs.retentionPeriod}"
        ];
      };
      nginx.virtualHosts.${cfg.webDomain}.locations = {
        "/victorialogs" = {
          return = "301 /victorialogs/select/vmui/";
        };
        "/victorialogs/" = {
          proxyPass = "http://127.0.0.1:9428/";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
          '';
        };
      };
    };

    systemd.services.victorialogs.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "victorialogs";
      Group = "victorialogs";
    };
  };
}
