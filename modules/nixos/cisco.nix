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
  accessTCPPorts = lib.unique (lib.optional httpEnabled cfg.httpPort ++ cfg.protectedTCPPorts);
  accessUDPPorts = lib.optional tftpEnabled cfg.tftpPort;
  clients = lib.unique (
    map (device: device.ip) (builtins.attrValues cfg.devices) ++ cfg.extraAllowedClients
  );
  portRules =
    protocol: ports:
    lib.optionalString (ports != [ ]) ''
      meta nfproto ipv4 ${protocol} dport { ${
        lib.concatMapStringsSep ", " toString ports
      } } ip saddr != @allowed4 drop
      meta nfproto ipv6 ${protocol} dport { ${lib.concatMapStringsSep ", " toString ports} } drop
    '';
  serve =
    mode: port:
    lib.escapeShellArgs (
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
  options.services.cisco = {
    extraAllowedClients = lib.mkOption {
      type = lib.types.listOf (
        lib.types.strMatching "(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])([.](25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])){3}"
      );
      default = [ ];
      description = "Additional allowed IPv4 addresses. Phone addresses are included automatically from devices.<name>.ip.";
    };
    protectedTCPPorts = lib.mkOption {
      type = lib.types.listOf (lib.types.ints.between 1 65535);
      default = [ ];
      description = "Additional local TCP ports, such as Beesly, sharing the phone and extraAllowedClients access list.";
    };
  };
  config = {
    systemd.services.cisco-config-http = lib.mkIf httpEnabled {
      description = "Cisco phone configuration HTTP server";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "nftables.service"
      ];
      requires = [ "nftables.service" ];
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
      description = "Cisco phone configuration TFTP server";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "nftables.service"
      ];
      requires = [ "nftables.service" ];
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

    networking.nftables.enable = lib.mkIf cfg.enable true;
    networking.nftables.tables.cisco_access = lib.mkIf cfg.enable {
      family = "inet";
      content = ''
        set allowed4 {
          type ipv4_addr;
          ${lib.optionalString (clients != [ ]) "elements = { ${lib.concatStringsSep ", " clients} };"}
        }
        chain input {
          type filter hook input priority -10; policy accept;
          ${portRules "tcp" accessTCPPorts}
          ${portRules "udp" accessUDPPorts}
        }
      '';
    };
  };
}
