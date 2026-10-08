{ pkgs, pname }:
pkgs.buildDotnetModule {
  inherit pname;
  version = "0-unstable-2026-10-08";
  src = pkgs.fetchFromGitHub {
    owner = "maeve-oake";
    repo = "beesly";
    rev = "64d22d7c4cab42dc16a6559b83db7ced0536eb9c";
    hash = "sha256-TWYaINaEMo8v/5tHYmBjC/SB/+/xJc3TyeNZFhk8yN8=";
  };
  projectFile = "beesly.csproj";
  nugetDeps = ./deps.json;
  dotnet-sdk = pkgs.dotnet-sdk_10;
  dotnet-runtime = pkgs.dotnet-aspnetcore_10;
  executables = [ "beesly" ];
  meta = {
    description = "Cisco phone XML services with Home Assistant and FreePBX integration";
    homepage = "https://github.com/maeve-oake/beesly";
    mainProgram = "beesly";
    platforms = pkgs.lib.platforms.linux;
  };
}
