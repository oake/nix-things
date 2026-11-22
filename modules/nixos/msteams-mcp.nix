{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.programs.msteams-mcp;
  package =
    if cfg.browserExecutable == null then
      cfg.package
    else
      pkgs.symlinkJoin {
        name = "msteams-mcp-configured";
        paths = [ cfg.package ];
        nativeBuildInputs = [ pkgs.makeWrapper ];

        postBuild = ''
          for program in msteams msteams-mcp; do
            wrapProgram "$out/bin/$program" \
              --set TEAMS_BROWSER_EXECUTABLE ${lib.escapeShellArg cfg.browserExecutable}
          done
        '';
      };
in
{
  options.programs.msteams-mcp = {
    enable = lib.mkEnableOption "the Microsoft Teams MCP server and command-line client";
    package = lib.mkPackageOption pkgs "msteams-mcp" { };

    browserExecutable = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = lib.literalExpression "lib.getExe pkgs.chromium";
      description = ''
        Chromium-based browser executable for Teams sign-in and session refresh.
        Null uses upstream browser discovery.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    {
      environment.systemPackages = [ package ];
    }
    // lib.optionalAttrs (options.services ? mcpproxy-peer) {
      services.mcpproxy-peer.path = [ package ];
    }
  );
}
