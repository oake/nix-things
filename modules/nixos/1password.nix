{
  config,
  unstable,
  lib,
  ...
}:
{
  options = {
    programs._1password-gui.autoStart = lib.mkOption {
      type = lib.types.bool;
      default = config.programs._1password-gui.enable;
      description = "Automatically start 1Password GUI on login.";
    };
  };

  config =
    {
      programs._1password-gui = {
        package = unstable._1password-gui;
        polkitPolicyOwners = [ config.me.username ];
      };
    }
    // lib.mkIf config.programs._1password-gui.autoStart {
      environment.etc."xdg/autostart/1password.desktop".source = (
        config.programs._1password-gui.package + "/share/applications/1password.desktop"
      );
    };
}
