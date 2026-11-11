{
  config,
  lib,
  pkgs,
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

      credential = var: lib.toLower (lib.replaceStrings [ "_" ] [ "-" ] var);
    in
    lib.mkIf cfg.enable {
      systemd.services.${name} = {
        description = if subcommand == "serve" then "MCPProxy" else "MCPProxy peer";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];

        environment =
          lib.optionalAttrs (cfg.path != [ ]) {
            PATH = lib.mkForce (
              mcp.searchPath cfg [
                (lib.makeBinPath [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.findutils
                  pkgs.gnugrep
                  pkgs.gnused
                ])
              ]
            );
          }
          // lib.mapAttrs (_: lib.mkForce) cfg.environment
          // environment;

        script = ''
          ${lib.concatStrings (
            lib.mapAttrsToList (var: _: ''
              export ${var}="$CREDENTIALS_DIRECTORY/${credential var}"
            '') secretFiles
          )}
          exec ${lib.getExe cfg.package} ${subcommand}
        '';

        serviceConfig = {
          Restart = "on-failure";
          RestartSec = 5;
          LoadCredential = lib.mapAttrsToList (var: file: "${credential var}:${file}") secretFiles;
          WorkingDirectory = dataDir;
          NoNewPrivileges = true;
          PrivateTmp = true;
          StateDirectory = baseNameOf dataDir;
          StateDirectoryMode = "0700";
        }
        // (
          if cfg.user == null then
            { DynamicUser = true; }
          else
            {
              User = cfg.user;
            }
            // lib.optionalAttrs (cfg.group != null) { Group = cfg.group; }
        );
      };
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
