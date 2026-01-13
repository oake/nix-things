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
        description = "Hostname or IP address to push messages to";
      };
      port = lib.mkOption {
        type = lib.types.int;
        default = 12202;
        description = "Port of a GELF TCP input to push messages to";
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
    services.fluent-bit = {
      enable = true;
      settings = {
        service.log_level = "warn";
        pipeline = {
          inputs = [
            {
              name = "systemd";
              tag = "journal.*";

              read_from_tail = true;
              lowercase = true;
              strip_underscores = true;
            }
          ];
          outputs = [
            {
              name = "gelf";
              match = "journal.*";

              host = cfg.logs.target;
              port = cfg.logs.port;
              mode = "tcp";

              gelf_short_message_key = "message";
              gelf_host_key = "hostname";
              gelf_level_key = "priority";
            }
          ];
        };
      };
    };
  };
}
