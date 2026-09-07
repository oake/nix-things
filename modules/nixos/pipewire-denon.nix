{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.pipewire-denon;
in
{
  options.services.pipewire-denon = {
    enable = lib.mkEnableOption "Denon AVR volume control through a native PipeWire sink";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.pipewire-denon;
      defaultText = lib.literalExpression "pkgs.pipewire-denon";
      description = "The pipewire-denon package.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      description = "User whose PipeWire session owns the sink and AVR connection.";
      example = "gamer";
    };
    displayName = lib.mkOption {
      type = lib.types.str;
      default = "Denon AVR";
      description = "Output device name displayed by KDE, Steam and other audio clients.";
    };
    targetNode = lib.mkOption {
      type = lib.types.str;
      description = "Underlying PCM sink's stable node.name, not a numeric ID or ALSA card name.";
      example = "alsa_output.pci-0000_03_00.1.hdmi-surround-extra3";
    };
    host = lib.mkOption {
      type = lib.types.str;
      description = "Hostname or IP address of the Denon AVR.";
      example = "iot-avr.lan.al";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 23;
      description = "Denon control TCP port.";
    };
    makeDefault = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Select the wrapper as the default output when it becomes available.";
    };
  };
  config = lib.mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      pulse.enable = lib.mkDefault true;
      wireplumber.enable = true;
    };
    systemd.user.services.pipewire-denon = {
      description = "PipeWire Denon AVR output";
      wantedBy = [ "pipewire.service" ];
      after = [
        "pipewire.service"
        "wireplumber.service"
      ];
      requires = [ "pipewire.service" ];
      partOf = [ "pipewire.service" ];
      unitConfig.ConditionUser = cfg.user;
      serviceConfig = {
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe cfg.package)
            "--host"
            cfg.host
            "--port"
            (toString cfg.port)
            "--target"
            cfg.targetNode
            "--name"
            cfg.displayName
          ]
          ++ lib.optional (!cfg.makeDefault) "--no-default"
        );
        Restart = "on-failure";
        RestartSec = 2;
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        UMask = "0077";
      };
    };
  };
}
