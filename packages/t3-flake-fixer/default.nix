{ pkgs, pname }:
pkgs.stdenvNoCC.mkDerivation {
  inherit pname;
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  installPhase = ''
    mkdir -p $out/libexec $out/bin
    cp receiver.py $out/libexec/t3-flake-fixer.py
    makeWrapper ${pkgs.python3}/bin/python $out/bin/t3-flake-fixer \
      --add-flags $out/libexec/t3-flake-fixer.py
  '';
  meta = {
    description = "Buildbot log collector and T3 repair launcher";
    mainProgram = "t3-flake-fixer";
    platforms = pkgs.lib.platforms.linux;
    license = pkgs.lib.licenses.mit;
  };
}
