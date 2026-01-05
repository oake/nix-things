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
    tokenType = lib.mkOption {
      type = lib.types.str;
      default = "homelab";
      description = ''
        Type of token to pull from secrets.
      '';
    };
    enableForwarding = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable IP forwarding for the NetBird client.
      '';
    };
  };

  config = lib.mkIf config.profiles.server.net-router.enable {
    profiles.server.enable = lib.mkForce true;

    age.secrets."netbird-${config.profiles.server.net-router.tokenType}" = {
      owner = "netbird";
      group = "netbird";
    };

    services.netbird.simple = {
      enable = true;
      managementUrl = "https://net.oa.ke";
      setupKeyFile = config.age.secrets."netbird-${config.profiles.server.net-router.tokenType}".path;
    };

    services.netbird.clients.default.port = lib.mkForce config.profiles.server.net-router.port;

    boot.kernel.sysctl = lib.mkIf config.profiles.server.net-router.enableForwarding {
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = true;
    };

    services.iperf3.enable = true;
  };
}
