{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.monitoring.metrics;
  start = pkgs.writeShellScript "beszel-agent-start" ''
    /bin/mkdir -p /var/lib/beszel-agent
    /bin/chmod 0700 /var/lib/beszel-agent

    if [ ! -r ${cfg.tokenFile} ]; then
      echo "beszel-agent: ${cfg.tokenFile} is not readable yet, retrying"
      exit 1
    fi

    exec ${pkgs.beszel}/bin/beszel-agent
  '';
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.gpu == null || cfg.gpu == "apple";
        message = "Darwin monitoring.metrics.gpu must be null or apple.";
      }
      {
        assertion = cfg.gpu != "apple" || pkgs.stdenv.hostPlatform.isAarch64;
        message = "monitoring.metrics.gpu = apple requires Apple Silicon.";
      }
    ];
    launchd.daemons.beszel-agent = {
      command = "${start}";
      serviceConfig = {
        UserName = "root";
        EnvironmentVariables = {
          HUB_URL = cfg.targetUrl;
          KEY = cfg.sshKey;
          TOKEN_FILE = cfg.tokenFile;
          DATA_DIR = "/var/lib/beszel-agent";
          DISABLE_SSH = "true";
          SKIP_GPU = lib.boolToString (cfg.gpu == null);
          SKIP_SYSTEMD = "true";
          PATH =
            lib.makeBinPath ([ pkgs.smartmontools ] ++ lib.optional (cfg.gpu == "apple") pkgs.macmon)
            + ":/usr/bin:/bin:/usr/sbin:/sbin";
        }
        // lib.optionalAttrs (cfg.namePrefixes != [ ]) {
          SYSTEM_NAME = lib.concatStringsSep " / " (cfg.namePrefixes ++ [ config.networking.hostName ]);
        }
        // lib.optionalAttrs (cfg.gpu == "apple") { GPU_COLLECTOR = "macmon"; };
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        ProcessType = "Background";
        StandardOutPath = "/var/log/beszel-agent.log";
        StandardErrorPath = "/var/log/beszel-agent.log";
      };
    };
  };
}
