{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.profiles.workstation.iphone.enable = lib.mkEnableOption "iPhone USB automounting" // {
    default = config.profiles.workstation.enable;
  };

  config = lib.mkIf config.profiles.workstation.iphone.enable {
    services.usbmuxd.enable = true;

    systemd.services.iphone-mount = {
      description = "Mount iPhone media";
      bindsTo = [ "dev-iphone.device" ];
      requires = [ "usbmuxd.service" ];
      after = [
        "dev-iphone.device"
        "usbmuxd.service"
      ];
      unitConfig.StartLimitIntervalSec = 0;
      path = [
        pkgs.coreutils
        pkgs.util-linux
      ];
      # GVFS discovers mounts directly under /run/media; the public link stays absent until mounted.
      script = ''
        deadline=$((SECONDS + 120))
        while (( SECONDS < deadline )); do
          if error=$(timeout --kill-after=1s 10s mount -t fuse3 \
            -o nosuid,nodev,allow_other,default_permissions,gid=${toString config.users.groups.users.gid},umask=007 \
            ${pkgs.ifuse}/bin/ifuse /run/media/iPhone 2>&1); then
            # Publish only a successful mount; don't retry an occupied public path.
            ln -sT /run/media/iPhone /mnt/iPhone || exit 78
            exit 0
          fi
          sleep 1
        done
        error="''${error%%$'\n'*}"
        echo "iPhone mount unavailable; retrying: ''${error:-mount timed out}" >&2
        exit 1
      '';
      postStop = ''
        if [ "$(readlink /mnt/iPhone 2>/dev/null)" = /run/media/iPhone ]; then
          rm /mnt/iPhone
        fi
        if mountpoint -q /run/media/iPhone; then
          umount -l /run/media/iPhone
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "media/iPhone";
        RuntimeDirectoryMode = "0700";
        TimeoutStartSec = "150s";
        Restart = "on-failure";
        RestartSec = "1s";
        RestartPreventExitStatus = [ 78 ];
      };
    };

    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="05ac", ATTR{idProduct}=="12[9a][0-9a-f]", TAG+="systemd", ENV{SYSTEMD_ALIAS}+="/dev/iphone", ENV{SYSTEMD_WANTS}+="iphone-mount.service"
    '';

    environment.systemPackages = [ pkgs.libimobiledevice ];
  };
}
