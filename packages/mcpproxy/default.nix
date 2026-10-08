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
  version = "0.70.0";
  src = fetchFromGitHub {
    owner = "smart-mcp-proxy";
    repo = "mcpproxy-go";
    tag = "v${version}";
    hash = "sha256-sVSqSr87F88D3pwyqQ4eP9zKkftwsI1ytt82XlDkz4c=";
  };
  frontend = buildNpmPackage {
    pname = "${pname}-frontend";
    inherit version src;
    sourceRoot = "${src.name}/frontend";
    nodejs = pkgs.nodejs_24;
    npmDepsHash = "sha256-j0F7aly/5ESwX/bdp9sqIJRKYCEuwpZX0xmu1ledVwc=";
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
  vendorHash = "sha256-rcQTRPuDQfbQY2mdWfG5awX4o0H/adN0caOhQGKkjDE=";
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
    "-X main.version=v${version}"
    "-X github.com/smart-mcp-proxy/mcpproxy-go/internal/httpapi.buildVersion=v${version}"
  ];

  meta = {
    description = "Local MCP gateway with upstream OAuth and a web management UI";
    homepage = "https://github.com/smart-mcp-proxy/mcpproxy-go";
    license = lib.licenses.mit;
    mainProgram = "mcpproxy";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
