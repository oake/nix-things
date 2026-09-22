{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    lib
    writeShellApplication
    ;
in
writeShellApplication {
  name = pname;
  text = builtins.readFile ./mrrp.sh;

  meta = {
    description = "Open a sish HTTP tunnel on mrrp.win";
    mainProgram = pname;
    platforms = lib.platforms.unix;
  };
}
