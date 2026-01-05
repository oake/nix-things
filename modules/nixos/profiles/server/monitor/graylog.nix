{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.profiles.server.monitor;
  graylogDir = "${cfg.storageDir}/graylog";
  mongodbDir = "${cfg.storageDir}/mongodb";
  opensearchDir = "${cfg.storageDir}/opensearch";
in
{
  config = lib.mkIf cfg.enable {
    age.secrets."${cfg.secretsDomain}/graylog-password-secret" = {
      owner = "graylog";
      group = "graylog";
    };
    age.secrets."${cfg.secretsDomain}/graylog-root-password-sha2" = {
      owner = "graylog";
      group = "graylog";
    };

    users.users.opensearch = {
      isSystemUser = true;
      group = "opensearch";
      description = "Opensearch server daemon user";
      createHome = true;
      home = opensearchDir;
    };
    users.groups.opensearch = { };

    services = {
      graylog = {
        enable = true;
        package = pkgs.graylog-6_1;
        extraConfig = ''
          http_external_uri = https://${cfg.webDomain}/logs/
          trusted_proxies = 127.0.0.1/32
        '';
        passwordSecretFile = config.age.secrets."${cfg.secretsDomain}/graylog-password-secret".path;
        rootPasswordSha2File = config.age.secrets."${cfg.secretsDomain}/graylog-root-password-sha2".path;
        nodeIdFile = "${graylogDir}/server/node-id";
        dataDir = "${graylogDir}/data";
        messageJournalDir = "${graylogDir}/data/journal";
      };
      mongodb = {
        enable = true;
        dbpath = mongodbDir;
      };
      opensearch = {
        enable = true;
        settings = {
          "cluster.name" = "monitor";
        };
        dataDir = opensearchDir;
      };
      nginx.virtualHosts.${cfg.webDomain}.locations = {
        "/logs" = {
          return = "301 /logs/";
        };
        "/logs/" = {
          proxyPass = "http://127.0.0.1:9000/";
          proxyWebsockets = true;
          extraConfig = ''
            auth_request_set $preferred_username $upstream_http_x_auth_request_preferred_username;
            proxy_set_header Remote-User $preferred_username;
          '';
        };
      };
    };
  };
}
