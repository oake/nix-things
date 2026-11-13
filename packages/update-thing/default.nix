{ pkgs, pname }:
pkgs.writeShellApplication {
  name = pname;
  runtimeInputs = with pkgs; [
    coreutils
    curl
    git
    gnused
    jq
    nix
    nix-update
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
