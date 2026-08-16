{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.services.fprintd.cs9711 = lib.mkEnableOption "Chipsailing CS9711 libfprint driver";

  config = lib.mkIf (config.services.fprintd.enable && config.services.fprintd.cs9711) {
    services.fprintd.package = pkgs.fprintd.override { libfprint = pkgs.libfprint-cs9711; };
    services.udev.packages = [ pkgs.libfprint-cs9711 ];
  };
}
