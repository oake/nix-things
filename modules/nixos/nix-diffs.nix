{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nix-diffs;
in
{
  options.services.nix-diffs = {
    enable = lib.mkEnableOption "the Nix snapshot diff service";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nix-diffs;
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8787;
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
    };
    dataPath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/nix-diffs";
    };
  };
  config = lib.mkIf cfg.enable {
    users.users.nix-diffs = {
      isSystemUser = true;
      group = "nix-diffs";
    };
    users.groups.nix-diffs = { };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataPath} 0755 root root - -"
      "d ${cfg.dataPath}/diffs 0750 nix-diffs nix-diffs - -"
      "d ${cfg.dataPath}/repos 0750 nix-diffs nix-diffs - -"
    ];
    systemd.services.nix-diffs = {
      description = "Nix snapshot comparisons";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [
        pkgs.git
        pkgs.dix-snapshots
      ];
      environment = {
        GIT_SSL_CAINFO = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        DATA_PATH = cfg.dataPath;
        LISTEN_ADDR = "${cfg.listenAddress}:${toString cfg.port}";
      };
      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        User = "nix-diffs";
        Group = "nix-diffs";
        Restart = "on-failure";
        RestartSec = 3;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          "${cfg.dataPath}/diffs"
          "${cfg.dataPath}/repos"
        ];
        UMask = "0027";
      };
    };
  };
}
