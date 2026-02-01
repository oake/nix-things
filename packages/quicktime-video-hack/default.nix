{
  pkgs,
  pname,
}:
let
  inherit (pkgs)
    lib
    buildGoModule
    fetchFromGitHub
    ;
in
buildGoModule {
  inherit pname;
  version = "0.6-beta";

  src = fetchFromGitHub {
    owner = "danielpaulus";
    repo = "quicktime_video_hack";
    rev = "d81396e2e7758d98c2a594853b64f98b54a8a871";
    hash = "sha256-21gzqtsB52ACtFaeBV/DEi2oBlLWrJLm2+oNVaubofI=";
  };

  vendorHash = "sha256-C867AaDeosCgEg2UZXIzxBd2y/6lXGsO3ZMZ11MZHTo=";

  nativeBuildInputs = with pkgs; [
    pkg-config
    makeWrapper
  ];

  buildInputs = with pkgs; [
    glib
    libusb1
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
  ];

  ldflags = [
    "-s"
    "-w"
  ];

  postInstall =
    let
      gstPluginPath = lib.makeSearchPath "lib/gstreamer-1.0" [
        pkgs.gst_all_1.gstreamer.out
        pkgs.gst_all_1.gst-plugins-base
        pkgs.gst_all_1.gst-plugins-good
        pkgs.gst_all_1.gst-plugins-bad
        pkgs.gst_all_1.gst-plugins-ugly
        pkgs.gst_all_1.gst-libav
      ];
      gstPluginScanner = "${pkgs.gst_all_1.gstreamer.out}/libexec/gstreamer-1.0/gst-plugin-scanner";
    in
    ''
      if [ -e "$out/bin/quicktime_video_hack" ]; then
        mv "$out/bin/quicktime_video_hack" "$out/bin/qvh"
      fi
      wrapProgram "$out/bin/qvh" \
        --set-default GST_PLUGIN_SYSTEM_PATH_1_0 "${gstPluginPath}" \
        --set-default GST_PLUGIN_SCANNER "${gstPluginScanner}" \
        --set-default GST_PLUGIN_SCANNER_1_0 "${gstPluginScanner}"
    '';

  meta = {
    homepage = "https://github.com/danielpaulus/quicktime_video_hack";
    description = "Record iOS device audio and video";
    license = with lib.licenses; [ mit ];
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    mainProgram = "qvh";
  };
}
