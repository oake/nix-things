{
  lib,
  config,
  ...
}:
{
  options.profiles.server.net-router = {
    enable = lib.mkEnableOption "net-router server profile";
    port = lib.mkOption {
      type = lib.types.port;
      example = lib.literalExpression "51820";
      description = ''
        Port the NetBird client listens on.
      '';
    };
  };

  config = lib.mkIf config.profiles.server.net-router.enable {
    profiles.server.enable = lib.mkForce true;

    age.secrets.netbird-homelab = {
      owner = "netbird";
      group = "netbird";
    };

    services.netbird.simple = {
      enable = true;
      managementUrl = "https://net.oa.ke";
      setupKeyFile = config.age.secrets.netbird-homelab.path;
    };

    services.netbird.clients.default.port = lib.mkForce config.profiles.server.net-router.port;

    boot.kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = true;
    };

    services.iperf3.enable = true;
  };
}
