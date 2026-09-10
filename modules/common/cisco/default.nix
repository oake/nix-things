{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.cisco;
  wallpaperDirectory = "Desktops/320x216x16";
  wallpaperFiles = lib.unique (
    builtins.filter (wallpaperFile: wallpaperFile != null) (
      lib.mapAttrsToList (_: device: device.wallpaperFile) cfg.devices
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
      pkgs.runCommand "cisco-7975g-http-root"
        {
          nativeBuildInputs = [ pkgs.imagemagick ];
        }
        ''
          mkdir -p "$out"
          cp -R ${cfg.firmware}/. "$out/"

          ${lib.concatMapStringsSep "\n" (name: ''
            mkdir -p "$out/${builtins.dirOf name}"
            ln -s ${pkgs.writeText (builtins.baseNameOf name) cfg.generatedConfigs.${name}} "$out/${name}"
          '') (builtins.attrNames cfg.generatedConfigs)}

          ${lib.optionalString (wallpaperFiles != [ ]) ''
            mkdir -p "$out/${wallpaperDirectory}"
          ''}
          ${lib.concatMapStringsSep "\n" (
            wallpaperFile:
            let
              filename = wallpaperFilename wallpaperFile;
            in
            ''
              image_info="$(magick identify -format '%m %wx%h' "${wallpaperFile}")"
              if [ "$image_info" != "PNG 320x216" ]; then
                echo "Cisco 7975G wallpaper must be a 320x216 PNG; ${wallpaperFile} is $image_info" >&2
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
                echo "Cisco 7975G ringtone must be 240-16080 bytes of µ-law PCM; ${file} is $bytes bytes" >&2
                exit 1
              fi
              if [ $((bytes % 240)) -ne 0 ]; then
                echo "Cisco 7975G ringtone size must be divisible by 240; ${file} is $bytes bytes" >&2
                exit 1
              fi
              cp "${file}" "$out/${filename}"
            ''
          ) ringtoneFiles}
        '';
    })
  ];
}
