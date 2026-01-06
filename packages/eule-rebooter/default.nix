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
buildGoModule {
  inherit pname;
  version = "0.1";

  src = fetchFromGitHub {
    owner = "anna-oake";
    repo = "eule-rebooter";
    rev = "4fe6dae2a50a65fb44c52f1914da143659287a82";
    hash = "sha256-zmRa70rRzYNN7PqEcN7vAwWiJpXicUF/UxfvzKUjry8=";
  };

  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
  ];

  env.CGO_ENABLED = 0;

  meta = {
    homepage = "https://github.com/anna-oake/eule-rebooter";
    description = "Reboots the system when instructed by a pollable HTTP server";
    license = with lib.licenses; [ wtfpl ];
    platforms = lib.platforms.linux;
    mainProgram = "eule-rebooter";
  };
}
