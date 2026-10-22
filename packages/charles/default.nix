{ pkgs, pname }:
let
  inherit (pkgs)
    lib
    stdenvNoCC
    fetchurl
    makeWrapper
    makeDesktopItem
    jdk25
    undmg
    ;
  isDarwin = stdenvNoCC.hostPlatform.isDarwin;
  desktopItem = makeDesktopItem {
    categories = [
      "Network"
      "Development"
      "WebDevelopment"
      "Java"
    ];
    desktopName = "Charles";
    exec = "charles %F";
    genericName = "Web Debugging Proxy";
    icon = "charles-proxy5";
    mimeTypes = [
      "application/x-charles-savedsession"
      "application/x-charles-savedsession+xml"
      "application/x-charles-savedsession+json"
      "application/har+json"
      "application/vnd.tcpdump.pcap"
      "application/x-charles-trace"
    ];
    name = "Charles";
    startupNotify = true;
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname;
  version = "5.2.2";

  # macOS needs the native app bundle (JNI libs, VAqua, macOS main class);
  # elsewhere the jars are arch-independent, so the x86_64 tarball serves all.
  src = fetchurl {
    url = "https://www.charlesproxy.com/assets/release/${finalAttrs.version}/charles-proxy-${finalAttrs.version}${
      if isDarwin then ".dmg" else "_x86_64.tar.gz"
    }";
    hash =
      if isDarwin then
        "sha256-Vg4Qwxuy5oC5udrfD7ZkUCib0itKaLysWhOozOUtnwU="
      else
        "sha256-oj6yCojocVHUzia8Hy+D36r8OB+cESUYHfAqMIniUok=";
    curlOptsList = [
      "--user-agent"
      "Mozilla/5.0"
    ];
  };

  sourceRoot = if isDarwin then "Charles.app" else null;
  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals isDarwin [ undmg ];
  dontConfigure = true;
  dontBuild = true;
  # Fixup would rewrite the signed Mach-O binaries (launcher, JNI libs, bundled JDK).
  dontFixup = isDarwin;

  installPhase = ''
    runHook preInstall

    ${
      if isDarwin then
        ''
          mkdir -p "$out/Applications/Charles.app" "$out/bin"
          cp -R . "$out/Applications/Charles.app"
          makeWrapper "$out/Applications/Charles.app/Contents/MacOS/Charles" "$out/bin/charles"
        ''
      else
        ''
          makeWrapper ${jdk25}/bin/java "$out/bin/charles" \
            --add-flags "-Xmx1024M -Dcharles.config='~/.charles.config' -XX:+UseZGC -Djava.library.path='$out/share/java' --add-opens java.base/sun.security.ssl=com.charlesproxy --add-opens java.desktop/java.awt.event=com.charlesproxy --add-opens java.base/java.io=com.charlesproxy --add-modules com.jthemedetector,com.formdev.flatlaf --module-path '$out/share/java' -m com.charlesproxy"

          for fn in lib/*.jar; do
            install -D -m644 "$fn" "$out/share/java/$(basename "$fn")"
          done

          mkdir -p "$out/share/applications"
          ln -s ${desktopItem}/share/applications/* "$out/share/applications/"

          mkdir -p "$out/share/icons"
          cp -r icon "$out/share/icons/hicolor"
          if [ -d etc/mime ]; then
            mkdir -p "$out/share/mime/packages"
            cp etc/mime/*.xml "$out/share/mime/packages/"
          fi
        ''
    }

    runHook postInstall
  '';

  meta = {
    description = "Web Debugging Proxy";
    homepage = "https://www.charlesproxy.com/";
    changelog = "https://www.charlesproxy.com/documentation/version-history/";
    maintainers = with lib.maintainers; [
      kalbasit
      kashw2
      Misaka13514
    ];
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    license = lib.licenses.unfree;
    platforms = lib.platforms.darwin ++ [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "charles";
  };
})
