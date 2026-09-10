{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.cisco;
  httpEnabled = cfg.enable && cfg.httpPort != null;
  tftpEnabled = cfg.enable && cfg.tftpPort != null;
  serve = mode: port: lib.escapeShellArgs (
    [
      "${cfg.serveBin}/bin/cisco-serve"
      mode
      "--root"
      (toString cfg.serverRoot)
      "--bind"
      cfg.bindHost
      "--port"
      (toString port)
    ]
    ++ lib.optionals (cfg.secretsPath != null) [
      "--secrets"
      cfg.secretsPath
    ]
  );
in
{
  config = {
    systemd.services.cisco-config-http = lib.mkIf httpEnabled {
      description = "Cisco 7975G configuration HTTP server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = serve "http" cfg.httpPort;
        DynamicUser = cfg.secretsPath == null;
        Restart = "on-failure";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };

    systemd.services.cisco-config-tftp = lib.mkIf tftpEnabled {
      description = "Cisco 7975G configuration TFTP server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = serve "tftp" cfg.tftpPort;
        DynamicUser = cfg.secretsPath == null;
        Restart = "on-failure";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        AmbientCapabilities = lib.mkIf (cfg.tftpPort != null && cfg.tftpPort < 1024) [
          "CAP_NET_BIND_SERVICE"
        ];
        CapabilityBoundingSet = lib.mkIf (cfg.tftpPort != null && cfg.tftpPort < 1024) [
          "CAP_NET_BIND_SERVICE"
        ];
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf httpEnabled [ cfg.httpPort ];
    networking.firewall.allowedUDPPorts = lib.mkIf tftpEnabled [ cfg.tftpPort ];
  };
}
