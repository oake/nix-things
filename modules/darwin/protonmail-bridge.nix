{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.protonmail-bridge;
in
{
  options.services.protonmail-bridge = {
    enable = lib.mkEnableOption "protonmail bridge";

    package = lib.mkPackageOption pkgs "protonmail-bridge" { };

    path = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      example = lib.literalExpression "with pkgs; [ pass ]";
      description = "List of derivations to put in protonmail-bridge's path.";
    };

    logLevel = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "panic"
          "fatal"
          "error"
          "warn"
          "info"
          "debug"
        ]
      );
      default = null;
      description = "Log level of the Proton Mail Bridge service. If set to null then the service uses its default log level.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.user.agents.protonmail-bridge.serviceConfig = {
      ProgramArguments = [
        (lib.getExe cfg.package)
        "--noninteractive"
      ]
      ++ lib.optionals (cfg.logLevel != null) [
        "--log-level"
        cfg.logLevel
      ];

      EnvironmentVariables.PATH = lib.makeBinPath cfg.path + ":/usr/bin:/bin:/usr/sbin:/sbin";
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
    };

    environment.systemPackages = [ cfg.package ];
  };
}
