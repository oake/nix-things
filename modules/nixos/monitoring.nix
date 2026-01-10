{
  lib,
  config,
  ...
}:
let
  cfg = config.monitoring;
in
{
  options.monitoring = {
    logs = {
      enable = lib.mkEnableOption "pushing logs to SIEM";
      target = lib.mkOption {
        type = lib.types.str;
        description = "Hostname or IP address to push syslog messages to";
      };
      port = lib.mkOption {
        type = lib.types.int;
        default = 3514;
        description = "Port to push syslog messages to";
      };
    };
    machineType = lib.mkOption {
      type = lib.types.enum [
        "local"
        "remote"
        "mobile"
      ];
      default = "local";
    };
  };
  config = lib.mkIf cfg.logs.enable {
    services.rsyslogd = {
      enable = true;
      extraConfig = ''
        *.* action(
          type="omfwd"
          target="${cfg.logs.target}"
          port="${toString cfg.logs.port}"
          protocol="tcp"
          template="RSYSLOG_SyslogProtocol23Format"

          action.resumeRetryCount="-1"

          queue.type="LinkedList"
          queue.filename="fwdqueue"
          queue.maxdiskspace="1g"
          queue.saveonshutdown="on"
        )
      '';
    };

    disko.simple.impermanence.persist.directories = [
      "/var/spool/rsyslog"
    ];
  };
}
