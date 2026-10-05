{
  lib,
  modulesPath,
  config,
  ...
}:
{
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    ./options.nix
    ./tarball.nix
    ./nvidia.nix
  ];

  config = lib.mkMerge [
    (lib.mkIf config.lxc.enable {
      systemd.suppressedSystemUnits = [
        "sys-kernel-debug.mount"
      ];

      system.nixos.tags = lib.mkForce [ ];

      proxmoxLXC.enable = lib.mkForce true;
      proxmoxLXC.manageNetwork = true;

      networking.enableIPv6 = false;

      age.identityPaths = [ "/nix-lxc/agenix_pq_key" ];

      nixpkgs.hostPlatform = "x86_64-linux";
    })
    {
      proxmoxLXC.enable = false;
    }
  ];
}
