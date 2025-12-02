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
    curl
    jq
    unzip
    ;
in
buildDotnetModule (finalAttrs: {
  inherit pname;
  version = "3.4.1.1";

  src = fetchFromGitHub {
    owner = "anna-oake";
    repo = "steam-lancache-prefill";
    rev = "6afd249586670ded128a0e3ff293c50fd054f1aa";
    hash = "sha256-/k4u9euHPL7xk7s3xZXJIeNM6COYocIszbJmhdmVcak=";
    fetchSubmodules = true;
  };

  projectFile = "SteamPrefill/SteamPrefill.csproj";
  nugetDeps = ./deps.json;

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.aspnetcore_8_0;

  executables = [ "SteamPrefill" ];

  patches = [ ./current-dir-config.patch ];

  nativeBuildInputs = [
    curl
    jq
    unzip
  ];

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
    platforms = lib.platforms.all;
  };
})
