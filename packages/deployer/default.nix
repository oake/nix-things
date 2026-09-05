{
  pkgs,
  pname,
}:
let
  version = "0.1.0";
  inherit (pkgs)
    lib
    buildGoModule
    fetchFromGitHub
    ;
in
buildGoModule {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "anna-oake";
    repo = "deployer";
    rev = "v${version}";
    hash = "sha256-27HRD90pqkVNRw/KbdOs+kiiF/ShNQcAesgz8Tf0t4U=";
  };

  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
  ];

  env.CGO_ENABLED = 0;

  meta = {
    homepage = "https://github.com/anna-oake/deployer";
    description = "Deploy CI-cached NixOS configurations for the next boot";
    platforms = lib.platforms.unix;
    mainProgram = pname;
  };
}
