{ pkgs, pname }:
let
  version = "0.1.0";
  inherit (pkgs) lib;
  webrtc = pkgs.fetchzip {
    url = "https://github.com/livekit/rust-sdks/releases/download/webrtc-51ef663/webrtc-linux-x64-release.zip";
    hash = "sha256-Cho7WsJBhkUs0ZCSXwj4zCXIn7NYNHbHo4UGVU/0jwY=";
  };
in
pkgs.rustPlatform.buildRustPackage {
  inherit pname version;

  src = pkgs.fetchFromGitHub {
    owner = "oake";
    repo = "miaow-linux";
    rev = "v${version}";
    hash = "sha256-P5krnvzULmFCcNKmcADvfDAbSZshfFPakfYF5q/8S3Q=";
  };

  cargoHash = "sha256-3X4UUayEe8yCSS7dyYIidQf1eyGNdbvMOslfi//049w=";

  nativeBuildInputs = with pkgs; [
    pkg-config
    wrapGAppsHook4
    glib
    clang
    lld
  ];

  buildInputs = with pkgs; [
    gtk4
    libadwaita
    pipewire
    libpulseaudio
    alsa-lib
    libGL
    libjpeg_turbo
    libva
    libdrm
    udev
    cudaPackages.cuda_cudart
  ];

  LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
  LK_CUSTOM_WEBRTC = webrtc;
  CUDA_HOME = "${pkgs.cudaPackages.cuda_cudart}";

  preFixup = ''
    # WebRTC loads these libraries with dlopen.
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          pkgs.libpulseaudio
          pkgs.alsa-lib
          pkgs.pipewire
          pkgs.libva
          pkgs.libdrm
        ]
      }
      --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib
    )
  '';

  postInstall = ''
    install -Dm644 data/ke.oa.miaow.desktop \
      $out/share/applications/ke.oa.miaow.desktop
    install -Dm644 data/ke.oa.miaow.gschema.xml \
      $out/share/glib-2.0/schemas/ke.oa.miaow.gschema.xml
    install -Dm644 data/ke.oa.miaow.svg \
      $out/share/icons/hicolor/scalable/apps/ke.oa.miaow.svg
    install -d $out/share/gnome-shell/extensions/miaow@oa.ke
    install -m644 gnome-shell-extension/extension.js \
      gnome-shell-extension/metadata.json \
      $out/share/gnome-shell/extensions/miaow@oa.ke/
    install -Dm644 data/ke.oa.miaow.gschema.xml \
      $out/share/gnome-shell/extensions/miaow@oa.ke/schemas/ke.oa.miaow.gschema.xml
    glib-compile-schemas $out/share/gnome-shell/extensions/miaow@oa.ke/schemas
    glib-compile-schemas $out/share/glib-2.0/schemas
  '';

  passthru.extensionUuid = "miaow@oa.ke";

  meta = {
    description = "Native GNOME one-to-one room-call client";
    homepage = "https://github.com/oake/miaow-linux";
    license = lib.licenses.mit;
    mainProgram = "miaow";
    platforms = [ "x86_64-linux" ];
  };
}
