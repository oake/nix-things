{
  config,
  lib,
  ...
}:
let
  mcp = import ../common/mcpproxy/lib.nix { inherit lib; };

  mkService =
    name:
    let
      cfg = config.services.${name};
      inherit (cfg.internal)
        environment
        secretFiles
        subcommand
        dataDir
        ;
      owner =
        lib.optionalString (cfg.user != null)
          "${cfg.user}:${lib.optionalString (cfg.group != null) cfg.group}";
      log = "/var/log/${name}.log";
    in
    lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.user != null;
          message = "services.${name}.user must be set on macOS: the daemon must not run as root.";
        }
      ];

      launchd.daemons.${name} = {
        command = "${lib.getExe cfg.package} ${subcommand}";

        environment =
          lib.optionalAttrs (cfg.path != [ ]) {
            PATH = mcp.searchPath cfg [
              "/usr/bin"
              "/bin"
              "/usr/sbin"
              "/sbin"
            ];
          }
          // cfg.environment
          // environment
          // secretFiles;

        serviceConfig = {
          UserName = cfg.user;
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 5;
          ProcessType = "Background";
          WorkingDirectory = dataDir;
          StandardOutPath = log;
          StandardErrorPath = log;
        }
        // lib.optionalAttrs (cfg.group != null) { GroupName = cfg.group; };
      };

      system.activationScripts.postActivation.text = lib.mkAfter ''
        mkdir -p ${lib.escapeShellArg dataDir}
        chmod 0700 ${lib.escapeShellArg dataDir}
        chown ${lib.escapeShellArg owner} ${lib.escapeShellArg dataDir}

        # launchd opens StandardOutPath as UserName, which cannot create files in /var/log
        touch ${lib.escapeShellArg log}
        chmod 0600 ${lib.escapeShellArg log}
        chown ${lib.escapeShellArg owner} ${lib.escapeShellArg log}
      '';
    };
in
{
  config = lib.mkMerge (
    map mkService [
      "mcpproxy"
      "mcpproxy-peer"
    ]
  );
}
