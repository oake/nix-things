{
  pkgs,
  pname,
}:
pkgs.buildGoModule (finalAttrs: {
  inherit pname;
  version = "1";

  src = pkgs.fetchFromGitHub {
    owner = "anna-oake";
    repo = "steam-lancache-beacon";
    tag = "v${finalAttrs.version}";
    hash = "sha256-/KRGFh94zmpwkvAvfvhfpcbcdtaDg5gesYrPBbo8z5o=";
  };

  vendorHash = "sha256-afblZuzp11Oe8c8/BM8oz/DfUa3OxDBUGER1y0IYK4o=";
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "Report Steam shader cache profiles to a LanCache manager";
    homepage = "https://github.com/anna-oake/steam-lancache-beacon";
    mainProgram = pname;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
