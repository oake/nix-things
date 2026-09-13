{
  pkgs,
  pname,
}:
let
  version = "0.1.0";
  inherit (pkgs)
    buildGoModule
    fetchFromGitHub
    lib
    ;
in
buildGoModule {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "anna-oake";
    repo = "rtl-proxy";
    rev = "v${version}";
    hash = "sha256-YJOqH4a4ArTGoehLl6Bb4dMzzJ3JBXKAbiDal7VMh3Y=";
  };

  vendorHash = "sha256-vjGhS7nhjXlms1ZsRG6Qy/7ategUIgwiBwk943cz9Lk=";

  subPackages = [ "cmd/rtl-proxy" ];

  ldflags = [
    "-s"
    "-w"
  ];

  env.CGO_ENABLED = 0;

  meta = {
    description = "Priority-aware proxy for rtl_tcp";
    homepage = "https://github.com/anna-oake/rtl-proxy";
    license = lib.licenses.mit;
    mainProgram = pname;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
