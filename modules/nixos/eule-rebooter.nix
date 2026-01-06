{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.eule-rebooter;
in
{
  options.services.eule-rebooter = {
    enable = lib.mkEnableOption "eule-rebooter";

    booterEndpoint = lib.mkOption {
      type = lib.types.str;
      default = "http://eule-booter.lan.al";
      description = "HTTP endpoint of eule-booter";
    };

    expectedBootOption = lib.mkOption {
      type = lib.types.str;
      default = "0";
      description = "Expected boot option, will reboot if not matched";
    };

    pollInterval = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Interval in seconds between polls, set 0 to check once";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.eule-rebooter = {
      description = "Reboots Eule when told by eule-booter";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        ${lib.getExe pkgs.eule-rebooter} \
          -b ${lib.escapeShellArg cfg.booterEndpoint} \
          -e ${lib.escapeShellArg cfg.expectedBootOption} \
          -p ${lib.escapeShellArg (toString cfg.pollInterval)}
      '';
      serviceConfig = {
        Restart = "on-failure";
      };
    };
  };
}
