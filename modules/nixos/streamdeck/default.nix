{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.streamdeck;
  yaml = pkgs.formats.yaml { };

  inherit (import ./config.nix { inherit lib config pkgs; }) mkConfigOption mkConfig fixConfig;

  brokenConfigFile = yaml.generate "streamdeck-config-broken.yaml" mkConfig;
  configFile = fixConfig "streamdeck-config.yaml" brokenConfigFile;
in
{
  options.services.streamdeck = with lib; {
    enable = mkEnableOption "Stream Deck service";

    package = mkOption {
      type = types.package;
      default = pkgs.streamdeck;
    };

    logLevel = mkOption {
      type = types.enum [
        "debug"
        "info"
        "warn"
        "error"
        "fatal"
      ];
      default = "info";
    };

    productId = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Specify Stream Deck to use (use streamdeck --list to find ID), default first found
      '';
    };

    config = mkConfigOption;
  };

  config = lib.mkIf cfg.enable {
    services.udev.packages = [
      (pkgs.writeTextFile {
        name = "70-streamdeck.rules";
        destination = "/etc/udev/rules.d/70-streamdeck.rules";
        text = ''
          SUBSYSTEM=="misc", KERNEL=="uinput", TAG+="uaccess", OPTIONS+="static_node=uinput"
          SUBSYSTEM=="hidraw", ACTION=="add", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d|006c|0063|0090", \
          SYMLINK+="streamdeck-%k", \
          TAG+="uaccess", \
          TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="streamdeck"
        '';
      })
    ];

    hardware.uinput.enable = true;

    systemd.user.paths.streamdeck-autostart = {
      description = "Launch Stream Deck tool on login";

      wantedBy = [ "default.target" ];

      pathConfig = {
        PathExistsGlob = "/dev/streamdeck-*";
        Unit = "streamdeck.service";
      };
    };

    systemd.user.services.streamdeck = {
      description = "Stream Deck tool";

      unitConfig = {
        StopWhenUnneeded = true;
      };

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;
        ExecStart =
          let
            args = [
              "--config=${configFile}"
              "--log-level=${cfg.logLevel}"
            ] ++ lib.optional (cfg.productId != null) "--product-id=${cfg.productId}";
          in
          "${lib.getExe cfg.package} ${lib.escapeShellArgs args}";
      };
    };
  };
}
