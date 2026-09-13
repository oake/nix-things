{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.services.rtl-proxy;
  yaml = pkgs.formats.yaml { };
  renderedConfig = yaml.generate "rtl-proxy.yaml" {
    upstream = cfg.upstreamAddress;
    reconnectDelayMs = cfg.reconnectDelayMilliseconds;
    settleMs = cfg.settleMilliseconds;
    frequencyOffsetHz = cfg.frequencyOffsetHertz;
    clients = lib.mapAttrsToList (name: client: {
      inherit name;
      inherit (client) listen priority preempted;
    }) cfg.clients;
  };
in
{
  options.services.rtl-proxy = {
    enable = mkEnableOption "priority-aware rtl_tcp proxy";

    package = mkOption {
      type = types.package;
      default = pkgs.rtl-proxy;
      defaultText = lib.literalExpression "pkgs.rtl-proxy";
      description = "The rtl-proxy package to run.";
    };

    upstreamAddress = mkOption {
      type = types.str;
      default = "127.0.0.1:1234";
      description = "Address of the real rtl_tcp server.";
    };

    reconnectDelayMilliseconds = mkOption {
      type = types.ints.unsigned;
      default = 1000;
      description = "Delay before reconnecting to rtl_tcp.";
    };

    settleMilliseconds = mkOption {
      type = types.ints.unsigned;
      default = 50;
      description = "Time for which IQ is discarded after ownership or tuning changes.";
    };

    frequencyOffsetHertz = mkOption {
      type = types.int;
      default = 0;
      description = ''
        Transparent tuner offset in Hz. The proxy adds this value to hardware
        tuning requests and digitally shifts the IQ stream back so clients keep
        seeing their requested center frequency while the tuner DC spike moves
        away from the center.
      '';
    };

    clients = mkOption {
      default = { };
      description = "Named rtl_tcp listeners. Lower priority numbers preempt higher numbers.";
      type = types.attrsOf (
        types.submodule (
          { ... }:
          {
            options = {
              listen = mkOption {
                type = types.str;
                description = "TCP listen address exposed to this client.";
              };
              priority = mkOption {
                type = types.ints.unsigned;
                description = "Priority number; lower values have higher priority.";
              };
              preempted = mkOption {
                type = types.enum [
                  "disconnect"
                  "pause"
                ];
                default = "disconnect";
                description = "Whether an active connection is disconnected or paused when preempted.";
              };
            };
          }
        )
      );
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.clients != { };
        message = "services.rtl-proxy.clients must contain at least one listener";
      }
    ];

    systemd.services.rtl-proxy = {
      description = "Priority-aware rtl_tcp proxy";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "rtl-tcp.service"
      ];
      serviceConfig = {
        DynamicUser = true;
        ExecStart = "${lib.getExe cfg.package} -config ${renderedConfig}";
        Restart = "always";
        RestartSec = "2s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
      };
    };
  };
}
