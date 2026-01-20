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
    machineType = lib.mkOption {
      type = lib.types.enum [
        "local"
        "remote"
        "mobile"
      ];
      default = "local";
    };

    logs = {
      target = lib.mkOption {
        type = lib.types.str;
        description = "Hostname or IP address to push messages to";
      };

      systemd = {
        enable = lib.mkEnableOption "pushing systemd logs to SIEM";
        port = lib.mkOption {
          type = lib.types.int;
          default = 12202;
          description = "Port of a GELF TCP input to push systemd messages to";
        };
      };

      docker = {
        enable = lib.mkEnableOption "pushing Docker logs to SIEM";
        port = lib.mkOption {
          type = lib.types.int;
          default = 12201;
          description = "Port of a GELF TCP input to push Dockermessages to";
        };
      };
    };
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.logs.systemd.enable {
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
                port = cfg.logs.systemd.port;
                mode = "tcp";

                gelf_short_message_key = "message";
                gelf_host_key = "hostname";
                gelf_level_key = "priority";
              }
            ];
          };
        };
      };
    })
    (lib.mkIf cfg.logs.docker.enable {
      virtualisation.docker.daemon.settings = {
        log-driver = "gelf";
        log-opts = {
          gelf-address = "tcp://${cfg.logs.target}:${toString cfg.logs.docker.port}";
          tag = "{{.ImageName}}/{{.Name}}/{{.ID}}";
          labels = "com.docker.compose.project,com.docker.compose.service";
          mode = "non-blocking";
          max-buffer-size = "4m";
        };
      };
    })
  ];
}
