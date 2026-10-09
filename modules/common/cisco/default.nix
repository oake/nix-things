{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.cisco;
  models = import ./models.nix;
  phoneFirmware = lib.unique (map (device: device.firmware) (builtins.attrValues cfg.devices));
  addOnFirmware = lib.unique (
    builtins.filter (firmware: firmware != null) (
      lib.concatMap (device: map (m: m.firmware) device.addOnModules) (builtins.attrValues cfg.devices)
    )
  );
  wallpaperFiles = lib.unique (
    builtins.filter (wallpaper: wallpaper.wallpaperFile != null) (
      lib.mapAttrsToList (_: device: {
        inherit (device) deviceModel wallpaperFile;
      }) cfg.devices
    )
  );
  shortFileHash = file: builtins.substring 0 8 (builtins.hashFile "sha256" file);
  wallpaperFilename = wallpaperFile: "w-${shortFileHash wallpaperFile}.png";
  ringtoneFilename = file: "r-${shortFileHash file}.raw";
  ringtoneFiles = lib.unique (builtins.attrValues cfg.ringtones);
  python = pkgs.python3.withPackages (ps: [ ps.tftpy ]);
  serveBin = pkgs.writeScriptBin "cisco-serve" ''
    #!${python}/bin/python3
    ${builtins.readFile ./serve.py}
  '';
in
{
  imports = [ ./options.nix ];

  config = lib.mkMerge [
    { services.cisco.serveBin = serveBin; }
    (lib.mkIf cfg.enable {
      services.cisco.serverRoot =
        pkgs.runCommand "cisco-http-root"
          {
            nativeBuildInputs = [ pkgs.imagemagick ];
          }
          ''
            mkdir -p "$out"
            ${lib.concatMapStringsSep "\n" (firmware: ''
              cp -R ${firmware}/. "$out/"
            '') (lib.unique (phoneFirmware ++ addOnFirmware))}

            ${lib.concatMapStringsSep "\n" (name: ''
              mkdir -p "$out/${builtins.dirOf name}"
              ln -s ${
                pkgs.writeText "cisco-config-${
                  builtins.substring 0 8 (builtins.hashString "sha256" name)
                }" cfg.generatedConfigs.${name}
              } "$out/"${lib.escapeShellArg name}
            '') (builtins.attrNames cfg.generatedConfigs)}

            ${lib.concatMapStringsSep "\n" (
              wallpaper:
              let
                inherit (wallpaper) wallpaperFile;
                model = models.${wallpaper.deviceModel};
                inherit (model) wallpaperDirectory wallpaperSize;
                filename = wallpaperFilename wallpaperFile;
              in
              ''
                mkdir -p "$out/${wallpaperDirectory}"
                image_info="$(magick identify -format '%m %wx%h' "${wallpaperFile}")"
                if [ "$image_info" != "PNG ${wallpaperSize}" ]; then
                  echo "Cisco phone wallpaper must be a ${wallpaperSize} PNG; ${wallpaperFile} is $image_info" >&2
                  exit 1
                fi
                cp "${wallpaperFile}" "$out/${wallpaperDirectory}/${filename}"
                magick "${wallpaperFile}" -resize '80x53!' "$out/${wallpaperDirectory}/TN-${filename}"
              ''
            ) wallpaperFiles}

            ${lib.concatMapStringsSep "\n" (
              file:
              let
                filename = ringtoneFilename file;
              in
              ''
                bytes="$(wc -c < "${file}" | tr -d ' ')"
                if [ "$bytes" -lt 240 ] || [ "$bytes" -gt 16080 ]; then
                  echo "Cisco phone ringtone must be 240-16080 bytes of µ-law PCM; ${file} is $bytes bytes" >&2
                  exit 1
                fi
                if [ $((bytes % 240)) -ne 0 ]; then
                  echo "Cisco phone ringtone size must be divisible by 240; ${file} is $bytes bytes" >&2
                  exit 1
                fi
                cp "${file}" "$out/${filename}"
              ''
            ) ringtoneFiles}
          '';
    })
  ];
}
