{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.teams-for-linux;
  flags =
    cfg.extraFlags
    ++ lib.optional cfg.settings.disablePinch "--disable-pinch"
    ++ lib.optionals cfg.watchcat.enable [
      "--awayOnSystemIdle=true"
      "--idleDetection.forceState"
      "--idleDetection.stateFile=${cfg.watchcat.stateFile}"
    ];
  teamsPackage =
    if flags == [ ] then
      cfg.package
    else
      cfg.package.overrideAttrs (old: {
        installPhase =
          let
            marker = ''--add-flags "$out/share/teams-for-linux/app.asar" \'';
          in
          if lib.hasInfix marker old.installPhase then
            builtins.replaceStrings
              [ marker ]
              [
                ''
                  --add-flags "$out/share/teams-for-linux/app.asar" \
                  --add-flags ${lib.escapeShellArg (lib.escapeShellArgs flags)} \''
              ]
              old.installPhase
          else
            throw "programs.teams-for-linux: cannot find the app.asar wrapper flags in the package installPhase";
      });
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
  watcher = pkgs.writeShellScript "watchcat" ''
    export GI_TYPELIB_PATH="${pkgs.glib.out}/lib/girepository-1.0''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
    exec ${python}/bin/python3 ${./watchcat.py} \
      --state-file ${lib.escapeShellArg cfg.watchcat.stateFile} \
      --forced-state ${lib.escapeShellArg cfg.watchcat.forcedState} \
      --interval ${toString cfg.watchcat.checkInterval}
  '';
in
{
  options.programs.teams-for-linux = {
    enable = lib.mkEnableOption "Teams for Linux";

    package = lib.mkPackageOption pkgs "teams-for-linux" { };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--disable-pinch" ];
      description = "Additional arguments passed to Teams for Linux.";
    };

    settings.disablePinch = lib.mkEnableOption "disabling pinch gestures in Teams for Linux";

    watchcat.enable = lib.mkEnableOption "syncing systemd sleep inhibitors to Teams for Linux";

    watchcat.forcedState = lib.mkOption {
      type = lib.types.enum [
        "active"
        "inactive"
      ];
      default = "active";
      description = "State written to the Teams idle-state file while sleep is inhibited.";
    };

    watchcat.stateFile = lib.mkOption {
      type = lib.types.str;
      default = "/tmp/teams-for-linux-idle-state-$USER";
      description = ''
        State file shared with Teams for Linux's idleDetection.stateFile.
        Environment variables are expanded by watchcat at runtime. The default
        matches Teams for Linux's default path. Use a dedicated file: watchcat
        writes forcedState while a matching inhibitor exists and deletes it otherwise.
      '';
    };

    watchcat.checkInterval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = ''
        Seconds between file reconciliations, including recreating the file
        after Teams for Linux removes it on exit. Inhibitor changes are also
        handled immediately through D-Bus notifications.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ teamsPackage ];

    systemd.user.services.watchcat = lib.mkIf cfg.watchcat.enable {
      description = "Sync systemd sleep inhibitors to Teams for Linux's activity override";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = watcher;
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
      };
    };
  };
}
