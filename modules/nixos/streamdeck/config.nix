{
  lib,
  config,
  pkgs,
}:
let
  inherit (lib) mkOption mkEnableOption types;

  inherit (import ./helpers.nix { inherit lib allAttributes; })
    mkColorOption
    mkAttributesOption
    transformPage
    cleanAttrs
    renameKeys
    ;

  renameMap = {
    color = "rgba";
    deviceType = "device";

    captionBorder = "caption_border";
    captionColor = "caption_color";
    captionFont = "caption_font";
    captionFontSize = "caption_font_size";
    captionPosition = "caption_position";
    defaultBrightness = "default_brightness";
    defaultPage = "default_page";
    displayOffTime = "display_off_time";
    longPressDuration = "long_press_duration";
    renderFont = "render_font";
    fontSize = "font_size";
    backgroundColor = "background_color";
    keyPress = "key_press";
    toggleDisplay = "toggle_display";
    keyCodes = "key_codes";
    modAlt = "mod_alt";
    modCtrl = "mod_ctrl";
    modShift = "mod_shift";
    modMeta = "mod_meta";
    changeVolume = "change_volume";
    setVolume = "set_volume";
  };

  allAttributes = {
    caption = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "Hello World";
      description = ''
        Caption to display on the key.
      '';
    };
    color = mkColorOption "Color";
    fontSize = mkOption {
      type = types.nullOr types.float;
      default = null;
      example = 10.0;
      description = "Font size to use.";
    };
    interval = mkOption {
      type = types.nullOr types.ints.unsigned;
      default = null;
      example = 5;
      description = "Display refresh interval in seconds.";
    };
    border = mkOption {
      type = types.nullOr types.ints.unsigned;
      default = null;
      example = 5;
      description = "Border width in pixels.";
    };
    backgroundColor = mkColorOption "Background color";
    image = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/home/myuser/.config/streamdeck/images/date_bg.png";
      description = "Path to an image file to display on the key.";
    };
    command = mkOption {
      type = types.nullOr (types.listOf types.str);
      default = null;
      example = [
        "/usr/bin/date"
        "+%H:%M:%S"
      ];
      description = "Command to execute when the key is pressed or to fetch data to display.";
    };
    env = mkOption {
      type = types.nullOr (types.attrsOf types.str);
      default = null;
      example = {
        MYVAR = "myvalue";
      };
      description = "Environment variables to set when executing the command.";
    };
    url = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://example.com/myimage.png";
      description = "URL of the image to display on the key.";
    };
    path = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/path/to/image.png";
      description = "Path to an image file to display on the key.";
    };
    deviceType = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "input";
      description = "Type of the device to control (input / sink / source).";
    };
    match = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "^Spotify";
      description = "Regular expression to match the name of the audio device.";
    };
    text = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "Hello World";
      description = "Text to display on the key.";
    };
    attachStderr = mkEnableOption "attach to STDERR of process";
    attachStdout = mkEnableOption "attach to STDOUT of process";
    wait = mkEnableOption "wait for command to finish";
    delay = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "1s";
      description = "Time to wait between key presses.";
    };
    keyCodes = mkOption {
      type = types.listOf types.int;
      example = [
        35
        18
        38
        38
        24
      ];
      description = "Key codes to press in order.";
    };
    modAlt = mkEnableOption "`alt` during key presses";
    modCtrl = mkEnableOption "`ctrl` during key presses";
    modShift = mkEnableOption "`shift` during key presses";
    modMeta = mkEnableOption "`meta` (also known as `mod4` or `win`) during key presses";
    name = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "second";
      description = "Name of the target page as defined in config.";
    };
    relative = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 1;
      description = "Move back in the page-history for N steps.";
    };
    mute = mkOption {
      type = types.nullOr (
        types.enum [
          "toggle"
          "true"
          "false"
        ]
      );
      default = null;
      example = "toggle";
      description = "State of mute to set.";
    };
    changeVolume = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = -5;
      description = "Adjustment of the volume to current volume (percent 0-150).";
    };
    setVolume = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 22;
      description = "Adjustment of the volume in absolute percentage (0-150).";
    };
  };

  keyType = types.submodule {
    options = {
      display = mkOption {
        type = types.submodule {
          options = {
            color = mkAttributesOption "This display will show a uniform color on the icon." [ "color" ];
            exec =
              mkAttributesOption "This display will execute a command and display the result on the icon."
                [
                  "backgroundColor"
                  "border"
                  "caption"
                  "color"
                  "command"
                  "env"
                  "fontSize"
                  "image"
                  "interval"
                ];
            image = mkAttributesOption "This display will load and display an image." [
              "caption"
              "path"
              "url"
            ];
            pulsevolume =
              mkAttributesOption "This action supports displaying device state / volume for PulseAudio devices."
                [
                  "border"
                  "caption"
                  "color"
                  "device"
                  "match"
                  "fontSize"
                  "interval"
                ];
            text = mkAttributesOption "This display will display a simple text styable through attributes." [
              "backgroundColor"
              "border"
              "caption"
              "color"
              "fontSize"
              "image"
              "interval"
              "text"
            ];
          };
        };
        description = ''
          What to display on the key.
        '';
      };
      actions = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              exec =
                mkAttributesOption "This action will call any command on the system specified and detach from it."
                  [
                    "attachStderr"
                    "attachStdout"
                    "command"
                    "env"
                    "wait"
                  ];
              keyPress =
                mkAttributesOption "This action will emulate key-presses through the uinput kernel API."
                  [
                    "delay"
                    "keyCodes"
                    "modAlt"
                    "modCtrl"
                    "modShift"
                    "modMeta"
                  ];
              page = mkAttributesOption "This action will switch to another page using its name." [
                "name"
                "relative"
              ];
              pulsevolume =
                mkAttributesOption "This action supports volume and mute control for PulseAudio setups."
                  [
                    "device"
                    "match"
                    "mute"
                    "changeVolume"
                    "setVolume"
                  ];
              toggleDisplay =
                mkAttributesOption
                  "This action will toggle the display brightness between 0 and the previous value."
                  [ ];
            };
          }
        );
        default = [ ];
        description = ''
          List of actions to perform when a key is pressed.
        '';
      };
    };
  };
in
{
  mkConfigOption = mkOption {
    description = "layout of your Stream Deck and more";
    default = { };
    type = types.submodule {
      options = {
        captionBorder = mkOption {
          type = types.nullOr types.ints.positive;
          default = null;
          example = 5;
          description = ''
            How much border to give captions in px. No border if empty.
          '';
        };
        captionColor = mkColorOption "Caption color, 4 RGBA values.";
        captionFont = mkOption {
          type = types.nullOr types.path;
          default = null;
          example = "/usr/share/fonts/TTF/Roboto-Bold.ttf";
          description = ''
            Path to the TTF font to use when rendering captions on buttons. renderFont is used, if empty.
          '';
        };
        captionFontSize = mkOption {
          type = types.nullOr types.float;
          default = null;
          example = 10.0;
          description = "Font size to use on captions.";
        };
        captionPosition = mkOption {
          type = types.nullOr (
            types.enum [
              "bottom"
              "top"
            ]
          );
          default = null;
          example = "bottom";
          description = ''
            Where to place captions (bottom/top).
          '';
        };
        defaultBrightness = mkOption {
          type = types.nullOr (types.ints.between 0 100);
          default = null;
          example = 20;
          description = ''
            Brightness to set on start.
          '';
        };
        defaultPage = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "default";
          description = ''
            Page to display on start.
          '';
        };
        displayOffTime = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "5m";
          description = ''
            Time to display off. No timeout, if empty.
          '';
        };
        longPressDuration = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "1s";
          description = ''
            Duration of a long press. 500ms, if empty.
          '';
        };
        renderFont = mkOption {
          type = types.nullOr types.path;
          default = null;
          example = "/usr/share/fonts/TTF/Roboto-Regular.ttf";
          description = ''
            Path to the TTF font to use when rendering buttons with text.
          '';
        };
        pages = mkOption {
          type = types.attrsOf (
            types.submodule {
              options = {
                keys = mkOption {
                  type = types.attrsOf keyType;
                  default = { };
                  description = ''
                    Keys to display on this page.
                  '';
                };
                overlay = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  example = "otherpage";
                  description = ''
                    Overlay keys from the specified page over this page.
                  '';
                };
                underlay = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  example = "otherpage";
                  description = ''
                    Underlay keys from the specified page under this page.
                  '';
                };
              };
            }
          );
          example = {
            default = {
            };
          };
          description = ''
            Pages, according to the documentation: https://github.com/Luzifer/streamdeck/wiki#configuration
          '';
        };
      };
    };
  };

  mkConfig =
    let
      cfg = config.services.streamdeck.config;
    in
    renameKeys (cleanAttrs (
      cfg
      // {
        auto_reload = false;
        pages = lib.mapAttrs transformPage cfg.pages;
      }
    )) renameMap;

  fixConfig =
    name: input:
    pkgs.runCommand name
      {
        src = input;
        nativeBuildInputs = [ pkgs.yq-go ];
        preferLocalBuild = true;
      }
      ''
        yq eval "(.pages[].keys) |= (to_entries | map(.key |= tonumber) | from_entries)" "$src" > "$out"
      '';
}
