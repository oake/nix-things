{
  config,
  lib,
  pkgs,
  hostName,
  ...
}:
let
  cfg = config.infra;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    mkMerge
    types
    ;
  tokenArgs = lib.optionals (cfg.hubTokenFile != null) [
    "-token-file"
    "%d/hub-token"
  ];
  tokenCredential = lib.optional (cfg.hubTokenFile != null) "hub-token:${cfg.hubTokenFile}";
  hubCommand = pkgs.writeShellScript "infra-hub-start" ''
    set -eu
    ${lib.optionalString (cfg.hub.githubTokenFile != null) ''
      export GITHUB_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/github-token")"
    ''}
    exec ${pkgs.infra-hub}/bin/infra-hub -data /var/lib/infra-hub -http-port ${toString cfg.hub.httpPort} -dix ${pkgs.dix-snapshots}/bin/dix
  '';
in
{
  options.infra = {
    deployer = {
      enable = mkEnableOption "infra repository deployment runner";
      sshKeyFile = mkOption {
        type = types.str;
        description = "Runtime path to the deployment SSH private key.";
      };
    };
    hub = {
      enable = mkEnableOption "infra hub";
      httpPort = mkOption {
        type = types.port;
        default = 8787;
        description = "HTTP port. The hub listens on 0.0.0.0.";
      };
      githubTokenFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional runtime GitHub token file for PR polling and Git fetches.";
      };
    };
  };
  config = mkMerge [
    (mkIf cfg.deploy.enable {
      users.users.deploy.isNormalUser = true;

      security.sudo.extraRules = [
        {
          users = [ "deploy" ];
          commands = [
            {
              command = "/nix/store/*-activatable-nixos-system-*/activate-rs";
              options = [ "NOPASSWD" ];
            }
            {
              command = "/run/current-system/sw/bin/rm /tmp/deploy-rs-canary-*";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    })
    (mkIf (cfg.beacon.enable || cfg.deployer.enable) {
      assertions = [
        {
          assertion = cfg.flakeRepo != null;
          message = "infra beacon/deployer requires infra.flakeRepo.";
        }
      ];
    })
    (mkIf cfg.beacon.enable {
      systemd.services.infra-beacon = {
        after = [ "network-online.target" ] ++ lib.optional cfg.hub.enable "infra-hub.service";
        wants = [ "network-online.target" ] ++ lib.optional cfg.hub.enable "infra-hub.service";
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          # A missed report must not roll back activation. The timer retries;
          # the beacon still logs the error (including an unenrolled host).
          SuccessExitStatus = [ 1 ];
          ExecStart = lib.escapeShellArgs (
            [
              "${pkgs.infra-beacon}/bin/infra-beacon"
              "-hub"
              cfg.hubUrl
              "-host"
              "${cfg.flakeRepo}/${hostName}"
            ]
            ++ tokenArgs
          );
          LoadCredential = tokenCredential;
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
        };
      };
      systemd.timers.infra-beacon = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "15s";
          OnUnitInactiveSec = "60s";
          RandomizedDelaySec = "10s";
        };
      };
    })
    (mkIf cfg.deployer.enable {
      systemd.services.infra-deployer = {
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "nix-daemon.service"
        ]
        ++ lib.optional cfg.hub.enable "infra-hub.service";
        wants = [ "network-online.target" ] ++ lib.optional cfg.hub.enable "infra-hub.service";
        path = [
          pkgs.nix
          pkgs.git
          pkgs.openssh
          pkgs.deploy-rs
        ];
        environment = {
          INFRA_HUB_URL = cfg.hubUrl;
          INFRA_REPOSITORY = cfg.flakeRepo;
        };
        serviceConfig = {
          User = "root";
          StateDirectory = "infra-deployer";
          WorkingDirectory = "/var/lib/infra-deployer";
          ExecStart = "${pkgs.openssh}/bin/ssh-agent ${pkgs.writeShellScript "infra-deployer-start" ''
            set -eu
            ${pkgs.openssh}/bin/ssh-add -q "$CREDENTIALS_DIRECTORY/ssh-key" < /dev/null
            ${lib.optionalString (
              cfg.hubTokenFile != null
            ) ''export INFRA_TOKEN_FILE="$CREDENTIALS_DIRECTORY/hub-token"''}
            exec ${pkgs.infra-deployer}/bin/infra-deployer -queue /var/lib/infra-deployer/queue.json
          ''}";
          LoadCredential = tokenCredential ++ [ "ssh-key:${cfg.deployer.sshKeyFile}" ];
          Restart = "on-failure";
          RestartSec = "10s";
          UMask = "0077";
        };
      };
    })
    (mkIf cfg.hub.enable {
      users.users.infra-hub = {
        isSystemUser = true;
        group = "infra-hub";
      };
      users.groups.infra-hub = { };
      systemd.services.infra-hub = {
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.git ];
        environment.GIT_SSL_CAINFO = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        after = [ "network.target" ];
        serviceConfig = {
          User = "infra-hub";
          Group = "infra-hub";
          StateDirectory = "infra-hub";
          ExecStart = hubCommand;
          LoadCredential = lib.optional (
            cfg.hub.githubTokenFile != null
          ) "github-token:${cfg.hub.githubTokenFile}";
          Restart = "on-failure";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
        };
      };
    })
  ];
}
