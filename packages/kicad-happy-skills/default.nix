{ pkgs, pname }:
pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname;
  version = "3.0.2";

  src = pkgs.fetchFromGitHub {
    owner = "aklofas";
    repo = "kicad-happy";
    tag = "v${finalAttrs.version}";
    hash = "sha256-A+qas/v9fAoGuCEVSHO5V8hOeJKMSNHwsLBfznVfDss=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/${pname} $out/share/doc/${pname}
    cp -R skills/. $out/share/${pname}/
    cp LICENSE $out/share/doc/${pname}/
    runHook postInstall
  '';

  meta = {
    description = "KiCad design review, simulation, sourcing and manufacturing skills";
    homepage = "https://github.com/aklofas/kicad-happy";
    license = pkgs.lib.licenses.mit;
    platforms = pkgs.lib.platforms.all;
  };
})
