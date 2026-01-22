{
  config,
  lib,
  ...
}:
let
  cfg = config.profiles.server.docker;
in
{
  options.profiles.server.docker.portainer = {
    enable = lib.mkEnableOption "Portainer EE container";

    exposePort = lib.mkEnableOption "exposing port 9000 for initial setup";

    traefikIntegration = {
      enable =
        lib.mkEnableOption "adding traefik labels to Portainer and adding it to the traefik network"
        // {
          default = true;
        };
      host = lib.mkOption {
        type = lib.types.str;
        default = config.deploy.fqdn;
        description = "Hostname for traefik to route to portainer from";
      };
      entrypoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "lan";
        description = "Entrypoint for traefik to route to portainer from";
      };
    };
  };

  config = lib.mkIf (cfg.enable && cfg.portainer.enable) {
    virtualisation.oci-containers.containers.portainer = {
      image = "portainer/portainer-ee";
      volumes = [
        "portainer_data:/data"
        "/var/run/docker.sock:/var/run/docker.sock"
        "/etc/localtime:/etc/localtime"
      ];
      autoStart = true;
      extraOptions = [
        "--pull=always"
        "--restart=unless-stopped"
        "--rm=false"
      ];

      ports = lib.optional cfg.portainer.exposePort "9000:9000";

      networks = lib.optional cfg.portainer.traefikIntegration.enable "web";
      labels = lib.optionalAttrs cfg.portainer.traefikIntegration.enable (
        {
          "traefik.enable" = "true";
          "traefik.http.routers.portainer.rule" = "Host(`${cfg.portainer.traefikIntegration.host}`)";
          "traefik.http.services.portainer.loadbalancer.server.port" = "9000";
        }
        // lib.optionalAttrs (cfg.portainer.traefikIntegration.entrypoint != null) {
          "traefik.http.routers.portainer.entrypoints" = cfg.portainer.traefikIntegration.entrypoint;
        }
      );

      log-driver = lib.mkIf config.monitoring.logs.docker.enable "gelf";
    };
  };
}
