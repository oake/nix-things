{
  pkgs,
  pname,
}:
let
  inherit (pkgs) lib;
  version = "1.14.1";
  propofol = pkgs.fetchFromGitHub {
    owner = "kageroumado";
    repo = "propofol";
    rev = "eac9055ca7373fa94aa5b9b501f3a83b3dc1ef80";
    hash = "sha256-XhUrk5k5NWPBYbdbk6J1HRwtzkiwn7CQtaAeIbgAd1E=";
  };
in
pkgs.stdenv.mkDerivation {
  inherit pname version;
  src = pkgs.fetchFromGitHub {
    owner = "kageroumado";
    repo = "adrafinil";
    tag = "v${version}";
    hash = "sha256-FAOq8TteaBHcv2znttjGaQFRS1gIOMUZwaA+cwchfhM=";
  };

  patches = [
    ./nix-managed.patch
    ./nix-caller-verification.patch
  ];

  nativeBuildInputs = with pkgs; [
    (swift.override {
      enableRepl = false;
      enableSourceKitLSP = false;
    })
    swiftpm
    python3
    rcodesign
    libicns
    imagemagick
  ];
  buildInputs = [ pkgs.apple-sdk_26 ];
  env.MACOSX_DEPLOYMENT_TARGET = "26.4";
  # Swift propagates SDK 27, whose SwiftUI macros are unavailable here.
  swiftpmFlags = [
    "--build-system"
    "native"
    "--sdk"
    pkgs.apple-sdk_26.sdkroot
  ];

  postPatch = ''
    cp ${./Package.swift} Package.swift
    cp -R ${propofol} Propofol
    chmod -R u+w Propofol
    substituteInPlace AdrafinilShared/Sources/AdrafinilShared/IPC/CallerVerifier.swift \
      --replace-fail '@adrafinilBundle@' "$out/Applications/Adrafinil.app"
  '';

  preBuild = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
  '';

  installPhase = ''
    runHook preInstall
    app="$out/Applications/Adrafinil.app"
    mkdir -p "$app/Contents/"{MacOS,Helpers,Resources,Library/LaunchAgents,Library/LaunchDaemons} "$out/bin"
    buildDir="$(swiftpmBinPath)"
    cp "$buildDir/Adrafinil" "$app/Contents/MacOS/"
    cp "$buildDir/AdrafinilCLI" "$app/Contents/Helpers/adrafinil"
    cp "$buildDir/AdrafinilDaemon" "$app/Contents/Library/LaunchAgents/"
    cp "$buildDir/AdrafinilHelper" "$app/Contents/Library/LaunchDaemons/"
    ln -s "$app/Contents/Helpers/adrafinil" "$out/bin/adrafinil"
    python3 ${./bundle-resources.py} "$app" "${version}"
    magick .github/adrafinil-icon.png -resize 512x512 icon.png
    png2icns "$app/Contents/Resources/Adrafinil.icns" icon.png
    runHook postInstall
  '';

  # Signing must happen after all Mach-O changes, and the bundle path is part of
  # the authentication boundary. Hardened runtime prevents DYLD injection into clients.
  postFixup = ''
    app="$out/Applications/Adrafinil.app"
    # Library/Launch{Agents,Daemons} are treated as resources by bundle signers,
    # so sign those executables explicitly before sealing the outer bundle.
    for executable in \
      "$app/Contents/Helpers/adrafinil" \
      "$app/Contents/Library/LaunchAgents/AdrafinilDaemon" \
      "$app/Contents/Library/LaunchDaemons/AdrafinilHelper"; do
      rcodesign sign --timestamp-url none --code-signature-flags runtime "$executable"
    done
    rcodesign sign --timestamp-url none --code-signature-flags runtime \
      --code-signature-flags Contents/Helpers/adrafinil:runtime "$app"
  '';

  passthru.updateScript = [
    ../../lib/update-source.sh
    ./default.nix
  ];

  meta = {
    description = "Native menu-bar app that inhibits sleep, including with the lid closed";
    homepage = "https://github.com/kageroumado/adrafinil";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    mainProgram = "adrafinil";
  };
}
