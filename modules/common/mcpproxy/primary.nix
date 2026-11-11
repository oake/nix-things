{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  mcp = import ./lib.nix { inherit lib; };
  inherit (mcp) optional optionalExample;

  cfg = config.services.mcpproxy;
  s = cfg.settings;

  dataDir = "/var/lib/mcpproxy";
in
{
  options.services.mcpproxy = {
    enable = lib.mkEnableOption "the MCPProxy primary (`mcpproxy serve`): MCP gateway and web dashboard";

    settings = mkOption {
      description = ''
        MCPProxy deployment settings. Each option maps to one `MCPPROXY_*`
        environment variable, read once at startup. Servers, profiles, clients,
        peers and secrets are managed in the dashboard, not here. Secret values
        are only accepted as files, never inline.
      '';
      default = { };
      type = types.submodule {
        options = {
          listen = mkOption {
            type = types.str;
            default = "127.0.0.1:8080";
            description = "Address of the MCP endpoint (`/mcp`), dashboard and REST API (`MCPPROXY_LISTEN`).";
          };

          encryptionKeyFile = mkOption {
            type = types.path;
            example = "/run/agenix/mcpproxy-key";
            description = ''
              File containing the base64-encoded 32-byte master key that
              encrypts the database (`MCPPROXY_ENCRYPTION_KEY_FILE`). Losing
              it loses the database.
            '';
          };

          oidc = mkOption {
            description = "OIDC provider used to sign in to the dashboard. Every admitted user is an administrator.";
            type = types.submodule {
              options = {
                issuer = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  example = "https://id.example.com";
                  description = ''
                    Issuer URL of the OIDC provider (`MCPPROXY_OIDC_ISSUER`). Set
                    exactly one of this and `issuerFile`.
                  '';
                };
                issuerFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "File containing the issuer URL (`MCPPROXY_OIDC_ISSUER_FILE`).";
                };
                clientId = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    OIDC client ID (`MCPPROXY_OIDC_CLIENT_ID`). Set exactly one of
                    this and `clientIdFile`.
                  '';
                };
                clientIdFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "File containing the client ID (`MCPPROXY_OIDC_CLIENT_ID_FILE`).";
                };
                clientSecretFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "File containing the OIDC client secret; null for a public client (`MCPPROXY_OIDC_CLIENT_SECRET_FILE`).";
                };
              };
            };
          };

          tools = mkOption {
            description = "Tool discovery and call limits.";
            default = { };
            type = types.submodule {
              options = {
                limit = optional (types.ints.between 1 1000) "Tools returned per `retrieve_tools` search (`MCPPROXY_TOOLS_LIMIT`).";
                responseLimit = optional types.ints.unsigned "Characters of a tool response returned before truncation; 0 disables (`MCPPROXY_TOOL_RESPONSE_LIMIT`).";
                callTimeout =
                  optionalExample types.str "2m"
                    "Deadline for one upstream tool call (`MCPPROXY_CALL_TOOL_TIMEOUT`).";
                maxResultSizeChars = optional types.ints.unsigned ''
                  Advertised on every tool as `_meta.anthropic/maxResultSizeChars`,
                  raising Claude Code's inline response ceiling; 0 disables the
                  annotation (`MCPPROXY_MAX_RESULT_SIZE_CHARS`).
                '';
              };
            };
          };

          upstream = mkOption {
            description = "How MCPProxy connects to and watches upstream MCP servers.";
            default = { };
            type = types.submodule {
              options = {
                healthCheckInterval =
                  optionalExample types.str "30s"
                    "Health check cadence; `0s` disables, otherwise 5s to 1h (`MCPPROXY_HEALTH_CHECK_INTERVAL`).";
                toolDiscoveryInterval =
                  optionalExample types.str "5m"
                    "Tool re-discovery cadence; `0s` disables, otherwise 30s to 24h (`MCPPROXY_TOOL_DISCOVERY_INTERVAL`).";
                initTimeout =
                  optionalExample types.str "30s"
                    "Deadline for an upstream's MCP `initialize` handshake; `0s` or 1s to 30m. Raise it for servers that warm up caches first (`MCPPROXY_INIT_TIMEOUT`).";
                allowedSystemVars =
                  optionalExample (types.listOf types.str)
                    [
                      "PATH"
                      "HOME"
                    ]
                    "System environment variables stdio MCP servers inherit (`MCPPROXY_ENVIRONMENT_ALLOWED_SYSTEM_VARS`).";
              };
            };
          };

          http = mkOption {
            description = "HTTP server behaviour.";
            default = { };
            type = types.submodule {
              options = {
                readTimeout =
                  optionalExample types.str "120s"
                    "Whole-request read timeout; `0s` disables (`MCPPROXY_HTTP_READ_TIMEOUT`).";
                writeTimeout =
                  optionalExample types.str "120s"
                    "Response write timeout on non-streaming endpoints; `0s` disables (`MCPPROXY_HTTP_WRITE_TIMEOUT`).";
                idleTimeout =
                  optionalExample types.str "180s"
                    "Idle keep-alive timeout (`MCPPROXY_HTTP_IDLE_TIMEOUT`).";
              };
            };
          };

          log = mcp.logOptions;

          codeExecution = mkOption {
            description = "Sandbox limits for clients allowed to run code.";
            default = { };
            type = types.submodule {
              options = {
                timeoutMs = optional (types.ints.between 1 600000) "Timeout of one execution in milliseconds (`MCPPROXY_CODE_EXECUTION_TIMEOUT_MS`).";
                maxToolCalls = optional types.ints.unsigned "Tool calls per execution; 0 is unlimited (`MCPPROXY_CODE_EXECUTION_MAX_TOOL_CALLS`).";
                poolSize = optional (types.ints.between 1 100) "JavaScript runtimes kept ready (`MCPPROXY_CODE_EXECUTION_POOL_SIZE`).";
                maxParallel = optional (types.ints.between 1 32) "Default concurrency of one `call_tools()` batch (`MCPPROXY_CODE_EXECUTION_MAX_PARALLEL`).";
              };
            };
          };

          oauth.expiryWarningHours = optional types.float "Hours before an upstream OAuth token expires at which its server shows as degraded (`MCPPROXY_OAUTH_EXPIRY_WARNING_HOURS`).";

          activity = mkOption {
            description = "Activity log retention.";
            default = { };
            type = types.submodule {
              options = {
                retentionDays = optional types.ints.positive "Days before records are pruned (`MCPPROXY_ACTIVITY_RETENTION_DAYS`).";
                maxRecords = optional types.ints.positive "Records kept before the oldest are pruned (`MCPPROXY_ACTIVITY_MAX_RECORDS`).";
                maxSizeMB = optional types.ints.unsigned "Total log size cap in MB; 0 disables the cap (`MCPPROXY_ACTIVITY_MAX_SIZE_MB`).";
                maxResponseSize = optional types.ints.positive "Bytes of a response stored per record (`MCPPROXY_ACTIVITY_MAX_RESPONSE_SIZE`).";
                cleanupIntervalMin = optional types.ints.positive "Minutes between background cleanups (`MCPPROXY_ACTIVITY_CLEANUP_INTERVAL_MIN`).";
              };
            };
          };

          toolCalls = mkOption {
            description = "Recent per-server tool call history, a debugging window rather than an audit log.";
            default = { };
            type = types.submodule {
              options = {
                maxResponseSize = optional types.ints.positive "Bytes of a response kept per call (`MCPPROXY_TOOL_CALL_MAX_RESPONSE_SIZE`).";
                maxRecordsPerServer = optional types.ints.positive "Calls kept per server (`MCPPROXY_TOOL_CALL_MAX_RECORDS_PER_SERVER`).";
              };
            };
          };

          outputValidation = mkOption {
            description = "Checks of a tool's structured response against its declared `outputSchema`.";
            default = { };
            type = types.submodule {
              options = {
                mode = optional (types.enum [
                  "off"
                  "warn"
                  "strict"
                ]) "What to do with a response that violates its schema (`MCPPROXY_OUTPUT_VALIDATION_MODE`).";
                maxBytes = optional types.ints.positive "Largest structured payload that is validated (`MCPPROXY_OUTPUT_VALIDATION_MAX_BYTES`).";
                maxDepth = optional types.ints.positive "Deepest nesting that is validated (`MCPPROXY_OUTPUT_VALIDATION_MAX_DEPTH`).";
                missingStructuredContent =
                  optional
                    (types.enum [
                      "allow"
                      "block"
                    ])
                    "What to do when a tool declares an `outputSchema` but returns no structured content (`MCPPROXY_OUTPUT_VALIDATION_MISSING_STRUCTURED_CONTENT`).";
              };
            };
          };

          observability = mkOption {
            description = "Usage page cache and persistence cadence.";
            default = { };
            type = types.submodule {
              options = {
                usageCacheTtl =
                  optionalExample types.str "5s"
                    "How long the usage aggregate is cached (`MCPPROXY_OBSERVABILITY_USAGE_CACHE_TTL`).";
                usagePersistInterval =
                  optionalExample types.str "30s"
                    "How often the usage aggregate is saved (`MCPPROXY_OBSERVABILITY_USAGE_PERSIST_INTERVAL`).";
              };
            };
          };

          routing = mkOption {
            description = "How tools are exposed to MCP clients.";
            default = { };
            type = types.submodule {
              options = {
                mode =
                  optional
                    (types.enum [
                      "retrieve_tools"
                      "direct"
                      "code_execution"
                    ])
                    "Tool surface: BM25 search plus `call_tool_*`, every tool directly as `server__tool`, or a JavaScript orchestration tool (`MCPPROXY_ROUTING_MODE`).";
                toolResponseMode = optional (types.enum [
                  "full"
                  "compact"
                ]) "How `retrieve_tools` serializes results (`MCPPROXY_TOOL_RESPONSE_MODE`).";
                directToolResponseMode = optional (types.enum [
                  "full"
                  "deferred"
                ]) "How direct listings serialize tool schemas (`MCPPROXY_DIRECT_TOOL_RESPONSE_MODE`).";
                instructions = optional types.str "Text returned to MCP clients on `initialize`, replacing the built-in guidance (`MCPPROXY_INSTRUCTIONS`).";
                advertiseUpstreamServers = optional types.bool "Tell clients the names of the servers they can reach (`MCPPROXY_ADVERTISE_UPSTREAM_SERVERS`).";
              };
            };
          };
        };
      };
    };
  }
  // (mcp.serviceOptions { inherit pkgs; });

  config = lib.mkIf cfg.enable {
    assertions =
      map
        (field: {
          assertion = (s.oidc.${field} == null) != (s.oidc."${field}File" == null);
          message = "services.mcpproxy.settings.oidc: set exactly one of ${field} and ${field}File.";
        })
        [
          "issuer"
          "clientId"
        ]
      ++ [
        {
          assertion = lib.all (n: !(lib.hasPrefix "MCPPROXY_" n)) (lib.attrNames cfg.environment);
          message = "services.mcpproxy.environment: MCPPROXY_* variables are configured through services.mcpproxy.settings.";
        }
      ];

    services.mcpproxy.internal = {
      subcommand = "serve";
      inherit dataDir;
      environment = mcp.toEnvironment (
        {
          MCPPROXY_LISTEN = s.listen;
          MCPPROXY_DATA_DIR = dataDir;
          MCPPROXY_OIDC_ISSUER = s.oidc.issuer;
          MCPPROXY_OIDC_CLIENT_ID = s.oidc.clientId;
          MCPPROXY_TOOLS_LIMIT = s.tools.limit;
          MCPPROXY_TOOL_RESPONSE_LIMIT = s.tools.responseLimit;
          MCPPROXY_CALL_TOOL_TIMEOUT = s.tools.callTimeout;
          MCPPROXY_MAX_RESULT_SIZE_CHARS = s.tools.maxResultSizeChars;
          MCPPROXY_HEALTH_CHECK_INTERVAL = s.upstream.healthCheckInterval;
          MCPPROXY_TOOL_DISCOVERY_INTERVAL = s.upstream.toolDiscoveryInterval;
          MCPPROXY_INIT_TIMEOUT = s.upstream.initTimeout;
          MCPPROXY_ENVIRONMENT_ALLOWED_SYSTEM_VARS = s.upstream.allowedSystemVars;
          MCPPROXY_HTTP_READ_TIMEOUT = s.http.readTimeout;
          MCPPROXY_HTTP_WRITE_TIMEOUT = s.http.writeTimeout;
          MCPPROXY_HTTP_IDLE_TIMEOUT = s.http.idleTimeout;
          MCPPROXY_CODE_EXECUTION_TIMEOUT_MS = s.codeExecution.timeoutMs;
          MCPPROXY_CODE_EXECUTION_MAX_TOOL_CALLS = s.codeExecution.maxToolCalls;
          MCPPROXY_CODE_EXECUTION_POOL_SIZE = s.codeExecution.poolSize;
          MCPPROXY_CODE_EXECUTION_MAX_PARALLEL = s.codeExecution.maxParallel;
          MCPPROXY_OAUTH_EXPIRY_WARNING_HOURS = s.oauth.expiryWarningHours;
          MCPPROXY_ACTIVITY_RETENTION_DAYS = s.activity.retentionDays;
          MCPPROXY_ACTIVITY_MAX_RECORDS = s.activity.maxRecords;
          MCPPROXY_ACTIVITY_MAX_SIZE_MB = s.activity.maxSizeMB;
          MCPPROXY_ACTIVITY_MAX_RESPONSE_SIZE = s.activity.maxResponseSize;
          MCPPROXY_ACTIVITY_CLEANUP_INTERVAL_MIN = s.activity.cleanupIntervalMin;
          MCPPROXY_TOOL_CALL_MAX_RESPONSE_SIZE = s.toolCalls.maxResponseSize;
          MCPPROXY_TOOL_CALL_MAX_RECORDS_PER_SERVER = s.toolCalls.maxRecordsPerServer;
          MCPPROXY_OUTPUT_VALIDATION_MODE = s.outputValidation.mode;
          MCPPROXY_OUTPUT_VALIDATION_MAX_BYTES = s.outputValidation.maxBytes;
          MCPPROXY_OUTPUT_VALIDATION_MAX_DEPTH = s.outputValidation.maxDepth;
          MCPPROXY_OUTPUT_VALIDATION_MISSING_STRUCTURED_CONTENT = s.outputValidation.missingStructuredContent;
          MCPPROXY_OBSERVABILITY_USAGE_CACHE_TTL = s.observability.usageCacheTtl;
          MCPPROXY_OBSERVABILITY_USAGE_PERSIST_INTERVAL = s.observability.usagePersistInterval;
          MCPPROXY_ROUTING_MODE = s.routing.mode;
          MCPPROXY_TOOL_RESPONSE_MODE = s.routing.toolResponseMode;
          MCPPROXY_DIRECT_TOOL_RESPONSE_MODE = s.routing.directToolResponseMode;
          MCPPROXY_INSTRUCTIONS = s.routing.instructions;
          MCPPROXY_ADVERTISE_UPSTREAM_SERVERS = s.routing.advertiseUpstreamServers;
        }
        // mcp.logEnvironment s.log
      );
      secretFiles = lib.filterAttrs (_: v: v != null) {
        MCPPROXY_ENCRYPTION_KEY_FILE = s.encryptionKeyFile;
        MCPPROXY_OIDC_ISSUER_FILE = s.oidc.issuerFile;
        MCPPROXY_OIDC_CLIENT_ID_FILE = s.oidc.clientIdFile;
        MCPPROXY_OIDC_CLIENT_SECRET_FILE = s.oidc.clientSecretFile;
      };
    };
  };
}
