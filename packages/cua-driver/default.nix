{
  pkgs,
  pname,
}:
let
  inherit (pkgs) lib stdenv;
  inherit (stdenv.hostPlatform) isDarwin isLinux;
in
pkgs.rustPlatform.buildRustPackage (finalAttrs: {
  inherit pname;
  version = "0.53.2";

  src = pkgs.fetchFromGitHub {
    owner = "trycua";
    repo = "cua";
    tag = "cua-driver-rs-v${finalAttrs.version}";
    hash = "sha256-1ipjzmL8Gmvf2g3bExDAVlQM5BnLvQDXIXHLcXCqNtA=";
  };

  cargoRoot = "libs/cua-driver/rust";
  buildAndTestSubdir = "libs/cua-driver/rust";
  cargoHash = "sha256-xazdKM9X/zAQjvIXmLDnZLbdzpJMdphWrSM4vwsyC1Y=";

  patches = lib.optionals isDarwin [
    ./relocatable-app.patch
    ./helium-macos.patch
    ./daemon-lifecycle.patch
  ];

  nativeBuildInputs = [
    pkgs.pkg-config
  ]
  ++ lib.optionals isDarwin [
    pkgs.rcodesign
    pkgs.re-plistbuddy
    pkgs.swiftpm
    (pkgs.swift.override {
      enableRepl = false;
      enableSourceKitLSP = false;
    })
  ]
  ++ lib.optionals isLinux [
    pkgs.rustPlatform.bindgenHook
  ];

  buildInputs =
    lib.optional isDarwin pkgs.apple-sdk_26
    ++ [ pkgs.zstd ]
    ++ lib.optionals isLinux [
      pkgs.libx11
      pkgs.libxi
      pkgs.libxtst
      pkgs.libxext
      pkgs.pipewire
      pkgs.libei
      pkgs.libxkbcommon
    ];

  env = {
    CARGO_PROFILE_RELEASE_LTO = "thin";
    CUA_DRIVER_GIT_SHA = finalAttrs.src.tag;
  }
  // lib.optionalAttrs isDarwin {
    MACOSX_DEPLOYMENT_TARGET = "14.0";
  };

  cargoBuildFlags = [
    "-p"
    "cua-driver"
    "-p"
    "cursor-theme-cli"
  ]
  ++ lib.optionals isLinux [
    "--features"
    "cua-driver/portal-input,cua-driver/portal-capture"
  ];

  doCheck = false;
  dontUseSwiftpmBuild = isDarwin;

  installPhase = lib.optionalString isDarwin ''
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

  postFixup =
    lib.optionalString isDarwin ''
      rcodesign sign --timestamp-url none "$out/Applications/CuaDriver.app"
    ''
    + lib.optionalString isLinux ''
      patchelf --add-rpath ${lib.makeLibraryPath [ pkgs.pipewire ]} "$out/bin/cua-driver"
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
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
