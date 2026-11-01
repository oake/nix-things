{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    lib
    stdenvNoCC
    fetchurl
    unzip
    makeWrapper
    ;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname;
  version = "3.1.1";

  src = fetchurl {
    url = "https://anoma.ly/release/hex/files/f07aeaa418521ef0253641dee24b95c884180bf41899bc1c5686f530f3668496/Hex.zip";
    hash = "sha256-8HrqpBhSHvAlNkHe4kuVyIQYC/QYmbwcVob1MPNmhJY=";
  };

  nativeBuildInputs = [
    unzip
    makeWrapper
  ];
  sourceRoot = "Hex.app";
  dontConfigure = true;
  dontBuild = true;
  # Preserve the upstream signature on the app bundle and its native libraries.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications/Hex.app" "$out/bin"
    cp -R . "$out/Applications/Hex.app"
    makeWrapper "$out/Applications/Hex.app/Contents/MacOS/hex" "$out/bin/${pname}"

    runHook postInstall
  '';

  meta = {
    description = "Local-first voice dictation for macOS";
    homepage = "https://anoma.ly/hex/";
    changelog = "https://github.com/anomalyco/hex/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
    mainProgram = pname;
  };
})
