{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.jovian.game-stream;

  # jovian.decky-loader.plugins comes from the decky-plugins module, not jovian itself. every host imports this
  # module, and setting an undeclared option fails evaluation even under mkIf, so it's only set where it exists
  hasDeckyPlugins = options ? jovian.decky-loader.plugins;

  rtmp = cfg.rtmpPort != null;
  hls = cfg.hlsPort != null;
  webrtc = cfg.webrtcHttpPort != null && cfg.webrtcPort != null;

  srtPort = 8890; # local publish only, from the capture to mediamtx
  audioBitrate = 192; # kbps

  # json is valid yaml; mediamtx rejects the %YAML directive formats.yaml emits
  mediamtxConfig = (pkgs.formats.json { }).generate "mediamtx.yml" (
    {
      logLevel = "info";
      api = false;
      metrics = false;
      pprof = false;
      playback = false;
      rtsp = false;
      moq = false;
      # give the capture time to come up before dropping the publisher
      readTimeout = "30s";

      srt = true;
      srtAddress = ":${toString srtPort}";

      # mediamtx enables these by default, so disabled ones are spelled out
      inherit rtmp hls webrtc;

      authInternalUsers = [
        {
          user = "any";
          ips = [
            "127.0.0.1"
            "::1"
          ];
          permissions = [ { action = "publish"; } ];
        }
        {
          user = "any";
          permissions = [
            { action = "read"; }
            { action = "playback"; }
          ];
        }
      ];

      paths.live = { };
    }
    // lib.optionalAttrs rtmp {
      rtmpAddress = ":${toString cfg.rtmpPort}";
    }
    // lib.optionalAttrs hls {
      hlsAddress = ":${toString cfg.hlsPort}";
      # only remux while someone is watching; first hls viewer waits a few seconds
      hlsAlwaysRemux = false;
    }
    // lib.optionalAttrs webrtc {
      webrtcAddress = ":${toString cfg.webrtcHttpPort}";
      webrtcLocalUDPAddress = ":${toString cfg.webrtcPort}";
      webrtcLocalTCPAddress = ":${toString cfg.webrtcPort}";
      webrtcAdditionalHosts = lib.optional (cfg.webrtcPublicHost != null) cfg.webrtcPublicHost;
    }
  );

  # captures the screen straight from kms (via the gsr-kms-server setcap wrapper) instead of
  # gamescope's pipewire stream, which only ever delivered the first frame
  capture = pkgs.writeShellApplication {
    name = "game-stream-capture";
    runtimeInputs = [ pkgs.gpu-screen-recorder ];
    text = ''
      # gsr's wayland mode lists monitors from drm; in x11 mode it would list gamescope's xwayland
      # outputs, which don't match any kms connector
      export WAYLAND_DISPLAY=''${GAMESCOPE_WAYLAND_DISPLAY:-gamescope-0}
      unset DISPLAY

      # set by the decky plugin via ~/.config/game-stream.env
      width=''${WIDTH:-3840}
      height=''${HEIGHT:-2160}
      fps=''${FPS:-60}
      # ~0.05 bits per pixel: 4k60 = 25 Mbps, 1080p60 = 6 Mbps
      bitrate=$((width * height * fps / 20000))
      if [ "$bitrate" -lt 6000 ]; then bitrate=6000; fi

      # h264 + opus in mpeg-ts over srt (20ms latency, it's localhost); mediamtx serves it as webrtc,
      # hls and rtmp alike. not whip: ffmpeg's whip muxer can't read mediamtx's http responses
      exec gpu-screen-recorder \
        -w screen -s "''${width}x''${height}" -f "$fps" -v no \
        -k h264 -bm cbr -q "$bitrate" -keyint 2 \
        -a default_output -ac opus -ab ${toString audioBitrate} \
        -c mpegts -o "srt://127.0.0.1:${toString srtPort}?streamid=publish:live&latency=20000&pkt_size=1316"
    '';
  };

  port =
    description: default:
    lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      inherit default;
      description = "${description} Null disables it.";
    };
in
{
  options.jovian.game-stream = {
    enable = lib.mkEnableOption "streaming the gamescope session, toggled from the decky-game-stream Quick Access plugin";

    rtmpPort = port "RTMP port, serving rtmp://host:port/live." 1935;
    hlsPort = port "HLS port, serving a web player at http://host:port/live/ (about 1s+ of delay)." 8888;
    webrtcHttpPort = port "WebRTC HTTP port, serving the low latency web player at http://host:port/live/. Set together with webrtcPort." 8889;
    webrtcPort = port "WebRTC media port (UDP and TCP), which viewers must be able to reach. Set together with webrtcHttpPort." 8189;

    webrtcPublicHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "stream.example.com";
      description = "Public IP or hostname viewers reach the host on, advertised as a WebRTC ICE candidate.";
    };
  };

  config = lib.mkIf cfg.enable (
    {
      assertions = [
        {
          assertion = (cfg.webrtcHttpPort == null) == (cfg.webrtcPort == null);
          message = "jovian.game-stream: set both webrtcHttpPort and webrtcPort, or neither to disable WebRTC.";
        }
        {
          assertion = hasDeckyPlugins;
          message = "jovian.game-stream: needs the decky-plugins module (jovian.decky-loader.plugins) to install the decky-game-stream toggle.";
        }
        {
          assertion = rtmp || hls || webrtc;
          message = "jovian.game-stream: RTMP, HLS and WebRTC are all disabled, so there'd be no way to watch the stream.";
        }
      ];
      # setcap wrapper for gsr-kms-server, needed for kms screen capture
      programs.gpu-screen-recorder.enable = true;

      # started and stopped by the decky plugin
      systemd.user.targets.game-stream = {
        description = "Game stream";
        partOf = [ "gamescope-session.target" ];
        after = [ "gamescope-session.target" ];
        wants = [
          "game-stream-server.service"
          "game-stream-capture.service"
        ];
      };

      systemd.user.services.game-stream-server = {
        description = "Game stream server (mediamtx)";
        partOf = [ "game-stream.target" ];
        serviceConfig = {
          ExecStart = "${lib.getExe pkgs.mediamtx} ${mediamtxConfig}";
          Restart = "on-failure";
        };
      };

      systemd.user.services.game-stream-capture = {
        description = "Game stream capture (screen + desktop audio)";
        partOf = [ "game-stream.target" ];
        after = [ "game-stream-server.service" ];
        # retry forever, e.g. if the capture dies on a display mode change
        unitConfig.StartLimitIntervalSec = 0;
        serviceConfig = {
          EnvironmentFile = [
            "%t/gamescope-environment" # GAMESCOPE_WAYLAND_DISPLAY
            "-%h/.config/game-stream.env"
          ];
          ExecStart = lib.getExe capture;
          Restart = "always";
          RestartSec = 5;
        };
      };
    }
    // lib.optionalAttrs hasDeckyPlugins {
      jovian.decky-loader.plugins = [ pkgs.decky-game-stream ];
    }
  );
}
