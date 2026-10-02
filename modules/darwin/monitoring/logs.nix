{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.monitoring.logs;
  # Fluent Bit 5.1 fails to link the system zstd library on Darwin.
  fluent-bit = pkgs.fluent-bit.overrideAttrs (old: {
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [ (lib.cmakeBool "FLB_PREFER_SYSTEM_LIB_ZSTD" false) ];
  });
  settings = (pkgs.formats.yaml { }).generate "monitoring-fluent-bit.yaml" {
    service = {
      log_level = "warn";
      flush = 1;
    };
    parsers = [
      {
        name = "unified-log";
        format = "json";
      }
    ];
    pipeline = {
      inputs = [
        {
          name = "exec";
          tag = "macos.system";
          command = "/usr/bin/log stream --style ndjson --level info --predicate 'process != \"fluent-bit\" AND process != \"log\"'";
          parser = "unified-log";
          buf_size = "256K";
          threaded = true;
          oneshot = true;
          exit_after_oneshot = true;
        }
      ];
      filters = [
        {
          name = "modify";
          match = "*";
          add = [
            "host ${config.networking.hostName}"
            "log_source macos"
          ];
          rename = [ "eventMessage message" ];
        }
      ];
      outputs = [
        (cfg.mkOutput [
          "host"
          "log_source"
        ])
      ];
    };
  };
  start = pkgs.writeShellScript "monitoring-logs-start" ''
    ${lib.optionalString (cfg.tokenFile != null) ''
      if [ ! -r ${cfg.tokenFile} ]; then
        echo "monitoring-logs: ${cfg.tokenFile} is not readable yet, retrying"
        exit 1
      fi
      set -a
      . ${cfg.tokenFile}
      set +a
    ''}
    exec ${fluent-bit}/bin/fluent-bit --config ${settings}
  '';
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.docker.enable;
          message = "monitoring.logs.docker is only supported on NixOS; Darwin Docker runs in a separate VM.";
        }
      ];
    }
    (lib.mkIf cfg.system.enable {
      launchd.daemons.monitoring-logs.serviceConfig = {
        ProgramArguments = [ "${start}" ];
        UserName = "root";
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        ProcessType = "Background";
        StandardOutPath = "/var/log/monitoring-logs.log";
        StandardErrorPath = "/var/log/monitoring-logs.log";
      };
    })
  ];
}
