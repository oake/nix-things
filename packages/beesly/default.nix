{ pkgs, pname }:
pkgs.buildDotnetModule {
  inherit pname;
  version = "0-unstable-2026-10-08";
  src = pkgs.fetchFromGitHub {
    owner = "maeve-oake";
    repo = "beesly";
    rev = "fc5532022c010883bd2216941c51871a1ab599ca";
    hash = "sha256-GBBgWW0jfbzL9SYp09NTJzVlaCEs4PBdXKpdFP6Sd8M=";
  };
  projectFile = "beesly.csproj";
  nugetDeps = ./deps.json;
  dotnet-sdk = pkgs.dotnet-sdk_10;
  dotnet-runtime = pkgs.dotnet-aspnetcore_10;
  executables = [ "beesly" ];
  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [ pkgs.stdenv.cc.cc.lib ];
  doInstallCheck = true;
  nativeInstallCheckInputs = [ pkgs.python3 ];
  installCheckPhase = ''
    runHook preInstallCheck
    BEESLY_EXECUTABLE="$out/bin/beesly" python3 tests/touch_ui.py
    runHook postInstallCheck
  '';
  meta = {
    description = "Cisco phone XML services with Home Assistant and FreePBX integration";
    homepage = "https://github.com/maeve-oake/beesly";
    mainProgram = "beesly";
    platforms = pkgs.lib.platforms.linux;
  };
}
