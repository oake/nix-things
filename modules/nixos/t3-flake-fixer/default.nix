{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.t3-flake-fixer;
  inherit (lib) mkOption types;
  home = config.users.users.${cfg.user}.home;
  settings = pkgs.writeText "t3-flake-fixer.json" (
    builtins.toJSON {
      inherit (cfg)
        repositories
        prompt
        listenAddress
        buildbotUrl
        t3BaseDir
        ;
      t3Executable = lib.getExe cfg.t3Package;
      storageRoot = if cfg.storageRoot == null then "${home}/buildbot-failures" else cfg.storageRoot;
      secretFile = if cfg.secretFile == null then null else "%d/token";
    }
  );
in
{
  options.services.t3-flake-fixer = {
    enable = lib.mkEnableOption "Buildbot failure collection and T3 repair launches";
    package = lib.mkPackageOption pkgs "t3-flake-fixer" { };
    user = mkOption {
      type = types.str;
      description = "Existing user owning the T3 server and projects.";
    };
    repositories = mkOption {
      default = { };
      description = "Allowed repositories mapped to absolute local T3 project paths.";
      type = types.attrsOf types.str;
    };
    buildbotUrl = mkOption {
      type = types.strMatching "https?://.+";
      description = "Shared trusted Buildbot base URL, with or without a trailing slash.";
      example = "http://builder-buyan.me.ow";
    };
    storageRoot = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Absolute log directory; null uses buildbot-failures in the user's configured home.";
    };
    t3Package = lib.mkPackageOption pkgs "t3-server" { };
    t3BaseDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Explicit T3 data directory; null uses the configured user's ~/.t3.";
    };
    prompt = mkOption {
      type = types.str;
      description = "Repair prompt. Literal placeholders: {{repository}}, {{revision}}, {{parent_build_id}}, {{bundle_path}}, {{failed_steps}} (human-readable bullet list). Substitution is single-pass without shell evaluation.";
    };
    secretFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Runtime file containing the Bearer token; never put the secret in Nix. Null disables authentication.";
    };
    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0:9847";
      description = "HTTP listen host:port (IPv6 uses [address]:port); notifications are accepted at /buildbot-failure.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (p: lib.hasPrefix "/" p) (builtins.attrValues cfg.repositories);
        message = "t3-flake-fixer requires absolute project paths";
      }
    ];
    systemd.services.t3-flake-fixer = {
      description = "Buildbot failure receiver and T3 launcher";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment.HOME = home;
      serviceConfig = {
        User = cfg.user;
        WorkingDirectory = home;
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = 5;
        ExecStart = "${lib.getExe cfg.package} --config ${settings}";
      }
      // lib.optionalAttrs (cfg.secretFile != null) {
        LoadCredential = "token:${cfg.secretFile}";
      };
    };
  };
}
