{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    stdenv
    fetchzip
    lib
    ;
in
stdenv.mkDerivation rec {
  inherit pname;
  version = "1.1.1";

  src = fetchzip {
    name = "${pname}-${version}-source.zip";
    url = "https://github.com/Hammerspoon/hammerspoon/releases/download/${version}/Hammerspoon-${version}.zip";
    sha256 = "sha256-PUv1LL2fSLHvOTb9flw+scrDFYyJ81mrFGjSk73k1S8=";
    stripRoot = false;
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -r $src/Hammerspoon.app $out/Applications/

    runHook postInstall
  '';

  passthru.updateScript = [
    ../../lib/update-source.sh
    ./default.nix
    "--use-github-releases"
  ];

  meta = {
    homepage = "https://www.hammerspoon.org";
    description = "Staggeringly powerful macOS desktop automation with Lua";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.mit;
    platforms = [
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
