{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    lib
    buildGoModule
    fetchFromGitHub
    ;
in
buildGoModule (finalAttrs: {
  inherit pname;
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "anna-oake";
    repo = "zone-wizard";
    tag = "v${finalAttrs.version}";
    hash = "sha256-1T5yO587eaTA/7oELdltwgAGYVlb4kaQKBdb1OVfxSU=";
  };

  vendorHash = "sha256-gP/Rc4S0aEfhnEqWcwrxOAlJjo3oDM4vFLpF6GrW1NQ=";

  ldflags = [
    "-s"
    "-w"
    "-X 'main.Version=v${finalAttrs.version}'"
  ];

  env.CGO_ENABLED = 0;

  meta = {
    homepage = "https://github.com/anna-oake/zone-wizard";
    description = "A tool to manage terraform files with Cloudflare DNS records";
    license = with lib.licenses; [ wtfpl ];
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    mainProgram = "zone-wizard";
  };
})
