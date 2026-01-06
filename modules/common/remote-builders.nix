{
  config,
  lib,
  ...
}:
let
  availableMachines = {
    gratis = {
      hostName = "gratis.oa.ke";
      system = "aarch64-linux";
      maxJobs = 4;
      supportedFeatures = [
        "benchmark"
        "big-parallel"
        "gccarch-armv8-a"
        "kvm"
        "nixos-test"
      ];
      publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUVqNkVSbk5ldUxuL0ZsTXFxN3pTVFhYbFBDLzFiVTlxT1lsYTNGTUJvbFMgZ3JhdGlzCg==";
    };
    "lxc-builder" = {
      hostName = "builder.lan.ci";
      system = "x86_64-linux";
      maxJobs = 10;
      supportedFeatures = [
        "benchmark"
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
      publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUU5aitSdGpaMDdWeXhDVDduSmk2Y3RUeUFWOGFsdUxaU3dncHptWmdGTkogbHhjLWJ1aWxkZXIK";
    };
  };
in
{
  options.remoteBuilders = {
    auto = lib.mkEnableOption "required remote builders automatically";
    protocol = lib.mkOption {
      type = lib.types.enum [
        "ssh-ng"
        "ssh"
      ];
      default = "ssh-ng";
      description = "The protocol to use for remote builders.";
    };
    machines = lib.mapAttrs (name: machine: {
      enable = lib.mkEnableOption "${machine.system} remote builder (${machine.hostName})" // {
        default = config.remoteBuilders.auto && config.nixpkgs.hostPlatform.system != machine.system;
      };
      sshUser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = config.me.username;
        description = "The username to log in as on ${machine.hostName}.";
      };
      sshKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The path to the SSH private key with which to authenticate on ${machine.hostName}.";
      };
    }) availableMachines;
  };

  config = {
    nix.extraOptions = lib.optionalString config.nix.distributedBuilds ''
      builders-use-substitutes = true
    '';

    nix.distributedBuilds = config.nix.buildMachines != [ ];

    nix.buildMachines = lib.mapAttrsToList (
      name: cfg:
      availableMachines.${name}
      // {
        sshUser = cfg.sshUser;
        sshKey = cfg.sshKey;
        protocol = config.remoteBuilders.protocol;
      }
    ) (lib.attrsets.filterAttrs (name: machine: machine.enable) config.remoteBuilders.machines);
  };
}
