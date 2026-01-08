# big thanks to @judiantara - https://github.com/judiantara/wyrmling/blob/master/config/tpm-boot.nix
{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.boot.initrd.luks.devices ? crypted) {
    environment.systemPackages =
      let
        device = config.boot.initrd.luks.devices.crypted.device;

        cryptenroll = pkgs.writeShellScriptBin "cryptenroll" ''
          set -euo pipefail

          if [[ $EUID -ne 0 ]]; then
            echo "Please run as root"
            exit 1
          fi

          systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+12 --wipe-slot=tpm2 ${device}
          echo "Rebooting now..."
          sleep 3
          reboot
        '';
      in
      [
        cryptenroll
      ];
  };
}
