{ pkgs, pname }:
pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname;
  version = "3.0.1";

  src = pkgs.fetchFromGitHub {
    owner = "aklofas";
    repo = "kicad-happy";
    tag = "v${finalAttrs.version}";
    hash = "sha256-mV0ehcqPC6Z5fN8VLsTOJ3z5tAdABt5HlM5z/f9wVcA=";
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
