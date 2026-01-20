{
  config,
  lib,
  ...
}:
let
  cfg = config.profiles.server.docker;
in
{
  imports = [
    ./networks.nix
  ];

  options.profiles.server.docker = {
    enable = lib.mkEnableOption "Docker server profile";

    enableNvidiaSupport = lib.mkEnableOption "nvidia-container-toolkit";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        profiles.server.enable = lib.mkForce true;

        virtualisation.docker = {
          enable = true;

          daemon.settings = {
            live-restore = true; # keep containers running when dockerd is restarted
            default-address-pools = [
              {
                base = "172.24.0.0/13";
                size = 22;
              }
            ];
            bip = "172.23.0.1/22";
          };

          # weekly prune all stopped containers, build cache, unused networks and images
          autoPrune = {
            enable = true;
            persistent = true;
            flags = [ "--all" ]; # all unused images, not just dangling ones
          };
        };

        profiles.server.docker.networks = {
          web = "172.16.0.0/22";
        };
      }
      (lib.mkIf cfg.enableNvidiaSupport {
        hardware.nvidia-container-toolkit = {
          enable = true;
        };
      })
      (lib.mkIf config.lxc.enable {
        lxc.unprivileged = false;
      })
    ]
  );
}
