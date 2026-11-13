if [[ $# != 1 || $1 == --help || $1 == -h ]]; then
  echo "Usage: update-thing <package-or-full-flake-attribute>"
  if [[ $# == 1 && ( $1 == --help || $1 == -h ) ]]; then
    exit 0
  fi
  exit 2
fi

export NIX_PATH=nixpkgs=channel:nixos-unstable

attribute=$1
case "$attribute" in
  packages.* | legacyPackages.*) ;;
  *)
    systems=$(nix eval --json --no-write-lock-file \
      --apply 'systems: builtins.mapAttrs (_: pkgs: builtins.attrNames pkgs) systems' \
      .#packages)
    system=$(jq -r --arg name "$attribute" --arg preferred "$runner_system" '
      to_entries
      | map(select(.value | index($name)))
      | sort_by([.key != $preferred, .key])
      | .[0].key // empty
    ' <<< "$systems")
    if [[ -z $system ]]; then
      echo "Package not found: $attribute" >&2
      exit 1
    fi
    attribute="packages.$system.$attribute"
    ;;
esac

metadata=$(nix eval --json --no-write-lock-file \
  --apply 'pkg:
    let
      passthru = pkg.passthru or { };
      script = passthru.updateScript or null;
      command = script.command or script;
      commands = if builtins.isList command then command else [ command ];
    in
    if !(passthru ? updateScript) then
      { mode = "nix-update"; args = [ ]; }
    else if script == null then
      { mode = "skip"; }
    else if commands != [ ]
      && builtins.baseNameOf (toString (builtins.head commands)) == "nix-update"
    then
      { mode = "nix-update"; args = map toString (builtins.tail commands); }
    else
      {
        mode = "custom";
        command = map toString commands;
        context = builtins.getContext (builtins.concatStringsSep "" (map toString commands));
        name = pkg.name;
        pname = pkg.pname or pkg.name;
        oldVersion = pkg.version or "";
      }' \
  ".#$attribute")

export UPDATE_NIX_ATTR_PATH="$attribute"

case "$(jq -r .mode <<< "$metadata")" in
  skip)
    echo "Skipping $attribute: updateScript is null"
    ;;
  nix-update)
    mapfile -d '' -t args < <(jq -j '.args[] | ., "\u0000"' <<< "$metadata")
    exec nix-update --flake "${args[@]}"
    ;;
  custom)
    mapfile -d '' -t dependencies < <(
      jq -j '
        .context | to_entries[]
        | if .value.outputs then
            .key + "^" + (.value.outputs | join(","))
          elif .value.allOutputs then
            .key + "^*"
          else empty end
        | ., "\u0000"
      ' <<< "$metadata"
    )
    if (( ${#dependencies[@]} )); then
      nix build --no-link "${dependencies[@]}"
    fi
    source_root=$(nix flake metadata --json --no-write-lock-file . | jq -r .path)
    mapfile -d '' -t command < <(
      jq -j --arg source "$source_root/" --arg checkout "$PWD/" '
        .command[]
        | if startswith($source)
          then $checkout + ltrimstr($source)
          else .
          end
        | ., "\u0000"
      ' <<< "$metadata"
    )
    UPDATE_NIX_NAME=$(jq -r .name <<< "$metadata")
    UPDATE_NIX_PNAME=$(jq -r .pname <<< "$metadata")
    UPDATE_NIX_OLD_VERSION=$(jq -r .oldVersion <<< "$metadata")
    export UPDATE_NIX_NAME UPDATE_NIX_PNAME UPDATE_NIX_OLD_VERSION
    exec "${command[@]}"
    ;;
esac
