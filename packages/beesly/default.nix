{ pkgs, pname }:
pkgs.buildDotnetModule {
  inherit pname;
  version = "0.1.0";
  src = pkgs.fetchFromGitHub {
    owner = "maeve-oake";
    repo = "beesly";
    rev = "2b4e00047b84c4160f11caf34413cf145f72ff3a";
    hash = "sha256-tJSgbj0NUVOgck2+xnYVVrAfVzk/iW5q2PohfPPfxbI=";
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
