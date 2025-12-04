{
  pkgs,
  config,
  lib,
  ...
}:
let
  service = "steam-lancache-prefill";
  cfg = config.services.lancache.prefill.steam;
in
{
  options.services.lancache.prefill.steam =
    let
      inherit (lib) mkEnableOption mkOption types;
    in
    {
      enable = mkEnableOption "Steam Prefill";
      onCalendar = mkOption {
        type = types.nullOr types.str;
        default = "daily";
        description = "Schedule for the OnCalendar property of the systemd timer. Set to null to disable the timer";
      };
      accounts = mkOption {
        type = types.attrsOf (
          types.submodule (
            { name, ... }:
            {
              options = {
                prefillAll = mkEnableOption "prefill all owned games";
                prefillRecent = mkEnableOption "prefill games played in the last 2 weeks";
                prefillRecentlyPurchased = mkEnableOption "prefill games purchased in the last 2 weeks";
                appIds = mkOption {
                  type = types.listOf types.int;
                  default = [ ];
                  example = [
                    1262350
                    620
                    220
                  ];
                  description = "Steam app IDs from this list will always be prefilled regardless of other options";
                };
                systems = mkOption {
                  type = types.listOf (
                    types.enum [
                      "windows"
                      "linux"
                      "macos"
                      "android"
                    ]
                  );
                  default = [ "windows" ];
                  description = "List of Steam systems to prefill games for";
                };
                tokenFile = mkOption {
                  type = types.str;
                  description = "Path to the accounts.config file with the Steam account token for this account";
                };
                workDir = mkOption {
                  type = types.str;
                  default = "/var/lib/lancache/steam-prefill/account-${name}";
                  description = "Path to the directory where the account data and logs will be stored";
                };
              };
            }
          )
        );
        default = { };
        description = "Steam accounts to prefill for";
      };
    };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.steam-lancache-prefill ];

    systemd.tmpfiles.rules = lib.mapAttrsToList (
      name: accountCfg:
      let
        configDir = "${accountCfg.workDir}/Config";
        selectedAppsFile = pkgs.writeText "steam-prefill-selected-apps-${name}.json" (
          builtins.toJSON accountCfg.appIds
        );
      in
      ''
        d ${configDir} 0750 root root - -
        L+ ${configDir}/selectedAppsToPrefill.json - root root - ${selectedAppsFile}
        L+ ${configDir}/account.config - root root - ${accountCfg.tokenFile}
      ''
    ) cfg.accounts;

    systemd.services =
      let
        accountNames = lib.attrNames cfg.accounts;
        prevMap = lib.listToAttrs (
          lib.imap (idx: name: {
            name = name;
            value = if idx == 1 then null else lib.elemAt accountNames (idx - 2);
          }) accountNames
        );
      in
      (lib.mapAttrs' (
        name: accountCfg:
        let
          prev = prevMap.${name};
        in
        {
          name = "${service}-${name}";
          value = {
            description = "Steam Prefill for account ${name}";
            wantedBy = [ "${service}.target" ];
            partOf = [ "${service}.target" ];
            after = lib.optional (prev != null) "${service}-${prev}.service";

            script = lib.concatStringsSep "\n" (
              map (system: ''
                echo "Running SteamPrefill for account ${name}, system ${system}..."
                ${pkgs.steam-lancache-prefill}/bin/SteamPrefill prefill --no-ansi \
                  ${lib.optionalString accountCfg.prefillAll "--all"} \
                  ${lib.optionalString accountCfg.prefillRecent "--recent"} \
                  ${lib.optionalString accountCfg.prefillRecentlyPurchased "--recently-purchased"} \
                  --os ${system}
              '') accountCfg.systems
            );

            serviceConfig = {
              Type = "oneshot";
              User = "root";
              WorkingDirectory = accountCfg.workDir;
            };

            stopIfChanged = false;
            restartIfChanged = false;
          };
        }
      ) cfg.accounts)
      // {
        ${service} = {
          description = "Steam Prefill (all accounts)";
          wants = lib.mapAttrsToList (name: _: "${service}-${name}.service") cfg.accounts;

          script = "# noop lol";

          serviceConfig = {
            Type = "oneshot";
          };

          stopIfChanged = false;
          restartIfChanged = false;
        };
      };

    systemd.timers.${service} = lib.mkIf (cfg.onCalendar != null) {
      description = "Steam Prefill timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
      };
    };
  };
}
