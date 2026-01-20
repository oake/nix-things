{
  config,
  lib,
  ...
}:
let
  cfg = config.profiles.server.docker;
in
{
  options.profiles.server.docker.networks = lib.mkOption {
    type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
    default = { };
    description = ''
      Docker networks to manage declaratively.
      Each attribute name is the network name, and the value is an optional CIDR subnet.
      If the subnet is null, we do not enforce/compare subnet and we create the network
      without --subnet (Docker auto-assigns).
    '';
    example = {
      web = "172.16.0.0/22";
      internal = null;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.docker-networks = {
      description = "Ensure declaratively managed Docker networks are in sync";
      after = [ "docker.service" ];
      wants = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      restartIfChanged = true;

      serviceConfig = {
        Type = "oneshot";
      };

      path = [ config.virtualisation.docker.package ];

      script =
        let
          labelKey = "nix.managed-network";

          wantedInit = lib.concatStringsSep "\n" (
            map (n: ''
              wanted[${lib.escapeShellArg n}]=1
            '') (builtins.attrNames cfg.networks)
          );

          ensureCmds = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: subnet: ''
              ensure "${name}" "${subnet}"
            '') cfg.networks
          );
        in
        ''
          set -euo pipefail

          label_key=${lib.escapeShellArg labelKey}
          label_val="1"

          declare -A wanted=()
          ${wantedInit}

          ensure() {
            local name="$1"
            local want_subnet="$2"  # empty => not declared

            if docker network inspect "$name" >/dev/null 2>&1; then
              if [ -n "$want_subnet" ]; then
                cur_subnet="$(docker network inspect -f '{{with index .IPAM.Config 0}}{{.Subnet}}{{end}}' "$name")"
                if [ "$cur_subnet" != "$want_subnet" ]; then
                  docker network rm "$name"
                else
                  return 0
                fi
              else
                # subnet not declared: only ensure existence
                return 0
              fi
            fi

            args=(network create --driver bridge --label "$label_key=$label_val")
            [ -n "$want_subnet" ] && args+=(--subnet "$want_subnet")
            args+=("$name")
            docker "''${args[@]}"
          }

          # Create/update declared networks
          ${ensureCmds}

          # Delete managed networks that are no longer declared
          while IFS= read -r n; do
            [ -n "$n" ] || continue
            if [ -z "''${wanted["$n"]+x}" ]; then
              docker network rm "$n"
            fi
          done < <(docker network ls --filter "label=$label_key=$label_val" --format '{{.Name}}')
        '';
    };
  };
}
