{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.grok-build;
  tomlFormat = pkgs.formats.toml { };
  jsonFormat = pkgs.formats.json { };
  textOrPath = lib.types.either lib.types.lines lib.types.path;
  configFile = "${cfg.configDir}/config.toml";

  sharedMcpServers = lib.optionalAttrs (cfg.enableMcpIntegration && config.programs.mcp.enable) (
    config.programs.mcp.servers
  );
  # Higher-priority definitions replace a whole server, never merge transports.
  mcpServers = lib.mapAttrs (
    name: server:
    lib.hm.mcp.transformMcpServer {
      inherit server;
      exclude = [ "type" ];
      extraTransforms = [ (lib.hm.mcp.wrapEnvFilesCommand { inherit pkgs name; }) ];
    }
  ) (sharedMcpServers // cfg.mcpServers // (cfg.settings.mcp_servers or { }));

  settings = lib.recursiveUpdate (lib.removeAttrs cfg.settings [ "mcp_servers" ]) (
    lib.optionalAttrs (mcpServers != { }) { mcp_servers = mcpServers; }
    // lib.optionalAttrs (cfg.plugins != { }) {
      plugins.enabled = lib.unique ((cfg.settings.plugins.enabled or [ ]) ++ lib.attrNames cfg.plugins);
    }
  );
  settingsSource = tomlFormat.generate "grok-build-config.toml" settings;

  mkMarkdownFiles =
    directory: entries:
    lib.mapAttrs' (
      name: value:
      lib.nameValuePair "${cfg.configDir}/${directory}/${name}.md" (
        if lib.isPath value then { source = value; } else { text = value; }
      )
    ) entries;
  mkDirectoryFiles =
    directory: entries:
    lib.mapAttrs' (
      name: source:
      lib.nameValuePair "${cfg.configDir}/${directory}/${name}" {
        inherit source;
      }
    ) entries;
  validName = name: builtins.match "[A-Za-z0-9][A-Za-z0-9._-]*" name != null;
  fileNames = lib.concatMap lib.attrNames [
    cfg.skills
    cfg.rules
    cfg.agents
    cfg.commands
    cfg.plugins
  ];
  hasContext = cfg.context != "";

  mkMarkdownOption =
    description:
    lib.mkOption {
      type = lib.types.attrsOf textOrPath;
      default = { };
      inherit description;
    };
in
{
  options.programs.grok-build = {
    enable = lib.mkEnableOption "Grok Build CLI";
    package = lib.mkPackageOption pkgs "grok-build" { nullable = true; };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.grok";
      defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/.grok"'';
      description = ''
        Absolute Grok home directory. A nondefault directory also sets GROK_HOME
        for login sessions; GUI harnesses should use the same environment variable.
        Authentication and session state are owned by Grok.
      '';
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          models.default = "grok-4.5";
          features.telemetry = false;
          compat.claude.mcps = false;
          compat.cursor.mcps = false;
        }
      '';
      description = ''
        Native configuration written to config.toml. MCP definitions in
        settings.mcp_servers take precedence over mcpServers and shared servers.
        Do not put credentials here: generated files enter the Nix store.
      '';
    };

    mutableSettings = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Merge declared settings into writable config.toml during activation.
        Declared values win; each declared MCP server replaces its existing
        definition in full. Undeclared settings and servers are preserved.
        Removing a declaration does not remove it from the writable file.
        Comments and formatting are not preserved. The default uses a store symlink.
      '';
    };

    enableMcpIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Consume programs.mcp.servers when programs.mcp.enable is also true.
        Grok uses native headers and enabled fields; type is omitted.
        File-backed env values are read at server startup through a wrapper.
        Existing Claude/Cursor compatibility discovery is not changed automatically;
        disable it explicitly in settings.compat if desired.
      '';
    };

    mcpServers = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          docs.url = "https://developers.openai.com/mcp";
          internal = {
            command = "/path/to/server";
            env.API_TOKEN.file = "/run/secrets/api-token";
          };
        }
      '';
      description = ''
        Grok-specific MCP servers, overriding shared definitions by server name.
        Supports native server fields, including enabled, headers, timeouts,
        and bearer_token_file. Environment values may use { file = "/path"; }
        to read secrets at runtime rather than placing their values in the store.
      '';
    };

    pagerSettings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      description = "Declarative TUI appearance settings written to pager.toml.";
    };

    context = lib.mkOption {
      type = textOrPath;
      default = "";
      description = ''
        Global instructions, as Markdown text or a file. Written to
        rules/home-manager.md, which Grok reads in every project.
      '';
    };

    rules = mkMarkdownOption "Named global Markdown rules, without the .md extension.";
    agents = mkMarkdownOption "Named agent definitions with YAML frontmatter, without .md.";
    commands = mkMarkdownOption "Named Markdown slash command definitions, without .md.";

    skills = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Named skill directories containing SKILL.md, linked under skills/.";
    };

    plugins = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = ''
        Local plugin directories linked under plugins/ and enabled by name.
        Attribute names must match the plugin names. Grok automatically trusts
        plugins in its user plugin directory. Plugin contents are not rewritten.
      '';
    };

    hooks = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = ''
        Hook event definitions written under the hooks key in hooks/home-manager.json.
        Use native Grok hook objects; other hook files remain untouched.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.configDir;
        message = "programs.grok-build.configDir must be an absolute path.";
      }
      {
        assertion = lib.all validName fileNames;
        message = "Grok skill, rule, agent, command, and plugin names must be simple filenames.";
      }
      {
        assertion = !hasContext || !(cfg.rules ? home-manager);
        message = "programs.grok-build.context and rules.home-manager target the same file.";
      }
      {
        assertion = lib.all lib.pathIsDirectory (lib.attrValues cfg.skills ++ lib.attrValues cfg.plugins);
        message = "programs.grok-build.skills and plugins must reference directories.";
      }
    ];

    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];
    home.sessionVariables = lib.mkIf (cfg.configDir != "${config.home.homeDirectory}/.grok") {
      GROK_HOME = cfg.configDir;
    };

    home.activation = lib.mkMerge [
      (lib.mkIf (cfg.mutableSettings && settings != { }) {
        grokBuildMutableSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] (
          lib.hm.generators.mkImpureConfigMerger {
            inherit pkgs;
            format = "toml";
            empty = "";
            path = configFile;
            staticSettings = settingsSource;
            mode = "600";
            jqOperation = ''
              ($dynamic * $static)
              | if $static | has("mcp_servers") then
                  .mcp_servers = (($dynamic.mcp_servers // {}) + $static.mcp_servers)
                else . end
            '';
          }
        );
      })
      (lib.mkIf (!cfg.mutableSettings && settings != { }) {
        grokBuildImmutableSettings = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] (
          lib.hm.generators.mkImpureConfigCleanup { file = config.home.file.${configFile}; }
        );
      })
    ];

    home.file = lib.mkMerge [
      (lib.mkIf (!cfg.mutableSettings && settings != { }) {
        ${configFile}.source = settingsSource;
      })
      (lib.mkIf (cfg.pagerSettings != { }) {
        "${cfg.configDir}/pager.toml".source =
          tomlFormat.generate "grok-build-pager.toml" cfg.pagerSettings;
      })
      (mkMarkdownFiles "rules" (
        cfg.rules // lib.optionalAttrs hasContext { home-manager = cfg.context; }
      ))
      (mkMarkdownFiles "agents" cfg.agents)
      (mkMarkdownFiles "commands" cfg.commands)
      (mkDirectoryFiles "skills" cfg.skills)
      (mkDirectoryFiles "plugins" cfg.plugins)
      (lib.mkIf (cfg.hooks != { }) {
        "${cfg.configDir}/hooks/home-manager.json".source = jsonFormat.generate "grok-build-hooks.json" {
          hooks = cfg.hooks;
        };
      })
    ];
  };
}
