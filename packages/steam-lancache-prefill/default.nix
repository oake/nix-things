{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    lib
    buildDotnetModule
    dotnetCorePackages
    fetchFromGitHub
    ;
in
buildDotnetModule (finalAttrs: {
  inherit pname;
  version = "3.7.2";

  src = fetchFromGitHub {
    owner = "tpill90";
    repo = "steam-lancache-prefill";
    rev = "v${finalAttrs.version}";
    hash = "sha256-469AQCuqjjkWElRPea/78CHi1ZBYF7y7O7QxlJb/I48=";
    fetchSubmodules = true;
  };

  projectFile = "SteamPrefill/SteamPrefill.csproj";
  nugetDeps = ./deps.json;

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.aspnetcore_8_0;

  executables = [ "SteamPrefill" ];

  patches = [ ./current-dir-config.patch ];

  postInstall = ''
    rm -rf $out/lib/steam-lancache-prefill/update.sh
  '';

  meta = {
    description = "Automatically fills a Lancache with games from Steam";
    homepage = "https://github.com/tpill90/steam-lancache-prefill";
    changelog = "https://github.com/tpill90/steam-lancache-prefill/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ rhoriguchi ];
    mainProgram = "SteamPrefill";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
