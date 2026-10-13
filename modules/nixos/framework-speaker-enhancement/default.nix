{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.framework.laptop13.speakerEnhancement;
  outputPrefix = builtins.head (builtins.match "(alsa_output\\.pci-.*)\\.[^.]*" cfg.rawDeviceName);
  speakerProfile = pkgs.runCommand "framework-speaker-profile" { } ''
    mixer=${config.services.pipewire.package}/share/alsa-card-profile/mixer
    mkdir -p "$out/paths"
    substitute "$mixer/profile-sets/default.conf" "$out/default.conf" \
      --replace-fail 'analog-output-speaker' 'framework-output-speaker'
    substitute "$mixer/paths/analog-output-speaker.conf" "$out/paths/framework-output-speaker.conf" \
      --replace-fail 'volume = merge' 'volume = zero' \
      --replace-fail '[Properties]' $'[Properties]\nport.type = speaker' \
      --replace-fail '.include analog-output.conf.common' \
        ".include $out/paths/framework-output.conf.common"
    substitute "$mixer/paths/analog-output.conf.common" "$out/paths/framework-output.conf.common" \
      --replace-fail 'volume = merge' 'volume = zero'
  '';
in
{
  options.hardware.framework.laptop13.speakerEnhancement = {
    enable = lib.mkEnableOption "speaker-only audio tuning for the classic Framework Laptop 13";

    rawDeviceName = lib.mkOption {
      type = lib.types.strMatching "alsa_output\\.pci-.*\\.[^.]+";
      default = config.hardware.framework.laptop13.audioEnhancement.rawDeviceName;
      defaultText = lib.literalExpression "config.hardware.framework.laptop13.audioEnhancement.rawDeviceName";
      description = ''
        An output node name identifying the built-in audio controller. Only its
        PCI identity is used; the active profile and speaker route are detected
        at runtime. Defaults to the identity provided by nixos-hardware.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.versionAtLeast config.services.pipewire.package.version "1.6.0";
        message = "Framework speaker enhancement requires PipeWire >= 1.6.0 (internal filter graphs).";
      }
      {
        assertion = lib.versionAtLeast config.services.pipewire.wireplumber.package.version "0.5.18";
        message = "Framework speaker enhancement requires WirePlumber >= 0.5.18.";
      }
      {
        assertion = config.services.pipewire.enable && config.services.pipewire.wireplumber.enable;
        message = "Framework speaker enhancement requires PipeWire and WirePlumber.";
      }
    ];

    systemd.user.services.wireplumber.environment.ACP_PATHS_DIR = lib.mkIf (
      !config.services.pipewire.systemWide
    ) "${speakerProfile}/paths";
    systemd.services.wireplumber.environment.ACP_PATHS_DIR =
      lib.mkIf config.services.pipewire.systemWide "${speakerProfile}/paths";

    services.pipewire = {
      enable = lib.mkDefault true;
      extraLv2Packages = with pkgs; [
        bankstown-lv2
        lsp-plugins
      ];

      wireplumber = {
        enable = lib.mkDefault true;
        extraScripts."framework/speaker-enhancement.lua" = builtins.readFile ./speaker-enhancement.lua;
        extraConfig."90-framework-speaker-enhancement" = {
          "framework-speaker-enhancement.graph" = import ./graph.nix { inherit lib; };
          "monitor.alsa.rules" = [
            {
              matches = [
                {
                  "device.name" = lib.replaceStrings [ "alsa_output." ] [ "alsa_card." ] outputPrefix;
                }
              ];
              actions.update-props = {
                "api.alsa.use-ucm" = false;
                "device.profile-set" = "${speakerProfile}/default.conf";
              };
            }
            {
              matches = [
                {
                  "node.name" = "~${lib.escapeRegex outputPrefix}\\..*";
                  "media.class" = "Audio/Sink";
                }
              ];
              actions.update-props = {
                "framework.speaker-enhancement" = true;
              };
            }
          ];
          "wireplumber.components" = [
            {
              name = "framework/speaker-enhancement.lua";
              type = "script/lua";
              provides = "custom.framework-speaker-enhancement";
            }
          ];
          "wireplumber.profiles".main."custom.framework-speaker-enhancement" = "required";
        };
      };
    };
  };
}
