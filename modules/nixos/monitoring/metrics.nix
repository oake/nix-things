{
  config,
  lib,
  ...
}:
let
  cfg = config.monitoring.metrics;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.gpu != "apple";
        message = "monitoring.metrics.gpu = apple requires Darwin.";
      }
    ];
    services.beszel.agent = {
      enable = true;
      dataDir = "/var/lib/beszel-agent";
      smartmon.enable = !config.lxc.enable;
      environment = {
        HUB_URL = cfg.targetUrl;
        KEY = cfg.sshKey;
        TOKEN_FILE = "%d/token";
        DISABLE_SSH = "true";
        SKIP_GPU = lib.boolToString (cfg.gpu == null);
      }
      // lib.optionalAttrs (cfg.namePrefixes != [ ]) {
        SYSTEM_NAME = lib.concatStringsSep " / " (cfg.namePrefixes ++ [ config.networking.hostName ]);
      }
      // lib.optionalAttrs config.lxc.enable {
        SENSORS = "";
      }
      // lib.optionalAttrs (cfg.gpu == "amd") {
        GPU_COLLECTOR = "amd_sysfs";
      }
      // lib.optionalAttrs (cfg.gpu == "nvidia") {
        GPU_COLLECTOR = "nvml";
        LD_LIBRARY_PATH = "/run/opengl-driver/lib";
      };
    };

    users.users.beszel-agent = {
      isSystemUser = true;
      group = "beszel-agent";
    };
    users.groups.beszel-agent = { };

    systemd.services.beszel-agent.serviceConfig = {
      DynamicUser = lib.mkForce false;
      Group = "beszel-agent";
      StateDirectoryMode = "0700";
      NoNewPrivileges = lib.mkForce true;
      RemoveIPC = true;
      LoadCredential = [ "token:${cfg.tokenFile}" ];
      PrivateDevices = lib.mkIf (cfg.gpu == "nvidia") (lib.mkForce false);
    };

    disko.simple.impermanence.persist.directories = [
      {
        directory = "/var/lib/beszel-agent";
        user = "beszel-agent";
        group = "beszel-agent";
        mode = "0700";
      }
    ];
  };
}
