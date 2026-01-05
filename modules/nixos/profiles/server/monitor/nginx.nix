{
  config,
  lib,
  ...
}:
let
  cfg = config.profiles.server.monitor;
in
{
  config = lib.mkIf cfg.enable {
    age.secrets."${cfg.secretsDomain}/oidc-credentials" = {
      owner = "oauth2-proxy";
      group = "oauth2-proxy";
    };

    security.acme.simple.enable = true;

    services = {
      nginx = {
        enable = true;
        recommendedProxySettings = true;
        virtualHosts.${cfg.webDomain} = {
          enableACME = true;
          acmeRoot = null;
          forceSSL = true;
        };
      };
      oauth2-proxy = {
        enable = true;
        provider = "oidc";
        upstream = [ "static://200" ];
        email.domains = [ "*" ];
        reverseProxy = true;
        setXauthrequest = true;
        keyFile = config.age.secrets."${cfg.secretsDomain}/oidc-credentials".path;
        extraConfig."whitelist-domain" = [ cfg.webDomain ];
        nginx = {
          domain = cfg.webDomain;
          virtualHosts.${cfg.webDomain} = { };
        };
      };
    };
  };
}
