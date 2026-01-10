{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.netbird.simple;
in
{
  options.services.netbird.simple =
    let
      inherit (lib) mkEnableOption mkOption types;
    in
    {
      enable = mkEnableOption "simple NetBird setup";
      managementUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "NetBird management API URL.";
        example = "https://netbird.example.com";
      };
      adminUrl = mkOption {
        type = types.nullOr types.str;
        default = cfg.managementUrl;
        description = "NetBird admin dashboard URL.";
        example = "https://netbird.example.com";
      };
      setupKeyFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to the file containing the setup key.";
        example = "/run/secret/netbird-key";
      };
    };

  config = lib.mkIf cfg.enable {
    services.netbird.clients.default = {
      environment =
        lib.optionalAttrs (cfg.managementUrl != null) {
          NB_MANAGEMENT_URL = cfg.managementUrl;
        }
        // lib.optionalAttrs (cfg.adminUrl != null) {
          NB_ADMIN_URL = cfg.adminUrl;
        }
        // lib.optionalAttrs (cfg.setupKeyFile != null) {
          NB_SETUP_KEY_FILE = cfg.setupKeyFile;
        };
      name = "netbird";
      interface = "nb0";
      port = 51820;
      logLevel = "warn";
    };

    systemd.services.netbird.postStart = lib.optionalString (cfg.setupKeyFile != null) ''
      set -x
      nb='${lib.getExe config.services.netbird.clients.default.wrapper}'

      fetch_status() {
        status="$("$nb" status 2>&1)"
      }

      print_status() {
        test -n "$status" || refresh_status
        cat <<EOF
      $status
      EOF
      }

      refresh_status() {
        fetch_status
        print_status
      }

      main() {
        print_status | ${lib.getExe pkgs.gnused} 's/^/STATUS:INIT: /g'
        while refresh_status | grep --quiet 'Disconnected' ; do
          sleep 1
        done
        print_status | ${lib.getExe pkgs.gnused} 's/^/STATUS:WAIT: /g'

        if print_status | grep --quiet 'NeedsLogin' ; then
          "$nb" up
        fi
      }

      main "$@"
    '';

    disko.simple.impermanence.persist.directories = [
      "/var/lib/netbird"
    ];
  };
}
