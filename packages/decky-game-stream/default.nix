{
  pkgs,
  pname,
}:
let
  inherit (pkgs) lib buildNpmPackage systemd;
in
buildNpmPackage {
  inherit pname;
  version = (lib.importJSON ./package.json).version;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./src
      ./main.py
      ./package.json
      ./package-lock.json
      ./plugin.json
      ./rollup.config.js
      ./tsconfig.json
    ];
  };

  npmDepsHash = "sha256-bwoChkmxmCVJHdEe4PmgsFDJ+wZQCLLuvzfZHLPN+o4=";

  # npm run build: rollup via @decky/rollup, into dist/
  installPhase = ''
    runHook preInstall

    dir=$out/plugins/game-stream
    mkdir -p $dir
    cp -r dist main.py plugin.json package.json $dir/
    substituteInPlace $dir/main.py --replace-fail "@systemctl@" "${lib.getExe' systemd "systemctl"}"

    runHook postInstall
  '';

  meta = {
    description = "Decky plugin to toggle game stream";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
