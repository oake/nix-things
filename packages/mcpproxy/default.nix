{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    lib
    fetchFromGitHub
    buildGoModule
    buildNpmPackage
    ;
  version = "0-unstable-2026-11-11";
  src = fetchFromGitHub {
    owner = "slopster67";
    repo = "mcpproxy-go";
    rev = "f59e5d814283b67dac9c21dec82e2cfc7828dd12";
    hash = "sha256-WJk8zvLRuEeiQ2KuvTLuWAQscwL9rRVu2FqMugKmSRU=";
  };
  frontend = buildNpmPackage {
    pname = "${pname}-frontend";
    inherit version src;
    sourceRoot = "${src.name}/frontend";
    nodejs = pkgs.nodejs_26;
    npmDepsHash = "sha256-RXLAORCcN5CrrHka6INVxPGiuZWeS5OfU1cHeYNH7pM=";
    dontNpmInstall = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r dist/. "$out/"
      runHook postInstall
    '';
  };
in
buildGoModule {
  inherit pname version src;
  vendorHash = "sha256-vklTd5YEHnXSOENSN4coq945LUJ6YZA/e28xwG80t+s=";
  subPackages = [ "cmd/mcpproxy" ];
  doCheck = false;
  env.CGO_ENABLED = 0;

  preBuild = ''
    mkdir -p web/frontend/dist
    cp -r ${frontend}/. web/frontend/dist/
  '';

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X github.com/slopster67/mcpproxy-go/internal/httpapi.buildVersion=${version}"
  ];

  meta = {
    description = "Local MCP gateway with upstream OAuth and a web management UI";
    homepage = "https://github.com/slopster67/mcpproxy-go";
    license = lib.licenses.mit;
    mainProgram = "mcpproxy";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
