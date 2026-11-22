{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.programs.ai;
  skills = lib.listToAttrs (
    map (
      path: lib.nameValuePair (baseNameOf (builtins.unsafeDiscardStringContext (toString path))) path
    ) cfg.skills
  );

  agent =
    enabled: settings:
    lib.mkIf enabled (
      {
        enable = true;
        enableMcpIntegration = true;
        inherit skills;
      }
      // settings
    );

  mutable = {
    mutableSettings = true;
  };
in
{
  imports = [ ./grok-build ];

  options.programs.ai = {
    enable = lib.mkEnableOption "shared AI harness configuration";

    agents = lib.genAttrs [
      "codex"
      "claude-code"
      "grok-build"
      "opencode"
      "antigravity"
    ] lib.mkEnableOption;

    skills = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Skill directories shared by the enabled harnesses. Each directory basename is used as the skill name.";
    };

    enableMcpProxyIntegration = lib.mkEnableOption "the local MCPProxy server in programs.mcp";
  };

  config = lib.mkIf cfg.enable (
    {
      home.packages = [ pkgs.python3 ];

      programs = {
        mcp = lib.mkIf cfg.enableMcpProxyIntegration {
          enable = true;
          servers.mcpproxy.url = lib.mkDefault "http://127.0.0.1:3333/mcp";
        };

        codex = agent cfg.agents.codex mutable;
        claude-code = agent cfg.agents.claude-code mutable;
        grok-build = agent cfg.agents.grok-build (
          mutable
          // {
            settings.compat = {
              claude.mcps = false;
              cursor.mcps = false;
            };
          }
        );
        opencode = agent cfg.agents.opencode { };
        antigravity-cli = agent cfg.agents.antigravity mutable;
      };
    }
    // lib.optionalAttrs (options ? stylix.targets.opencode.enable) {
      stylix.targets.opencode.enable = lib.mkIf cfg.agents.opencode false;
    }
  );
}
