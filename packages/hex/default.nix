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
  version = "3.3.0";

  src = fetchurl {
    url = "https://github.com/anomalyco/hex/releases/download/v${finalAttrs.version}/hex-${finalAttrs.version}-macos-arm64.zip";
    hash = "sha256-HCjWoeeQMj7xmbSBvJIx5q2OcKF4W+hJE+Cnvwpuuzk=";
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
