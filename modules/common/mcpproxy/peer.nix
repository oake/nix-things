{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  mcp = import ./lib.nix { inherit lib; };

  cfg = config.services.mcpproxy-peer;
  s = cfg.settings;

  dataDir = "/var/lib/mcpproxy-peer";
in
{
  options.services.mcpproxy-peer = {
    enable = lib.mkEnableOption ''
      an MCPProxy peer (`mcpproxy peer`). It connects outward to a primary and
      runs the primary's servers assigned to this machine; it has no dashboard,
      admin API or database
    '';

    settings = mkOption {
      description = ''
        MCPProxy peer settings. Each option maps to one `MCPPROXY_*`
        environment variable, read once at startup. Everything else is
        configured centrally on the primary. The token is optional and only
        accepted as a file, never inline.
      '';
      default = { };
      type = types.submodule {
        options = {
          primaryUrl = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "https://mcp.example.com";
            description = ''
              Origin (scheme, host and port, no path) of the primary
              (`MCPPROXY_PEER_PRIMARY_URL`). Set exactly one of this and
              `primaryUrlFile`.
            '';
          };

          primaryUrlFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            example = "/run/agenix/mcpproxy-primary-url";
            description = ''
              File containing the origin of the primary
              (`MCPPROXY_PEER_PRIMARY_URL_FILE`), which keeps the address out of
              public configuration. Set exactly one of this and `primaryUrl`.
            '';
          };

          tokenFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            example = "/run/agenix/mcpproxy-peer-token";
            description = ''
              File containing the peer token created on the primary under
              Clients, Add peer (`MCPPROXY_PEER_TOKEN_FILE`).

              Null signs the peer in through the browser instead: open the
              `listen` address on this machine, sign in to the primary and
              choose the peer. The sign-in is kept in the data directory and
              survives restarts; rotating or deleting the peer on the primary
              signs it out.
            '';
          };

          listen = mkOption {
            type = types.str;
            default = "127.0.0.1:8080";
            description = ''
              Address of this machine's local MCP endpoint (`/mcp`), which MCP
              clients connect to with a client token or by signing in, and of
              the peer's own sign-in page (`MCPPROXY_LISTEN`). Browser sign-in
              must be opened on a loopback address such as `127.0.0.1`.
            '';
          };

          log = mcp.logOptions;
        };
      };
    };
  }
  // (mcp.serviceOptions { inherit pkgs; });

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (s.primaryUrl == null) != (s.primaryUrlFile == null);
        message = "services.mcpproxy-peer.settings: set exactly one of primaryUrl and primaryUrlFile.";
      }
      {
        assertion = lib.all (n: !(lib.hasPrefix "MCPPROXY_" n)) (lib.attrNames cfg.environment);
        message = "services.mcpproxy-peer.environment: MCPPROXY_* variables are configured through services.mcpproxy-peer.settings.";
      }
      {
        assertion =
          !(config.services.mcpproxy.enable && s.listen == config.services.mcpproxy.settings.listen);
        message = "services.mcpproxy and services.mcpproxy-peer both listen on ${s.listen}; set one of the two `settings.listen`.";
      }
    ];

    services.mcpproxy-peer.internal = {
      subcommand = "peer";
      inherit dataDir;
      environment = mcp.toEnvironment (
        {
          MCPPROXY_LISTEN = s.listen;
          MCPPROXY_DATA_DIR = dataDir;
          MCPPROXY_PEER_PRIMARY_URL = s.primaryUrl;
        }
        // mcp.logEnvironment s.log
      );
      secretFiles = lib.filterAttrs (_: v: v != null) {
        MCPPROXY_PEER_PRIMARY_URL_FILE = s.primaryUrlFile;
        MCPPROXY_PEER_TOKEN_FILE = s.tokenFile;
      };
    };
  };
}
