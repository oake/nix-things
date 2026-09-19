{
  config,
  lib,
  ...
}:
let
  cfg = config.monitoring.metrics;
in
{
  options.monitoring.metrics = {
    enable = lib.mkEnableOption "pushing metrics to Beszel";
    gpu = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "amd"
          "nvidia"
        ]
      );
      default = null;
      description = "GPU monitoring backend. Null leaves Beszel's automatic detection unchanged.";
    };
    targetUrl = lib.mkOption {
      type = lib.types.str;
      example = "https://beszel.example.com";
      description = "URL of the Beszel hub.";
    };
    sshKey = lib.mkOption {
      type = lib.types.str;
      example = "ssh-ed25519 AAAA...";
      description = "Public SSH key of the Beszel hub, used to verify its identity.";
    };
    tokenFile = lib.mkOption {
      type = lib.types.str;
      example = lib.literalExpression "config.age.secrets.beszel-token.path";
      description = ''
        Absolute runtime path to a file containing only the Beszel registration token.
        The file is loaded through systemd credentials and may be owned by root.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.beszel.agent = {
      enable = true;
      dataDir = "/var/lib/beszel-agent";
      smartmon.enable = !config.lxc.enable;
      environment = {
        HUB_URL = cfg.targetUrl;
        KEY = cfg.sshKey;
        TOKEN_FILE = "%d/token";
        DISABLE_SSH = "true";
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
