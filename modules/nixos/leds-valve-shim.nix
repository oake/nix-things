{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.leds-valve-shim;

  writableAttrs = [
    "enabled"
    "effect"
    "multi_intensity"
    "brightness"
    "delay"
  ];

  sysfsAttrPaths = lib.concatMapStringsSep " " (attr: "/sys$env{DEVPATH}/${attr}") writableAttrs;
in
{
  options.hardware.leds-valve-shim = {
    enable = lib.mkEnableOption "Valve LED sysfs shim for Steam front light bar integration";

    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
      description = "Group allowed to write the Steam-facing valve-leds sysfs attributes.";
    };

    debugLog = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable debug logging for writes handled by the leds-valve-shim kernel module.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.extraModulePackages = [
      config.boot.kernelPackages.leds-valve-shim
    ];

    boot.kernelModules = [
      "leds-valve-shim"
    ];

    boot.extraModprobeConfig = lib.mkIf cfg.debugLog ''
      options leds-valve-shim debug_log=1
    '';

    services.udev.packages = [
      (pkgs.writeTextFile {
        name = "leds-valve-shim-udev-rules";
        destination = "/etc/udev/rules.d/70-leds-valve-shim.rules";
        text = ''
          ACTION=="add|change", SUBSYSTEM=="leds", KERNEL=="valve-leds*", RUN+="${pkgs.coreutils}/bin/chgrp ${cfg.group} ${sysfsAttrPaths}", RUN+="${pkgs.coreutils}/bin/chmod g+w ${sysfsAttrPaths}"
        '';
      })
    ];
  };
}
