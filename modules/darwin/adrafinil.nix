{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.adrafinil;
  app = "${cfg.package}/Applications/Adrafinil.app";
  bundleID = "glass.kagerou.adrafinil";
in
{
  options.programs.adrafinil = {
    enable = lib.mkEnableOption "Adrafinil with declarative sleep-inhibition services";

    package = lib.mkPackageOption pkgs "adrafinil" { };

    launchAtLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to launch the menu-bar app at login for system.primaryUser.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    launchd.daemons.adrafinil-helper = {
      command = "${app}/Contents/Library/LaunchDaemons/AdrafinilHelper";
      serviceConfig = {
        Label = "${bundleID}.helper";
        MachServices."${bundleID}.helper" = true;
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
      };
    };

    launchd.user.agents.adrafinil-daemon = {
      command = "${app}/Contents/Library/LaunchAgents/AdrafinilDaemon";
      serviceConfig = {
        Label = "${bundleID}.daemon";
        MachServices."${bundleID}.daemon" = true;
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
      };
    };

    launchd.user.agents.adrafinil = lib.mkIf cfg.launchAtLogin {
      command = "${app}/Contents/MacOS/Adrafinil";
      serviceConfig = {
        Label = bundleID;
        RunAtLoad = true;
        KeepAlive = false;
        ProcessType = "Interactive";
        LimitLoadToSessionType = "Aqua";
      };
    };
  };
}
