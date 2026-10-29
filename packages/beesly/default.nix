{ pkgs, pname }:
pkgs.buildDotnetModule {
  inherit pname;
  version = "0-unstable-2026-10-08";
  src = pkgs.fetchFromGitHub {
    owner = "maeve-oake";
    repo = "beesly";
    rev = "67101892b8a5388c03f9407d6fc513f94b9c7359";
    hash = "sha256-nE3fI5VgrlA+wsAPPSjyY3htgiaJ5ShLcypFHRGMPF4=";
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
