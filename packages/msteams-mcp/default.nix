{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    buildNpmPackage
    fetchFromGitHub
    lib
    ;
in
buildNpmPackage (finalAttrs: {
  inherit pname;
  version = "0.32.0";

  src = fetchFromGitHub {
    owner = "m0nkmaster";
    repo = "msteams-mcp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-fQ+ofEAmMScSYlYbuN1X4dgDmvWTNWyLK06e2cO8H6w=";
  };

  npmDepsHash = "sha256-f/VZrW8I/mFUCTjalkgRiwlHjot3UvWBRIPjgFEn/C0=";

  patches = [ ./browser-executable.patch ];

  passthru.updateScript = pkgs.nix-update-script { };

  meta = {
    description = "Microsoft Teams MCP server and command-line client";
    homepage = "https://github.com/m0nkmaster/msteams-mcp";
    license = lib.licenses.mit;
    mainProgram = "msteams-mcp";
    platforms = lib.platforms.unix;
  };
})
