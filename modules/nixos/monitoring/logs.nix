{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.monitoring;
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.logs.system.enable || cfg.logs.docker.enable) {
      services.fluent-bit = {
        enable = true;
        package = pkgs.fluent-bit.overrideAttrs (old: {
          # Avoid rewriting the persistent journal cursor every second while idle.
          patches = (old.patches or [ ]) ++ [ ./fluent-bit-cursor-on-change.patch ];
        });
        settings = {
          service.log_level = "warn";
          pipeline = {
            inputs =
              (lib.optional cfg.logs.system.enable {
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
              (lib.optional cfg.logs.system.enable {
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
