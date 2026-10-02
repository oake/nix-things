{ config, lib, ... }:
let
  cfg = config.monitoring.logs;

  parsed =
    let
      m = builtins.match "(https?)://([^/:]+)(:([0-9]+))?(/.*)?" cfg.targetUrl;
    in
    if m == null then
      throw "monitoring.logs.targetUrl must look like https://host[:port][/path], got: ${cfg.targetUrl}"
    else
      {
        tls = builtins.elemAt m 0 == "https";
        host = builtins.elemAt m 1;
        port =
          if builtins.elemAt m 3 != null then
            lib.toInt (builtins.elemAt m 3)
          else if builtins.elemAt m 0 == "https" then
            443
          else
            80;
        prefix = lib.removeSuffix "/" (if builtins.elemAt m 4 == null then "" else builtins.elemAt m 4);
      };
in
{
  imports = [
    (lib.mkRenamedOptionModule
      [ "monitoring" "logs" "systemd" "enable" ]
      [ "monitoring" "logs" "system" "enable" ]
    )
  ];
  options.monitoring.logs = {
    targetUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://logs.oa.ke";
      example = "https://logs.example.com";
      description = "Base URL of the VictoriaLogs instance to push messages to.";
    };
    tokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = lib.literalExpression "config.age.secrets.logs-token.path";
      description = ''
        Absolute runtime path to an environment file containing
        LOGS_TOKEN=<token>, the bearer token for the log server, sent as an
        Authorization header. The file is read at runtime and may be owned by
        root; never put its contents in Nix. Null sends no Authorization header.
      '';
    };

    accountId = lib.mkOption {
      type = lib.types.ints.u32;
      default = 0;
      example = 1;
      description = "VictoriaLogs tenant AccountID to push messages to.";
    };
    projectId = lib.mkOption {
      type = lib.types.ints.u32;
      default = 0;
      example = 1;
      description = "VictoriaLogs tenant ProjectID to push messages to.";
    };

    system = {
      enable = lib.mkEnableOption "pushing operating system logs to SIEM";
    };

    docker = {
      enable = lib.mkEnableOption "pushing Docker logs to SIEM";
    };

    mkOutput = lib.mkOption {
      type = lib.types.raw;
      internal = true;
      readOnly = true;
      description = "Builds the fluent-bit HTTP output for targetUrl from a list of stream fields.";
      default =
        streamFields:
        {
          name = "http";
          match = "*";
          inherit (parsed) host port;
          uri = "${parsed.prefix}/insert/jsonline?_stream_fields=${lib.concatStringsSep "," streamFields}&_msg_field=message&_time_field=date";
          format = "json_lines";
          json_date_key = "date";
          json_date_format = "iso8601";
          retry_limit = "no_limits";
          header = [
            "AccountID ${toString cfg.accountId}"
            "ProjectID ${toString cfg.projectId}"
          ]
          ++ lib.optional (cfg.tokenFile != null) "Authorization Bearer \${LOGS_TOKEN}";
        }
        // lib.optionalAttrs parsed.tls {
          tls = "on";
          "tls.verify" = "on";
        };
    };
  };
}
