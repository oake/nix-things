{
  lib,
  config,
  ...
}:
let
  cfg = config.boot.splash;
in
{
  options.boot.splash = with lib; {
    enable = mkEnableOption "boot splash screen";
    themePackage = mkOption {
      type = types.package;
      description = "The package providing the Plymouth theme to use.";
    };
    theme = mkOption {
      type = types.str;
      description = "The name of the Plymouth theme to use.";
    };
  };
  config = lib.mkIf cfg.enable {
    boot = {
      plymouth = {
        enable = true;
        themePackages = [ cfg.themePackage ];
        theme = cfg.theme;
      };
      consoleLogLevel = 3;
      initrd.verbose = false;
      kernelParams = [
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "udev.log_priority=3"
        "rd.systemd.show_status=auto"
        "fbcon=nodefer"
        "vt.global_cursor_default=0"
      ];
      loader.grub.splashImage = null;
    };

    disko.simple.impermanence.persist.files = [
      "/var/lib/plymouth/boot-duration"
    ];
  };
}
