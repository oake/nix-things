{
  lib,
  ...
}:
{
  imports = [
    ./logs.nix
    ./metrics.nix
  ];

  options.monitoring = {
    machineType = lib.mkOption {
      type = lib.types.enum [
        "local"
        "remote"
        "mobile"
      ];
      default = "local";
    };
  };
}
