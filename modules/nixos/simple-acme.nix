{
  lib,
  config,
  ...
}:
let
  cfg = config.security.acme.simple;
in
{
  options.security.acme.simple = {
    enable = lib.mkEnableOption "Simple ACME configuration";
    email = lib.mkOption {
      type = lib.types.str;
      default = config.me.email;
      description = "Email address to use for ACME registration";
    };
  };

  config = lib.mkIf cfg.enable {
    profiles.server.enable = lib.mkForce true;

    age.secrets."acme-cf-credentials" = {
      owner = "acme";
      group = "acme";
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        email = cfg.email;
        dnsProvider = "cloudflare";
        extraLegoFlags = [
          "--dns.propagation-wait"
          "60s"
        ];
        credentialsFile = config.age.secrets."acme-cf-credentials".path;
      };
    };
  };
}
