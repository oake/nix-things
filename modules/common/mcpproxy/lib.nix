{ lib }:
let
  inherit (lib) mkOption types;
in
rec {
  # An optional setting. null leaves the variable unset, so MCPProxy keeps its
  # built-in default (the defaults live in one place: the MCPProxy binary).
  optional =
    type: description:
    mkOption {
      type = types.nullOr type;
      default = null;
      description = "${description}\n\nUnset keeps MCPProxy's built-in default.";
    };

  optionalExample =
    type: example: description:
    mkOption {
      type = types.nullOr type;
      default = null;
      inherit example;
      description = "${description}\n\nUnset keeps MCPProxy's built-in default.";
    };

  # Variable value as MCPProxy parses it: booleans are true/false, lists are
  # comma-separated.
  toValue =
    v:
    if builtins.isBool v then
      lib.boolToString v
    else if builtins.isList v then
      lib.concatStringsSep "," v
    else
      toString v;

  # Drop unset settings (null, or an empty list) and render the rest.
  toEnvironment =
    attrs: lib.mapAttrs (_: toValue) (lib.filterAttrs (_: v: v != null && v != [ ]) attrs);

  # Options shared by both modes (MCPPROXY_LOG_*).
  logOptions = mkOption {
    description = "Logging. Defaults to console output only, which lands in the service log.";
    default = { };
    type = types.submodule {
      options = {
        level = optional (types.enum [
          "trace"
          "debug"
          "info"
          "warn"
          "error"
        ]) "Minimum log level (`MCPPROXY_LOG_LEVEL`).";
        toFile = optional types.bool "Also write logs to a file (`MCPPROXY_LOG_TO_FILE`).";
        toConsole = optional types.bool "Write logs to the console (`MCPPROXY_LOG_TO_CONSOLE`).";
        filename = optional types.str "Log file name inside the log directory (`MCPPROXY_LOG_FILENAME`).";
        dir = optional types.path "Log directory; defaults to `logs` inside the data directory (`MCPPROXY_LOG_DIR`).";
        maxSizeMB = optional types.ints.positive "Rotate a log file at this size in MB (`MCPPROXY_LOG_MAX_SIZE`).";
        maxBackups = optional types.ints.unsigned "Rotated log files to keep (`MCPPROXY_LOG_MAX_BACKUPS`).";
        maxAgeDays = optional types.ints.unsigned "Days to keep rotated log files (`MCPPROXY_LOG_MAX_AGE`).";
        compress = optional types.bool "Compress rotated log files (`MCPPROXY_LOG_COMPRESS`).";
      };
    };
  };

  logEnvironment = log: {
    MCPPROXY_LOG_LEVEL = log.level;
    MCPPROXY_LOG_TO_FILE = log.toFile;
    MCPPROXY_LOG_TO_CONSOLE = log.toConsole;
    MCPPROXY_LOG_FILENAME = log.filename;
    MCPPROXY_LOG_DIR = log.dir;
    MCPPROXY_LOG_MAX_SIZE = log.maxSizeMB;
    MCPPROXY_LOG_MAX_BACKUPS = log.maxBackups;
    MCPPROXY_LOG_MAX_AGE = log.maxAgeDays;
    MCPPROXY_LOG_COMPRESS = log.compress;
  };

  # PATH of the service: every `path` entry (a package's bin directory, or a
  # directory), then `tail` (the platform's base directories).
  searchPath =
    cfg: tail:
    lib.concatStringsSep ":" (
      map (p: if lib.isDerivation p then "${lib.getBin p}/bin" else p) cfg.path ++ tail
    );

  # Options of the service itself, independent of MCPProxy's own settings.
  serviceOptions =
    { pkgs }:
    {
      package = lib.mkPackageOption pkgs "mcpproxy" { };

      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          User the service runs as. On NixOS, null runs it under a dynamic
          user; on macOS the user is required. Credential files are read by the service user, so they must
          be readable by it (NixOS passes them through systemd credentials and
          also works with root-owned files).
        '';
      };

      group = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Group the service runs as. Null uses the user's primary group.";
      };

      path = mkOption {
        type = types.listOf (types.either types.package types.str);
        default = [ ];
        example = lib.literalExpression ''[ pkgs.nodejs pkgs.uv "/etc/profiles/per-user/anna/bin" ]'';
        description = ''
          Added to the service's PATH, in order: a package contributes its
          `bin` directory, a string is used as a directory. The stdio MCP
          servers MCPProxy launches inherit that PATH.
        '';
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = {
          TZ = "Europe/Amsterdam";
        };
        description = ''
          Extra environment variables for the service and the MCP servers it
          launches (subject to `MCPPROXY_ENVIRONMENT_ALLOWED_SYSTEM_VARS`).
          Setting `PATH` here replaces the one built from `path`.
          MCPPROXY_* names are rejected: use `settings` for those.
        '';
      };

      internal = {
        environment = mkOption {
          type = types.attrsOf types.str;
          internal = true;
          readOnly = true;
          description = "MCPPROXY_* variables derived from `settings`.";
        };
        secretFiles = mkOption {
          type = types.attrsOf types.path;
          internal = true;
          readOnly = true;
          description = "MCPPROXY_*_FILE variables mapped to the credential file they point at.";
        };
        dataDir = mkOption {
          type = types.str;
          internal = true;
          readOnly = true;
          description = "Fixed data directory of this mode.";
        };
        subcommand = mkOption {
          type = types.str;
          internal = true;
          readOnly = true;
          description = "mcpproxy subcommand that starts this mode.";
        };
      };
    };
}
