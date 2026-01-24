{
  config,
  lib,
  ...
}:
let
  cfg = config.lxc.nvidia;
in
{
  config = lib.mkIf (config.lxc.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "For Nvidia passthrough to work, lxc.nvidia.package must be set to an Nvidia driver package matching the host driver version.";
      }
    ];

    hardware.graphics.enable = true;
    hardware.graphics.package = cfg.package;
    hardware.nvidia.package = cfg.package;
    hardware.nvidia-container-toolkit.suppressNvidiaDriverAssertion = true;

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
