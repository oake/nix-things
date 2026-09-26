{
  pkgs,
  pname,
}:
pkgs.buildGoModule {
  inherit pname;
  src = pkgs.fetchFromGitHub {
    owner = "oake";
    repo = "infra";
    rev = "878b518a1a6deca7db70824fd4e0f554604f2210";
    hash = "sha256-XH2q8Y1sqt3uftevEu+ogH65rCMdninD6sl8RbsoRE0=";
  };
  version = "unstable-2026-09-26";
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
