{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkMerge [
    (lib.mkIf config.infra.deploy.enable {
      users.knownUsers = [ "deploy" ];

      users.users.deploy = {
        isHidden = true;
        shell = pkgs.zsh;
      };

      system.activationScripts.postActivation.text = ''
        echo "allowing deploy over ssh"
        /usr/sbin/dseditgroup -o edit -a deploy -t user com.apple.access_ssh 2>/dev/null || true
      '';

      security.sudo.extraConfig = ''
        deploy ALL = (root) NOPASSWD: /nix/store/*-activatable-darwin-system-*/activate-rs
        deploy ALL = (root) NOPASSWD: /bin/rm /private/tmp/deploy-rs-canary-*
        deploy ALL = (root) NOPASSWD: /bin/rm /tmp/deploy-rs-canary-*
      '';
    })
    (lib.mkIf config.infra.beacon.enable {
      assertions = [
        {
          assertion = config.infra.flakeRepo != null;
          message = "infra.beacon requires infra.flakeRepo.";
        }
      ];
      launchd.daemons.infra-beacon.serviceConfig = {
        ProgramArguments = [
          "${pkgs.infra-beacon}/bin/infra-beacon"
          "-hub"
          config.infra.hubUrl
          "-host"
          "${config.infra.flakeRepo}/${config.networking.hostName}"
        ]
        ++ lib.optionals (config.infra.hubTokenFile != null) [
          "-token-file"
          config.infra.hubTokenFile
        ];
        RunAtLoad = true;
        StartInterval = 60;
        ProcessType = "Background";
        StandardErrorPath = "/var/log/infra-beacon.log";
      };
    })
  ];
}
