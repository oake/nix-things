{
  pkgs,
  pname,
}:
# Server-only build of T3 Code: the `t3` CLI/server plus the web client it
# serves, without the Electron desktop app that nixpkgs' t3code ships.
let
  inherit (pkgs) lib stdenv;
  nodejs = pkgs.nodejs_26;
  pnpm = pkgs.pnpm_12;
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname;
  version = "0.1.9";
  strictDeps = true;
  __structuredAttrs = true;

  src = pkgs.fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    tag = "v${finalAttrs.version}";
    hash = "sha256-3i5o9gs/nYx0vxyn2ukYtLEA21UZZdX0x4ebgxY8bhI=";
  };

  postPatch = ''
    # the preview browser downloads a generic-linux chrome-headless-shell that
    # can't run on NixOS; let the environment provide one instead, e.g.
    # T3CODE_BROWSER_EXECUTABLE=''${chromium}/bin/chromium
    substituteInPlace apps/server/src/preview/PreviewBrowser.ts \
      --replace-fail \
        '  return PreviewBrowser.of({ executable, installed });' \
        '  const override = process.env.T3CODE_BROWSER_EXECUTABLE;
      if (override) {
        return PreviewBrowser.of({
          executable: Effect.succeed(override),
          installed: Effect.succeed(Option.some(override)),
        });
      }
      return PreviewBrowser.of({ executable, installed });'

    # the web build fetches SPDX license templates from GitHub otherwise
    mkdir -p .generated/third-party-licenses/spdx/v3.28.0
    cp ${pkgs.spdx-license-list-data.json}/json/details/*.json \
      .generated/third-party-licenses/spdx/v3.28.0
  '';

  nativeBuildInputs = [
    pkgs.makeBinaryWrapper
    pkgs.node-gyp
    nodejs
    pkgs.python3
    pnpm
    pkgs.pnpmConfigHook
    pkgs.cacert
  ];

  # `t3` is the server; its build task depends on `@t3tools/web#build`, whose
  # output is copied into the server's dist/client.
  pnpmWorkspaces = [
    "@t3tools/monorepo"
    "t3..."
    "@t3tools/web..."
    "@t3tools/scripts..."
  ];

  pnpmDeps = pkgs.fetchPnpmDeps {
    inherit pnpm;
    inherit (finalAttrs)
      pname
      version
      src
      pnpmWorkspaces
      ;
    fetcherVersion = 5;
    hash = "sha256-mprGkCoSnB2MM5xE6HdbVtBFJ+qtBmzZTfWTcE5AcjM=";
  };

  buildPhase = ''
    runHook preBuild

    # pnpm otherwise sees the version bump below as dependency drift and reinstalls
    export pnpm_config_verify_deps_before_run=false
    node scripts/update-release-package-versions.ts ${finalAttrs.version}

    export npm_config_nodedir=${nodejs}
    # `vp config` in @t3tools/monorepo needs git
    pnpm rebuild --pending "''${pnpmInstallFlags[@]}" --filter '!@t3tools/monorepo'

    # upstream's public production Connect config is consumed by both the
    # server and web builds via loadRepoEnv; keep it tied to the pinned source
    cp .env.example .env
    pnpm vp run --filter t3 build

    runHook postBuild
  '';

  # vendored prebuilt native modules for other platforms; let fixup handle
  # shebangs and stripping but don't patchelf the tree
  dontPatchELF = true;
  noAuditTmpdir = true;

  installPhase = ''
    runHook preInstall

    # only the server's production dependencies, not the whole workspace's
    dest=$out/libexec/t3-server
    mkdir -p $dest/apps/server $dest/node_modules/.pnpm
    cp -r --no-preserve=mode apps/server/{package.json,node_modules,dist} $dest/apps/server
    pnpm --filter t3 list --prod --depth Infinity --parseable \
      | grep -o 'node_modules/\.pnpm/[^/]*' | sort -u \
      | while read -r entry; do
          # optional deps for other platforms are listed but not installed
          [ -e "$entry" ] || continue
          cp -r --no-preserve=mode "$entry" $dest/node_modules/.pnpm/
        done
    # sourcemaps, and katex's font scripts that would pull python3 into the closure
    find $dest \( -name '*.map' -o -name '*.py' \) -delete
    # links into workspace packages that are bundled into dist
    find $dest -xtype l -delete

    makeWrapper ${lib.getExe nodejs} $out/bin/t3 \
      --add-flags $dest/apps/server/dist/bin.mjs \
      --set-default T3CODE_RESOURCE_MONITOR_PATH ${lib.getExe finalAttrs.passthru.resourceMonitor}

    runHook postInstall
  '';

  passthru.resourceMonitor = pkgs.rustPlatform.buildRustPackage {
    pname = "${pname}-resource-monitor";
    inherit (finalAttrs) version src;
    sourceRoot = "${finalAttrs.src.name}/native/resource-monitor";
    cargoHash = "sha256-5cmG2daM1bVOA23gjjoalbx0fEL1hmqV6WZov0sUZp8=";
    meta.mainProgram = "t3-resource-monitor";
  };

  meta = {
    description = "T3 Code server (headless, without the desktop app)";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "t3";
    platforms = [ "x86_64-linux" ];
  };
})
