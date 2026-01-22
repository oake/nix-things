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
      port = lib.mkOption {
        type = lib.types.int;
        default = 12201;
        description = "Port of a GELF TCP input to push messages to";
      };

      systemd = {
        enable = lib.mkEnableOption "pushing systemd logs to SIEM";
      };

      docker = {
        enable = lib.mkEnableOption "pushing Docker logs to SIEM";
      };
    };
  };
  config = lib.mkMerge [
    (lib.mkIf (cfg.logs.systemd.enable || cfg.logs.docker.enable) {
      services.fluent-bit = {
        enable = true;
        settings = {
          service.log_level = "warn";
          pipeline = {
            inputs =
              (lib.optional cfg.logs.systemd.enable {
                name = "systemd";
                tag = "journal.*";

                db = "/var/lib/fluent-bit/systemd.db";
                read_from_tail = true;
                lowercase = true;
                strip_underscores = true;
              })
              ++ (lib.optional cfg.logs.docker.enable {
                name = "forward";
                unix_path = "/run/fluent-bit/fluent-bit.sock";
              });
            filters =
              (lib.optional cfg.logs.systemd.enable {
                name = "modify";
                match = "journal.*";
                add = [
                  "log_source systemd"
                ];
                rename = [
                  "hostname host"
                  "priority level"
                ];
              })
              ++ (lib.optionals cfg.logs.docker.enable [
                {
                  name = "nest";
                  match = "docker.*";
                  operation = "lift";
                  nested_under = "attrs";
                }
                {
                  name = "modify";
                  match = "docker.*";
                  add = [
                    "log_source docker"
                    "host \${HOSTNAME}"
                  ];
                  rename = [
                    "log message"
                    "com.docker.compose.project compose_stack"
                    "com.docker.compose.service compose_service"
                  ];
                }
              ]);
            outputs = [
              {
                name = "gelf";
                match = "*";

                host = cfg.logs.target;
                port = cfg.logs.port;
                mode = "tcp";

                gelf_short_message_key = "message";
              }
            ];
          };
        };
      };
      systemd.services.fluent-bit.serviceConfig = {
        RuntimeDirectory = "fluent-bit";
        RuntimeDirectoryMode = "0755";
        StateDirectory = "fluent-bit";
        StateDirectoryMode = "0755";
      };
      systemd.services.fluent-bit.environment = {
        HOSTNAME = "%H";
      };
      disko.simple.impermanence.persist.directories = [
        {
          directory = "/var/lib/private/fluent-bit";
          mode = "0700";
        }
      ];
    })
    (lib.mkIf cfg.logs.docker.enable {
      virtualisation.docker.daemon.settings = {
        log-driver = "fluentd";
        log-opts = {
          fluentd-address = "unix:///run/fluent-bit/fluent-bit.sock";
          fluentd-async = "true";
          tag = "docker.{{.ImageName}}/{{.Name}}/{{.ID}}";
          labels = "com.docker.compose.project,com.docker.compose.service";
        };
      };
    })
  ];
}
