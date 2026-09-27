{
  pkgs,
  pname,
}:
pkgs.buildGoModule {
  inherit pname;
  src = pkgs.fetchFromGitHub {
    owner = "oake";
    repo = "infra";
    rev = "d7da1602c91b83bdfa67710bba65beeb50295f3e";
    hash = "sha256-+ImZfe7rGJNEjhOLewqubAR7xAVlRsbNaZNxo4hxYgI=";
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
