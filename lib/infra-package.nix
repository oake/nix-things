{
  pkgs,
  pname,
}:
pkgs.buildGoModule {
  inherit pname;
  src = pkgs.fetchFromGitHub {
    owner = "oake";
    repo = "infra";
    rev = "deb8bc30f5043a6d05f093e6874cc4221b0c10be";
    hash = "sha256-9cOeSpDNymBW3Apt6orgxxeM0gVvPD0Vp8nJJDz+c48=";
  };
  version = "unstable-2026-09-27";
  vendorHash = "sha256-UTkp3qXSpq/hljlAh4CWMhg4T0r7yJwDR/CPWqhtNe4=";
  subPackages = [ "cmd/${pname}" ];
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
  ];
  meta = {
    homepage = "https://github.com/oake/infra";
    mainProgram = pname;
    platforms = pkgs.lib.platforms.unix;
  };
}
