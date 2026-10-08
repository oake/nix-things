{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.mcpproxy;
  listen = "127.0.0.1:${toString cfg.port}";
  launcher = pkgs.writeShellScript "mcpproxy-serve" ''
    export PATH="${config.home.profileDirectory}/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
    exec ${lib.getExe cfg.package} serve --listen ${lib.escapeShellArg listen}
  '';
in
{
  options.programs.mcpproxy = {
    enable = lib.mkEnableOption "MCPProxy and its shared MCP endpoint";
    package = lib.mkPackageOption pkgs "mcpproxy" { };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Loopback port for the MCP endpoint and web management UI.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    programs.mcp = {
      enable = true;
      servers.mcpproxy.url = "http://${listen}/mcp";
    };

    launchd.agents.mcpproxy = lib.mkIf pkgs.stdenvNoCC.hostPlatform.isDarwin {
      enable = true;
      config = {
        ProgramArguments = [ "${launcher}" ];
        EnvironmentVariables.MCPPROXY_KEYRING_WRITE = "1";
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 5;
        ProcessType = "Background";
      };
    };

    systemd.user.services.mcpproxy = lib.mkIf pkgs.stdenvNoCC.hostPlatform.isLinux {
      Unit = {
        Description = "MCPProxy gateway";
        After = [ "network.target" ];
      };
      Service = {
        ExecStart = "${launcher}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
