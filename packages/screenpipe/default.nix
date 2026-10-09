{ pkgs, pname }:
let
  version = "2.7.97";
  tag = "app-v${version}";
  src = pkgs.fetchFromGitHub {
    owner = "screenpipe";
    repo = "screenpipe";
    inherit tag;
    hash = "sha256-sp6Cn99vJFAzIwUF3HueT0HHOlmgh/WhXv1Hwn/7z1I=";
  };

  interFont = pkgs.fetchurl {
    name = "Inter.ttf";
    url = "https://raw.githubusercontent.com/google/fonts/2eb0b48d5f760f62e286216f0859a8c540dbc1bd/ofl/inter/Inter%5Bopsz,wght%5D.ttf";
    hash = "sha256-KRYKgP9J3cqyyXcRJH4IsfqyekhKMpzouBPYINxVkDE=";
  };
  headingFont = pkgs.fetchurl {
    name = "SpaceGrotesk.ttf";
    url = "https://raw.githubusercontent.com/google/fonts/2eb0b48d5f760f62e286216f0859a8c540dbc1bd/ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf";
    hash = "sha256-rK1t4fyTQ29cDx9BN3Ue8E8a6jBj5wNlNZcP/PvXn3I=";
  };
  swiftRs = pkgs.fetchFromGitHub {
    owner = "brendonovich";
    repo = "swift-rs";
    rev = "f64a4514de07f450ec5b6aa297624cd3479d9579";
    hash = "sha256-glYla3P2L67uj2SWhLIUmLPiAtJOYzp08eNkmlAZX1w=";
  };
  mlxMetallib = pkgs.fetchurl {
    url = "https://github.com/screenpipe/screenpipe/releases/download/mlx-metallib-v0.2.0/mlx.metallib";
    hash = "sha256-0HcRDb5M9eL2Vyq7ej6c+qh9v8bQoc1kfmdHNeOf9nM=";
  };
  xcrun = pkgs.writeShellScriptBin "xcrun" ''
    if [ "$1" = "--sdk" ]; then shift 2; fi
    case "$1" in
      --show-sdk-path) echo "$SDKROOT" ;;
      --find) command -v "$2" ;;
      *) exec "$@" ;;
    esac
  '';

  nodeModules = pkgs.stdenvNoCC.mkDerivation {
    pname = "${pname}-node-modules";
    inherit version src;
    nativeBuildInputs = [
      pkgs.bun
      pkgs.writableTmpDirAsHomeHook
    ];
    dontConfigure = true;
    dontFixup = true;
    dontPatchShebangs = true;
    buildPhase = ''
      runHook preBuild
      cd apps/screenpipe-app-tauri
      export BUN_INSTALL_CACHE_DIR="$TMPDIR/bun-cache"
      bun install --backend=copyfile --frozen-lockfile --ignore-scripts --no-progress
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      rm -rf node_modules/@screenpipe/workflows-ui
      cp -R ../../packages/workflows-ui node_modules/@screenpipe/workflows-ui
      cp -R node_modules "$out"
      runHook postInstall
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-EuJdTwJphBTn51/9gYGfLo5onia/QeAi0NtwRNMKKZA=";
  };
  frontend = pkgs.stdenvNoCC.mkDerivation {
    pname = "${pname}-frontend";
    inherit version src;
    patches = [
      ./personal-local-features.patch
      ./offline-fonts.patch
    ];
    nativeBuildInputs = [
      pkgs.bun
      pkgs.nodejs
      pkgs.writableTmpDirAsHomeHook
    ];
    env = {
      NEXT_PUBLIC_SCREENPIPE_PERSONAL_BUILD = "1";
      SCREENPIPE_NATIVE_PREBUILD_COMPLETE = "1";
      SCREENPIPE_FRONTEND_CACHE_DIR = "off";
      SCREENPIPE_I18N_MODE = "off";
      NEXT_TELEMETRY_DISABLED = "1";
      CI = "true";
    };
    configurePhase = ''
      runHook preConfigure
      cd apps/screenpipe-app-tauri
      cp -R ${nodeModules} node_modules
      chmod -R u+w node_modules
      patchShebangs --build node_modules
      mkdir -p app/fonts
      cp ${interFont} app/fonts/Inter.ttf
      cp ${headingFont} app/fonts/SpaceGrotesk.ttf
      runHook postConfigure
    '';
    buildPhase = ''
      runHook preBuild
      bun test lib/personal-local-build.test.ts
      bun run build
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      cp -R out "$out"
      runHook postInstall
    '';
    dontFixup = true;
  };

  unwrapped = pkgs.rustPlatform.buildRustPackage {
    inherit pname version src;
    patches = [
      ./personal-local-features.patch
      ./offline-fonts.patch
    ];
    cargoRoot = "apps/screenpipe-app-tauri/src-tauri";
    cargoDeps =
      (pkgs.rustPlatform.fetchCargoVendor {
        inherit pname version src;
        cargoRoot = "apps/screenpipe-app-tauri/src-tauri";
        hash = "sha256-9reuPtFz4vJEuP66jKwCht6oA46KsQx9wTmn9/Y0sq4=";
      }).overrideAttrs
        (old: {
          nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.patch ];
          buildCommand = ''
            cp -R "$vendorStaging" staging
            chmod -R u+w staging
            patch -p1 -d staging/git/0d3d1f30a78bb4616b4a4d0939a29ad0c1a8e14f < ${./nokhwa-workspace.patch}
            fetch-cargo-vendor-util create-vendor "$PWD/staging" "$out"
          '';
        });
    buildAndTestSubdir = "apps/screenpipe-app-tauri";
    buildFeatures = [
      "metal"
      "redact-onnx-coreml"
    ];
    nativeBuildInputs =
      with pkgs;
      [
        bun
        cargo-tauri.hook
        cmake
        nodejs
        swift
        swiftpm
        pkg-config
        rustPlatform.bindgenHook
        writableTmpDirAsHomeHook
        darwin.autoSignDarwinBinariesHook
      ]
      ++ [ xcrun ];
    buildInputs = with pkgs; [
      apple-sdk_15
      bzip2
      ffmpeg
      libsamplerate
      oniguruma
      onnxruntime
      openssl
      sqlite
      xz
      zlib
    ];
    env = {
      SCREENPIPE_PERSONAL_BUILD = "1";
      NEXT_PUBLIC_SCREENPIPE_PERSONAL_BUILD = "1";
      SCREENPIPE_NATIVE_PREBUILD_COMPLETE = "1";
      SCREENPIPE_FRONTEND_CACHE_DIR = "off";
      SCREENPIPE_I18N_MODE = "off";
      NEXT_TELEMETRY_DISABLED = "1";
      CI = "true";
      ORT_LIB_LOCATION = "${pkgs.onnxruntime}/lib";
      ORT_PREFER_DYNAMIC_LINK = "1";
      ORT_STRATEGY = "system";
    };
    configurePhase = ''
      runHook preConfigure
      app=apps/screenpipe-app-tauri
      cp -R ${frontend} "$app/out"
      cd "$app"
      cp -L ${pkgs.bun}/bin/bun src-tauri/bun-aarch64-apple-darwin
      cp -L ${pkgs.ffmpeg}/bin/ffmpeg src-tauri/ffmpeg-aarch64-apple-darwin
      cp -L ${pkgs.ffmpeg}/bin/ffprobe src-tauri/ffprobe-aarch64-apple-darwin
      cp ${mlxMetallib} src-tauri/mlx.metallib
      cp ${mlxMetallib} src-tauri/mlx.metallib-aarch64-apple-darwin
      ln -s ${nodeModules} node_modules
      bun -e 'import { prepareLocalization } from "./scripts/i18n/prepare.mjs"; await prepareLocalization();'
      rm node_modules
      bun -e '
        const path = "src-tauri/tauri.conf.json";
        const config = await Bun.file(path).json();
        config.build.beforeBuildCommand = "";
        config.bundle.targets = ["app"];
        config.bundle.externalBin = ["bun", "ffmpeg", "ffprobe", "mlx.metallib"];
        config.bundle.createUpdaterArtifacts = false;
        await Bun.write(path, JSON.stringify(config, null, 2));
        const macPath = "src-tauri/tauri.macos.conf.json";
        const mac = await Bun.file(macPath).json();
        mac.bundle.externalBin = config.bundle.externalBin;
        await Bun.write(macPath, JSON.stringify(mac, null, 2));
      '
      cd ../..
      runHook postConfigure
    '';
    postPatch = ''
      vendorDir="$NIX_BUILD_TOP/${pname}-${version}-vendor"
      manifest="$vendorDir/source-git-13/permission-flow-0.1.40/PermissionFlowShim/Package.swift"
      test -f "$manifest"
      cp -R ${swiftRs} "$(dirname "$manifest")/swift-rs"
      patch -p1 -d "$(dirname "$(dirname "$manifest")")" < ${./permission-flow-offline.patch}
    '';
    postInstall = ''
      mkdir -p "$out/bin"
      cat > "$out/bin/screenpipe-app" <<EOF
      #!${pkgs.runtimeShell}
      exec "$out/Applications/screenpipe.app/Contents/MacOS/screenpipe-app" "\$@"
      EOF
      chmod +x "$out/bin/screenpipe-app"
    '';
    doCheck = false;
    passthru = { inherit nodeModules frontend; };
    meta = {
      description = "Screenpipe desktop app with personal-use local features enabled";
      homepage = "https://screenpipe.com";
      license = {
        shortName = "screenpipe-commercial";
        fullName = "Screenpipe Commercial License";
        free = false;
        url = "https://github.com/screenpipe/screenpipe/blob/${tag}/LICENSE.md";
      };
      platforms = [ "aarch64-darwin" ];
      mainProgram = "screenpipe-app";
    };
  };
in
pkgs.stdenvNoCC.mkDerivation {
  inherit (unwrapped) pname version meta;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R ${unwrapped}/. "$out"
    chmod -R u+w "$out"
    mv "$out/Applications/screenpipe.app/Contents/MacOS/mlx.metallib" "$out/Applications/screenpipe.app/Contents/Resources/mlx.metallib"
    /usr/bin/xattr -c "$out/Applications/screenpipe.app/Contents/Resources/mlx.metallib"
    ln -s ../Resources/mlx.metallib "$out/Applications/screenpipe.app/Contents/MacOS/mlx.metallib"
    substituteInPlace "$out/bin/screenpipe-app" --replace-fail "${unwrapped}" "$out"
    wrapProgram "$out/bin/screenpipe-app" --set SCREENPIPE_SKIP_ONBOARDING 1
    /usr/bin/plutil -replace LSEnvironment.SCREENPIPE_SKIP_ONBOARDING -string 1 "$out/Applications/screenpipe.app/Contents/Info.plist"
    /usr/bin/codesign --force --deep --sign - --entitlements ${src}/apps/screenpipe-app-tauri/src-tauri/entitlements.plist "$out/Applications/screenpipe.app"
    /usr/bin/codesign --verify --deep --strict "$out/Applications/screenpipe.app"
    runHook postInstall
  '';
  passthru = { inherit nodeModules frontend unwrapped; };
}
