{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs._1password-gui;
  desktopFile = "${cfg.package}/share/applications/com.onepassword.OnePassword.desktop";
in
{
  options.programs._1password-gui.autostart = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = "Automatically start 1Password GUI on login.";
    };
    silent = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Start 1Password GUI minimized to tray when autostarting.";
    };
  };

  config = lib.mkMerge [
    {
      programs._1password-gui.polkitPolicyOwners = [ config.me.username ];
    }
    (lib.mkIf cfg.autostart.enable {
      environment.etc."xdg/autostart/1password.desktop".source =
        if cfg.autostart.silent then
          pkgs.runCommand "1password-autostart.desktop" { } ''
            sed 's|^Exec=1password|Exec=1password --silent|' ${desktopFile} > $out
          ''
        else
          desktopFile;
    })
  ];
}
