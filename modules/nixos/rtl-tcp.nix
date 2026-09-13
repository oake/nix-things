{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.rtl-tcp;
  args = [
    "-a"
    cfg.listenAddress
    "-p"
    (toString cfg.port)
  ]
  ++ lib.optionals (cfg.device != null) [
    "-d"
    cfg.device
  ]
  ++ lib.optional cfg.biasTee "-T"
  ++ cfg.extraArgs;
in
{
  options.services.rtl-tcp = {
    enable = lib.mkEnableOption "RTL-SDR TCP server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.rtl-sdr-blog;
      defaultText = lib.literalExpression "pkgs.rtl-sdr-blog";
      description = "RTL-SDR package providing the rtl_tcp executable and udev rules.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which rtl_tcp listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 1234;
      description = "TCP port on which rtl_tcp listens.";
    };

    device = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "00000001";
      description = "Optional device index or serial number passed to rtl_tcp with -d.";
    };

    biasTee = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the RTL-SDR Blog bias tee with rtl_tcp's -T option.";
    };

    enableHardwareSupport = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable NixOS RTL-SDR udev rules, plugdev group, and DVB module blacklist.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the configured TCP port in the firewall.";
    };

    restartSec = lib.mkOption {
      type = lib.types.str;
      default = "2s";
      description = "Delay before systemd restarts rtl_tcp.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "-P"
        "1"
      ];
      description = "Additional command-line arguments passed verbatim to rtl_tcp.";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.rtl-sdr = lib.mkIf cfg.enableHardwareSupport {
      enable = true;
      package = cfg.package;
    };

    users.groups.rtl-tcp = { };
    users.users.rtl-tcp = {
      isSystemUser = true;
      group = "rtl-tcp";
      extraGroups = lib.optional cfg.enableHardwareSupport "plugdev";
    };

    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.port;

    systemd.services.rtl-tcp = {
      description = "RTL-SDR TCP server";
      documentation = [ "https://github.com/rtlsdrblog/rtl-sdr-blog" ];
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "systemd-udevd.service"
      ];

      serviceConfig = {
        User = "rtl-tcp";
        Group = "rtl-tcp";
        ExecStart = "${lib.getExe' cfg.package "rtl_tcp"} ${lib.escapeShellArgs args}";
        Restart = "always";
        RestartSec = cfg.restartSec;

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
      };
    };
  };
}
