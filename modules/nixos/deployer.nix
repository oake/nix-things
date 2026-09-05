{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.deployer;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
in
{
  options.services.deployer = {
    enable = mkEnableOption "automatic boot deployments of CI-cached NixOS configurations";
    package = lib.mkPackageOption pkgs "deployer" { };
    githubRepo = mkOption {
      type = types.str;
      example = "anna-oake/nixos-config";
      description = "Public GitHub repository in owner/repository format.";
    };
    hosts = mkOption {
      type = types.nonEmptyListOf types.str;
      example = [
        "eule"
        "star"
      ];
      description = "NixOS configuration and deploy-rs node names to deploy.";
    };
    atticServer = mkOption {
      type = types.str;
      example = "attic.oa.ke";
      description = "Attic server domain or HTTP(S) URL without a path.";
    };
    atticCache = mkOption {
      type = types.str;
      example = "nixos";
      description = "Public Attic cache name.";
    };
    atticTokenFile = mkOption {
      type = types.strMatching "/.+";
      example = "/run/agenix/lxc-builder/deploy-attic-token";
      description = "Absolute runtime path to an Attic token with pull access to the cache.";
    };
    dataPath = mkOption {
      type = types.strMatching "/.+";
      default = "/var/lib/deployer";
      description = "Absolute directory for the checkout and persistent deployment state.";
    };
    sshKeyFile = mkOption {
      type = types.strMatching "/.+";
      example = "/run/agenix/deployer-ssh-key";
      description = ''
        Absolute runtime path to an unencrypted deployment SSH private key.
        May be set to config.age.secrets.deployer-ssh-key.path. Systemd loads
        the key as a credential and a service-local SSH agent supplies it to
        deploy-rs and Nix.
      '';
    };
    interval = mkOption {
      type = types.str;
      default = "60s";
      description = "Polling interval as a positive Go duration.";
    };
  };

  config = mkIf cfg.enable {
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    systemd.services.deployer = {
      description = "Deploy CI-cached NixOS configurations for next boot";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "nix-daemon.service"
      ];
      path = [
        pkgs.git
        pkgs.nix
        pkgs.deploy-rs
        pkgs.openssh
      ];
      environment = {
        GITHUB_REPO = cfg.githubRepo;
        DATA_PATH = cfg.dataPath;
        HOSTS = lib.concatStringsSep "," cfg.hosts;
        ATTIC_SERVER = cfg.atticServer;
        ATTIC_CACHE = cfg.atticCache;
        INTERVAL = cfg.interval;
        HOME = "/root";
      };
      serviceConfig = {
        SyslogIdentifier = "deployer";
        User = "root";
        ExecStart = "${pkgs.openssh}/bin/ssh-agent ${pkgs.writeShellScript "deployer-with-key" ''
          set -eu
          ${pkgs.openssh}/bin/ssh-add -q "$CREDENTIALS_DIRECTORY/ssh-key" < /dev/null
          export ATTIC_TOKEN_FILE="$CREDENTIALS_DIRECTORY/attic-token"
          exec ${lib.getExe cfg.package}
        ''}";
        LoadCredential = [
          "ssh-key:${cfg.sshKeyFile}"
          "attic-token:${cfg.atticTokenFile}"
        ];
        Restart = "on-failure";
        RestartSec = "10s";
        UMask = "0077";
        TimeoutStopSec = "15s";
      };
    };
  };
}
