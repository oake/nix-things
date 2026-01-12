{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    stdenvNoCC
    lib
    fetchurl
    _7zz
    makeWrapper
    nix-update-script
    ;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname;
  version = "1.0.5";

  src = fetchurl {
    url = "https://github.com/ryzenixx/proxmoxbar-macos/releases/download/v${finalAttrs.version}/ProxmoxBar.dmg";
    hash = "sha256-+sTFvvrKHu1GxTSN6mhIupudZpR+oEnufKxstUhHt+k=";
  };
  sourceRoot = ".";

  nativeBuildInputs = [
    _7zz
    makeWrapper
  ];

  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall

    mkdir -p $out/{Applications,bin}
    mv ./ProxmoxBar\ Installer/ProxmoxBar.app $out/Applications
    makeWrapper $out/Applications/ProxmoxBar.app/Contents/MacOS/ProxmoxBar $out/bin/${pname}

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "A native macOS menu bar app to manage Proxmox Resources";
    longDescription = ''
      ProxmoxBar lives in your menu bar, giving you instant control over your Proxmox infrastructure.
      Monitor your nodes, manage VMs and LXC containers, and handle power actions in style.
    '';
    homepage = "https://github.com/ryzenixx/proxmoxbar-macos";
    downloadPage = "https://github.com/ryzenixx/proxmoxbar-macos/releases";
    changelog = "https://github.com/ryzenixx/proxmoxbar-macos/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
    ];
    platforms = [
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = pname;
  };
})
