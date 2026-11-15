{ pkgs, pname }:
pkgs.stdenvNoCC.mkDerivation {
  inherit pname;
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  installPhase = ''
    mkdir -p $out/libexec $out/bin
    cp cli.py receiver.py notify.py $out/libexec/
    makeWrapper ${pkgs.python3}/bin/python $out/bin/t3-flake-fixer \
      --add-flags $out/libexec/cli.py
  '';
  passthru.updateScript = null;

  meta = {
    description = "Nixbot log collector and T3 repair launcher";
    mainProgram = "t3-flake-fixer";
    platforms = pkgs.lib.platforms.unix;
    license = pkgs.lib.licenses.mit;
  };
}
