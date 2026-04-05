{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.deploy.enable {
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
      deploy ALL = (root) NOPASSWD: /bin/rm /tmp/deploy-rs-canary-*
    '';
  };
}
