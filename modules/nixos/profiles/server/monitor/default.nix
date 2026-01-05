{
  config,
  lib,
  ...
}:
{
  imports = [
    ./nginx.nix
    ./graylog.nix
  ];

  options.profiles.server.monitor = {
    enable = lib.mkEnableOption "monitor server profile";

    secretsDomain = lib.mkOption {
      type = lib.types.str;
      default = "lxc-monitor";
      description = "The subpath for the agenix secrets.";
    };

    storageDir = lib.mkOption {
      type = lib.types.str;
      default = "/storage";
      description = "The directory for storing monitoring services data.";
    };

    webDomain = lib.mkOption {
      type = lib.types.str;
      default = "monitor.${config.me.lanDomain}";
      description = "The domain for the web server.";
    };
  };

  config = lib.mkIf config.profiles.server.monitor.enable {
    profiles.server.enable = lib.mkForce true;
  };
}
