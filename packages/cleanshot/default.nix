{
  pkgs,
  pname,
}:
let
  sigtool = pkgs.darwin.sigtool;
  inherit (pkgs)
    stdenv
    lib
    fetchurl
    makeWrapper
    _7zz
    rcodesign
    re-plistbuddy
    ;
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname;
  version = "5.0.1";

  src = fetchurl {
    url = "https://updates.getcleanshot.com/v3/CleanShot-X-${finalAttrs.version}.dmg";
    hash = "sha256-hauVyKS+T7ZQqU7Ah6fn2J9Oa9qcGGEc3USraj7bHPE=";
  };

  nativeBuildInputs = [
    _7zz
    makeWrapper
    rcodesign
    re-plistbuddy
    sigtool
  ];

  sourceRoot = ".";
  dontConfigure = true;
  dontFixup = true;

  unpackPhase = "7zz x -y -sns- $src >/dev/null";

  buildPhase = ''
    $CC -x objective-c -fobjc-arc -dynamiclib -fvisibility=hidden \
      -arch arm64 -arch x86_64 \
      -framework Foundation -framework AppKit \
      ${./redirect.m} -o libcsredirect.dylib
  '';

  installPhase = ''
    app="$out/Applications/CleanShot X.app"
    mkdir -p "$out/Applications"
    cp -R "CleanShot X.app" "$app"
    chmod -R u+w "$app"

    cp libcsredirect.dylib "$app/Contents/Frameworks/"
    plutil -insert LSEnvironment -dictionary "$app/Contents/Info.plist"
    plutil -insert LSEnvironment.DYLD_INSERT_LIBRARIES -string \
      "$app/Contents/Frameworks/libcsredirect.dylib" "$app/Contents/Info.plist"

    # Ad-hoc signatures cannot carry CleanShot's restricted team entitlements.
    plutil -create xml1 empty-entitlements.plist
    while IFS= read -r -d $'\0' file; do
      if sigtool --file "$file" check-requires-signature; then
        codesign --force --sign - --entitlements empty-entitlements.plist "$file"
      fi
    done < <(find "$app" -type f -print0)
    rcodesign sign --entitlements-xml-file empty-entitlements.plist "$app"

    makeWrapper /usr/bin/open "$out/bin/${pname}" --add-flags "'$app'"
  '';

  meta = {
    description = "CleanShot X with configurable cloud API and dashboard URLs";
    homepage = "https://cleanshot.com";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.unfree;
    mainProgram = pname;
    platforms = [ "aarch64-darwin" ];
  };
})
