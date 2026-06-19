{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.framework-privacy-bar;
in
{
  options.programs.framework-privacy-bar = {
    enable = lib.mkEnableOption "Framework Privacy Bar tray app";

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to start Framework Privacy Bar automatically for desktop sessions.";
    };

    package = lib.mkPackageOption pkgs "framework-privacy-bar" { };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];

    services.udev.packages = [
      (pkgs.writeTextFile {
        name = "70-cros-ec.rules";
        destination = "/etc/udev/rules.d/70-cros-ec.rules";
        text = ''
          SUBSYSTEM=="misc", KERNEL=="cros_ec", TAG+="uaccess"
        '';
      })
    ];

    environment.etc."xdg/autostart/framework-privacy-bar.desktop" = lib.mkIf cfg.autoStart {
      source = "${cfg.package}/share/applications/framework-privacy-bar.desktop";
    };
  };
}
