{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.cisco;
  httpEnabled = cfg.enable && cfg.httpPort != null;
  tftpEnabled = cfg.enable && cfg.tftpPort != null;
  serve = mode: port: [
    "${cfg.serveBin}/bin/cisco-serve"
    mode
    "--root"
    (toString cfg.serverRoot)
    "--bind"
    cfg.bindHost
    "--port"
    (toString port)
  ]
  ++ lib.optionals (cfg.secretsPath != null) [
    "--secrets"
    cfg.secretsPath
  ];
in
{
  config = {
    launchd.daemons.cisco-config-http = lib.mkIf httpEnabled {
      serviceConfig = {
        ProgramArguments = serve "http" cfg.httpPort;
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/cisco-config-http.log";
        StandardErrorPath = "/var/log/cisco-config-http.log";
      };
    };

    launchd.daemons.cisco-config-tftp = lib.mkIf tftpEnabled {
      serviceConfig = {
        ProgramArguments = serve "tftp" cfg.tftpPort;
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/cisco-config-tftp.log";
        StandardErrorPath = "/var/log/cisco-config-tftp.log";
      };
    };
  };
}
