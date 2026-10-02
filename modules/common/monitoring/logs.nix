{ lib, ... }:
{
  imports = [
    (lib.mkRenamedOptionModule
      [ "monitoring" "logs" "systemd" "enable" ]
      [ "monitoring" "logs" "system" "enable" ]
    )
  ];
  options.monitoring.logs = {
    target = lib.mkOption {
      type = lib.types.str;
      description = "Hostname or IP address to push messages to";
    };
    port = lib.mkOption {
      type = lib.types.int;
      default = 12201;
      description = "Port of a GELF TCP input to push messages to";
    };

    victoria = {
      enable = lib.mkEnableOption "pushing logs to VictoriaLogs on the target host (in addition to the GELF output)";
      port = lib.mkOption {
        type = lib.types.int;
        default = 9428;
        description = "Port of the VictoriaLogs HTTP API to push messages to";
      };
    };

    system = {
      enable = lib.mkEnableOption "pushing operating system logs to SIEM";
    };

    docker = {
      enable = lib.mkEnableOption "pushing Docker logs to SIEM";
    };
  };
}
