{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.t3-server;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
  defaultUser = "t3-server";
in
{
  options.services.t3-server = {
    enable = mkEnableOption "the T3 Code server (`t3 serve`)";
    package = lib.mkPackageOption pkgs "t3-server" { };

    user = mkOption {
      type = types.str;
      default = defaultUser;
      description = ''
        User the server and every agent it spawns run as. Agent logins and
        configuration live in this user's home. The default user is created
        with its home in /var/lib/t3-server; any other user must already exist.
      '';
    };

    group = mkOption {
      type = types.str;
      default = defaultUser;
      description = "Group of the server process.";
    };

    host = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "127.0.0.1";
      description = ''
        Interface to bind (`T3CODE_HOST`). Null binds 0.0.0.0 restricted to
        private-network clients when `lan` is set, and loopback otherwise.
        An explicit host disables the private-network restriction.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 3773;
      description = "HTTP/WebSocket port (`T3CODE_PORT`).";
    };

    lan = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Accept connections from private networks, not only this machine
        (`T3CODE_LAN`). Needed when a reverse proxy on another host forwards
        to the server.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open `port` in the firewall.";
    };

    baseDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/var/lib/t3-server/.t3";
      description = "T3 Code data directory (`T3CODE_HOME`); null uses ~/.t3 of `user`.";
    };

    workingDirectory = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Default working directory for provider sessions; null uses the home of `user`.";
    };

    browserExecutable = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = lib.literalExpression "lib.getExe pkgs.chromium";
      description = ''
        Chromium-based browser for previews and agent browser use
        (`T3CODE_BROWSER_EXECUTABLE`). Null leaves the feature unavailable,
        since T3's own download of chrome-headless-shell cannot run on NixOS.
      '';
    };

    path = mkOption {
      type = types.listOf (types.either types.package types.str);
      default = [ ];
      example = lib.literalExpression ''[ pkgs.nodejs "/etc/profiles/per-user/alice" ]'';
      description = ''
        Extra packages, or prefixes whose `bin` directory is used, on the
        server's PATH. Agents (codex, claude, opencode, …) are found here.
        The user's home-manager profile and the system profile are always
        included after these.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        T3CODE_SERVER_BROWSER_SANDBOX = "0";
      };
      description = "Extra environment variables for the server.";
    };
  };

  config = mkIf cfg.enable {
    users = lib.mkIf (cfg.user == defaultUser) {
      users.${defaultUser} = {
        isSystemUser = true;
        group = cfg.group;
        home = "/var/lib/t3-server";
        createHome = true;
      };
      groups.${defaultUser} = { };
    };

    environment.systemPackages = [ cfg.package ];

    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.port;

    systemd.services.t3-server = {
      description = "T3 Code server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      path = cfg.path ++ [
        pkgs.git
        pkgs.openssh
        "/etc/profiles/per-user/${cfg.user}"
        "/run/current-system/sw"
      ];

      environment = {
        T3CODE_PORT = toString cfg.port;
        T3CODE_LAN = lib.boolToString cfg.lan;
      }
      // lib.optionalAttrs (cfg.host != null) { T3CODE_HOST = cfg.host; }
      // lib.optionalAttrs (cfg.baseDir != null) { T3CODE_HOME = cfg.baseDir; }
      // lib.optionalAttrs (cfg.browserExecutable != null) {
        T3CODE_BROWSER_EXECUTABLE = cfg.browserExecutable;
      }
      // cfg.environment;

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${lib.getExe cfg.package} serve";
        # systemd's ~ is the home of User=
        WorkingDirectory = if cfg.workingDirectory != null then cfg.workingDirectory else "~";
        Restart = "on-failure";
        RestartSec = 5;
        # SIGTERM only the server so it can stop its agents itself; the rest is SIGKILLed once it exits
        KillMode = "mixed";
      };
    };
  };
}
