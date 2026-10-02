{
  config,
  lib,
  ...
}:
let
  cfg = config.profiles.server.monitor;
  opensearchDir = "${cfg.storageDir}/opensearch";
in
{
  config = lib.mkIf cfg.enable {
    users.users.opensearch = {
      isSystemUser = true;
      group = "opensearch";
      description = "Opensearch server daemon user";
      createHome = true;
      home = opensearchDir;
    };
    users.groups.opensearch = { };

    services.opensearch = {
      enable = true;
      settings = {
        "cluster.name" = "monitor";
      };
      dataDir = opensearchDir;
    };
  };
}
