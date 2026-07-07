{
  pkgs,
  pname,
  kernel,
  kernelModuleMakeFlags,
}:
let
  inherit (pkgs)
    lib
    stdenv
    fetchFromGitHub
    ;
  version = "0.1.0";
in

stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "anna-oake";
    repo = "leds-valve-shim";
    tag = "v${version}";
    hash = "sha256-GLaDOSBXsYL+LRQ9MmBa4s3YtkblVJA9R+3xaoNyM1Q=";
  };

  hardeningDisable = [ "pic" ];
  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernelModuleMakeFlags ++ [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall

    install -D -m 0644 leds-valve-shim.ko $out/lib/modules/${kernel.modDirVersion}/extra/leds-valve-shim.ko

    runHook postInstall
  '';

  meta = {
    description = "Steam-compatible Valve LED class shim driver";
    homepage = "https://github.com/anna-oake/leds-valve-shim";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
}
