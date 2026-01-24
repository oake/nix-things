{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lxc.nvidia;
  nvidia-userspace = pkgs.callPackage ./nvidia-userspace.nix {
    nvidia-libs = cfg.package.override {
      libsOnly = true;
      kernel = null;
    };
  };
in
{
  config = lib.mkIf (config.lxc.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "For Nvidia passthrough to work, lxc.nvidia.package must be set to an Nvidia driver package matching the host driver version.";
      }
    ];

    environment.systemPackages = [ nvidia-userspace ];

    hardware.graphics.enable = true;
    hardware.graphics.package = nvidia-userspace;
    hardware.nvidia.package = nvidia-userspace;
    hardware.nvidia-container-toolkit = {
      suppressNvidiaDriverAssertion = true;

      mount-nvidia-executables = false;
      mounts = lib.mkAfter (
        map
          (tool: {
            hostPath = "${nvidia-userspace}/origBin/${tool}";
            containerPath = "/usr/bin/${tool}";
          })
          [
            "nvidia-smi"
            "nvidia-debugdump"
            "nvidia-powerd"
            "nvidia-cuda-mps-control"
            "nvidia-cuda-mps-server"
          ]
      );
    };

    lxc = {
      devices = [
        "/dev/nvidia0"
        "/dev/nvidiactl"
        "/dev/nvidia-uvm"
        "/dev/nvidia-uvm-tools"
        "/dev/nvidia-caps/nvidia-cap1"
        "/dev/nvidia-caps/nvidia-cap2"
      ];
      extraConfig = ''
        lxc.apparmor.profile: unconfined
        lxc.cgroup2.devices.allow: a
        lxc.cap.drop:
      '';
      tags = [ "nvidia" ];
      features = lib.mkForce [ ];
    };
  };
}
