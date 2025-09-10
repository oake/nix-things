{
  config,
  lib,
  ...
}:
{
  imports = [
    ./share
    ./net-router
  ];

  config = lib.mkIf config.profiles.server.enable {
    networking.firewall.enable = false;

    nixpkgs.flake = {
      setNixPath = false;
      setFlakeRegistry = false;
    };

    environment.defaultPackages = [ ];

    programs.bash.completion.enable = false;
    programs.command-not-found.enable = false;

    documentation.enable = false;

    xdg.icons.enable = false;
    xdg.mime.enable = false;
    xdg.sounds.enable = false;

    nix.settings.auto-optimise-store = true;
  };
}
