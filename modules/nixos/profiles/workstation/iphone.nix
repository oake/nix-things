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
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p -m 0700 /mnt/iPhone";
        ExecStart = "${pkgs.util-linux}/bin/mount -t fuse3 -o nosuid,nodev,allow_other,default_permissions,gid=${toString config.users.groups.users.gid},umask=007,x-gvfs-show,x-gvfs-name=iPhone,x-gvfs-icon=phone ${pkgs.ifuse}/bin/ifuse /mnt/iPhone";
        ExecStopPost = [
          "-${pkgs.util-linux}/bin/umount -l /mnt/iPhone"
          "-${pkgs.coreutils}/bin/rmdir /mnt/iPhone"
        ];
        Restart = "on-failure";
        RestartSec = "3s";
        TimeoutStartSec = "120s";
      };
    };

    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="05ac", ATTR{idProduct}=="12[9a][0-9a-f]", TAG+="systemd", ENV{SYSTEMD_ALIAS}+="/dev/iphone", ENV{SYSTEMD_WANTS}+="iphone-mount.service"
    '';

    environment.systemPackages = [ pkgs.libimobiledevice ];
  };
}
