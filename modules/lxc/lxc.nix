{
  inputs,
  ...
}:
{
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    inputs.self.nixosModules.default
    ./profiles
  ];

  systemd.suppressedSystemUnits = [
    "sys-kernel-debug.mount"
  ];

  proxmoxLXC.manageNetwork = true;
  networking.firewall.enable = false;

  age.identityPaths = [ "/nix-lxc/agenix_key" ];

  # cut 300 MiB off the final closure lol
  nixpkgs.flake = {
    setNixPath = false;
    setFlakeRegistry = false;
  };

  nixpkgs.hostPlatform = "x86_64-linux";
}
