{
  pkgs,
  pname,
}:
let
  inherit (pkgs) lib;
in
pkgs.rustPlatform.buildRustPackage (finalAttrs: {
  inherit pname;
  version = "0.52.9";

  src = pkgs.fetchFromGitHub {
    owner = "trycua";
    repo = "cua";
    tag = "cua-driver-rs-v${finalAttrs.version}";
    hash = "sha256-V8Xd3hQhME3o1wqvjc1ulcPIwdwvSWR0+LyQN14Cecs=";
  };

  cargoRoot = "libs/cua-driver/rust";
  buildAndTestSubdir = "libs/cua-driver/rust";
  cargoHash = "sha256-5j3KJRICX/Or4gnF7HmZeQnXmULafI8jOoeaR2MbBLk=";

  patches = [
    ./relocatable-app.patch
    ./helium-macos.patch
    ./daemon-lifecycle.patch
  ];

  nativeBuildInputs = [
    pkgs.pkg-config
    pkgs.rcodesign
    pkgs.re-plistbuddy
    pkgs.swiftpm
    (pkgs.swift.override {
      enableRepl = false;
      enableSourceKitLSP = false;
    })
  ];
  buildInputs = [
    pkgs.apple-sdk_26
    pkgs.zstd
  ];

  env = {
    MACOSX_DEPLOYMENT_TARGET = "14.0";
    CARGO_PROFILE_RELEASE_LTO = "thin";
    CUA_DRIVER_GIT_SHA = finalAttrs.src.tag;
  };

  cargoBuildFlags = [
    "-p"
    "cua-driver"
    "-p"
    "cursor-theme-cli"
  ];

  doCheck = false;
  dontUseSwiftpmBuild = true;

  installPhase = ''
    runHook preInstall

    app="$out/Applications/CuaDriver.app"
    mkdir -p "$app/Contents/MacOS" "$out/bin" "$out/share/doc/${pname}"
    cp libs/cua-driver/rust/scripts/CuaDriverBundle/Contents/Info.plist "$app/Contents/"
    cp -R libs/cua-driver/rust/scripts/CuaDriverBundle/Contents/Resources "$app/Contents/"
    cp target/aarch64-apple-darwin/release/{cua-driver,cua-cursor-theme} "$app/Contents/MacOS/"
    plutil -replace CFBundleShortVersionString -string '${finalAttrs.version}' "$app/Contents/Info.plist"
    plutil -replace CFBundleVersion -string '${finalAttrs.version}' "$app/Contents/Info.plist"
    for executable in cua-driver cua-cursor-theme; do
      ln -s "$app/Contents/MacOS/$executable" "$out/bin/$executable"
    done
    cp LICENSE.md "$out/share/doc/${pname}/"

    runHook postInstall
  '';

  postFixup = ''
    rcodesign sign --timestamp-url none "$out/Applications/CuaDriver.app"
  '';

  passthru.updateScript = pkgs.nix-update-script {
    extraArgs = [
      "--use-github-releases"
      "--github-releases-limit=100"
      "--version=unstable"
      "--version-regex"
      "^cua-driver-rs-v([0-9]+[.][0-9]+[.][0-9]+)$"
    ];
  };

  meta = {
    description = "Background desktop automation with an agent cursor, CLI and MCP server";
    homepage = "https://cua.ai/docs/cua-driver";
    changelog = "https://github.com/trycua/cua/releases/tag/cua-driver-rs-v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "cua-driver";
    platforms = [ "aarch64-darwin" ];
  };
})
