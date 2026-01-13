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
buildGoModule rec {
  inherit pname;
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "anna-oake";
    repo = "age-plugin-1p-pq";
    tag = "v${version}";
    hash = "sha256-hFN+2CJ/vi5XTtRXQmBB3WmTDjjXV1gfzYgcA4xJKqY=";
  };

  vendorHash = "sha256-6xFkrAfc0Hw1/5ihI3VJrP+hUanZu262MJD1NXQmzXc=";

  ldflags = [
    "-s"
    "-w"
  ];

  env.CGO_ENABLED = 0;

  meta = {
    homepage = "https://github.com/anna-oake/age-plugin-1p-pq";
    description = "Use age with hybrid post-quantum identities stored in 1Password";
    license = with lib.licenses; [ mit ];
    platforms = lib.platforms.unix;
    mainProgram = "age-plugin-1p-pq";
  };
}
