{
  pkgs,
  config,
  lib,
  ...
}:
let
  sftpShell = pkgs.writeShellScriptBin "sftpgo-subsys" ''
    exec ${pkgs.sftpgo}/bin/sftpgo startsubsys -j
  '';
in
{
  config = lib.mkIf config.profiles.server.share.enable {
    users.users = lib.genAttrs (builtins.attrNames config.profiles.server.share.users) (name: {
      shell = "${sftpShell}/bin/sftpgo-subsys";
    });
    services.openssh.sftpServerExecutable = "${sftpShell}/bin/sftpgo-subsys";
  };
}
