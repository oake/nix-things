{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.monitoring;
  # journald priority -> level names VictoriaLogs' UI recognises
  levelNames = [
    "emerg"
    "alert"
    "crit"
    "err"
    "warning"
    "notice"
    "info"
    "debug"
  ];
  output =
    cfg.logs.mkOutput [
      "host"
      "log_source"
      "syslog_identifier"
      "compose_stack"
      "compose_service"
    ]
    // {
      "storage.total_limit_size" = "1G";
    };
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
          service = {
            log_level = "warn";
            "storage.path" = "/var/lib/fluent-bit/buffer";
          };
          pipeline = {
            inputs =
              (lib.optional cfg.logs.system.enable {
                name = "systemd";
                tag = "journal.*";

                db = "/var/lib/fluent-bit/systemd.db";
                read_from_tail = true;
                "storage.type" = "filesystem";
                "storage.pause_on_chunks_overlimit" = "on";
                lowercase = true;
                strip_underscores = true;
              })
              ++ (lib.optional cfg.logs.docker.enable {
                name = "forward";
                unix_path = "/run/fluent-bit/fluent-bit.sock";
                "storage.type" = "filesystem";
              });
            filters =
              (lib.optionals cfg.logs.system.enable (
                [
                  {
                    name = "modify";
                    match = "journal.*";
                    add = [
                      "log_source systemd"
                    ];
                    rename = [
                      "hostname host"
                    ];
                  }
                ]
                ++ lib.imap0 (priority: level: {
                  name = "modify";
                  match = "journal.*";
                  condition = "Key_value_equals priority ${toString priority}";
                  add = "level ${level}";
                }) levelNames
              ))
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
            outputs = [ output ];
          };
        };
      };
      systemd.services.fluent-bit.serviceConfig = {
        RuntimeDirectory = "fluent-bit";
        RuntimeDirectoryMode = "0755";
        StateDirectory = "fluent-bit";
        StateDirectoryMode = "0755";
      }
      // lib.optionalAttrs (cfg.logs.tokenFile != null) {
        EnvironmentFile = cfg.logs.tokenFile;
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
