{ lib, ... }:
{
  options.monitoring.metrics = {
    enable = lib.mkEnableOption "pushing metrics to Beszel";
    namePrefixes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "kitezh"
        "mynah"
      ];
      description = ''
        Prefixes joined with " / " before networking.hostName to form Beszel's
        SYSTEM_NAME. An empty list leaves Beszel's default naming unchanged.
        Used when registering a new system with a universal token; existing
        systems must be renamed in the hub. Use lib.mkBefore or lib.mkAfter
        to control ordering when combining prefixes from multiple modules.
      '';
    };
    gpu = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "amd"
          "nvidia"
          "apple"
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
        The file is read at runtime and may be owned by root; never put its contents in Nix.
      '';
    };
  };

}
