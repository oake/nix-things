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
    repo = "mc-datapack-generator";
    tag = "v${finalAttrs.version}";
    hash = "sha256-GvFL/U61YBTpnQS46a1HKLuYNlJJFjC2pN4iNXBc9ns=";
  };

  vendorHash = "sha256-SlPbNAVLusri+MdGHvpr0WF+RSwwFebLpk227eIVVCE=";

  ldflags = [
    "-s"
    "-w"
  ];

  env.CGO_ENABLED = 0;

  meta = {
    homepage = "https://github.com/anna-oake/mc-datapack-generator";
    description = "A tool to generate Minecraft datapacks of some kinds";
    license = with lib.licenses; [ mit ];
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
      "aarch64-darwin"
    ];
    mainProgram = "mc-datapack-generator";
  };
})
