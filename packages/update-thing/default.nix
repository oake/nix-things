{ pkgs, pname }:
let
  patchedNixUpdate = pkgs.nix-update.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (pkgs.fetchpatch {
        url = "https://github.com/Mic92/nix-update/commit/d545c1fad667e573128cad0db55fdc77134a4d3c.patch";
        hash = "sha256-CVSihQevWIwKSnjKo9ilw1hdi4a1t0xr6DunAUKSBFA=";
      })
    ];
  });
in
pkgs.writeShellApplication {
  name = pname;
  runtimeInputs = with pkgs; [
    coreutils
    curl
    git
    gnused
    jq
    nix
    patchedNixUpdate
  ];
  text = ''
    runner_system=${pkgs.lib.escapeShellArg pkgs.stdenv.hostPlatform.system}
  ''
  + builtins.readFile ./update-thing.sh;

  passthru.updateScript = null;

  meta = {
    description = "Update a flake package using its declared update instructions";
    mainProgram = pname;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
}
