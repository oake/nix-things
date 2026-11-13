{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    stdenvNoCC
    fetchFromGitHub
    lib
    ;
in
stdenvNoCC.mkDerivation {
  inherit pname;
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "maeve-oake";
    repo = "plymouth-1975-theme";
    rev = "fc88d5b8e583dc8c40662e7e7a19ee77dbef6d88";
    hash = "sha256-OT4GwqDwQgF0kVMKPN0kSQoRHAuTAcvA1nh4PTGBaK8=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/plymouth/themes/1975
    cp * $out/share/plymouth/themes/1975
    find $out/share/plymouth/themes/ -name \*.plymouth -exec sed -i "s@\/usr\/@$out\/@" {} \;

    runHook postInstall
  '';

  passthru.updateScript = pkgs.nix-update-script {
    extraArgs = [
      "--version=branch"
    ];
  };

  meta = {
    description = "The 1975 Plymouth boot splash";
    platforms = lib.platforms.linux;
  };
}
