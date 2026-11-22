{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    buildNpmPackage
    fetchFromGitHub
    lib
    makeWrapper
    microsoft-edge
    ;
in
buildNpmPackage (finalAttrs: {
  inherit pname;
  version = "0.31.5";

  src = fetchFromGitHub {
    owner = "m0nkmaster";
    repo = "msteams-mcp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-3KusTU97HJYFYBlStHFkARgGjWBL54uBalP9ABcRHOw=";
  };

  npmDepsHash = "sha256-+ZcC7O9Pbsbgc1ky8zcZS3pCItT52tJccsvAAtipIxE=";

  patches = [ ./edge-executable.patch ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    for program in msteams msteams-mcp; do
      wrapProgram "$out/bin/$program" \
        --set-default TEAMS_BROWSER msedge \
        --set-default TEAMS_BROWSER_EXECUTABLE "${lib.getExe microsoft-edge}"
    done
  '';

  passthru.updateScript = pkgs.nix-update-script { };

  meta = {
    description = "Microsoft Teams MCP server and command-line client";
    homepage = "https://github.com/m0nkmaster/msteams-mcp";
    license = lib.licenses.mit;
    mainProgram = "msteams-mcp";
    platforms = [ "x86_64-linux" ];
  };
})
