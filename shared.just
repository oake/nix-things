# generate a keypair, rekey all secrets
[group('deployment')]
@bootstrap host: _add
  echo "Loading the bootstrap script..."
  nix run .#bootstrap-{{host}}

# install with nixos-anywhere or LXC in PVE
[group('deployment')]
@install host build="local": _add
  if [[ "{{host}}" == lxc-* ]]; then \
    just _install-lxc {{host}}; \
  else \
    just _install-anywhere {{host}} {{build}}; \
  fi

@_install-lxc host:
  echo "Loading the install script..."
  nix run .#install-{{host}}

@_install-anywhere host build:
  test -d .bootstrap/extra && [ "$(ls -A .bootstrap/extra)" ] \
    || { echo "Can't find the keypair. Did you bootstrap?"; exit 1; }

  nix run nixos-anywhere -- \
        --extra-files '.bootstrap/extra' \
        --build-on '{{build}}' \
        --flake '.#{{host}}' \
        root@{{host}}.{{landomain}}

# use deploy-rs to update existing hosts
[group('deployment')]
deploy *args: _add
  #!/usr/bin/env sh
  set -euo pipefail
  MODE=auto
  TARGETS=""
  for arg in {{args}}; do
    case "$arg" in
      --remote) MODE=remote ;;
      --local) MODE=local ;;
      *) TARGETS="${TARGETS} .#${arg}" ;;
    esac
  done
  if [ -z "$TARGETS" ]; then
    echo "usage: just deploy <host...> [--remote|--local]" >&2
    exit 2
  fi

  DEPLOY_ARG=--remote-build
  case "$MODE" in
    local) DEPLOY_ARG= ;;
    remote) ;;
    *) case "$TARGETS" in *".#lxc-"*) ;;
       *) DEPLOY_ARG=--remote-build ;;
       esac ;;
  esac
  if [ "$MODE" = "auto" ] && printf '%s' "$TARGETS" | grep -q '\.#lxc-' && \
     ! printf '%s' "$TARGETS" | grep -qv '\.#lxc-'; then
    DEPLOY_ARG=
  fi

  nix run nixpkgs#deploy-rs -- -s ${DEPLOY_ARG} --targets ${TARGETS}

# create/edit agenix secret
[group('secrets')]
@secret secret: _add && rekey
  nix run github:oddlama/agenix-rekey -- edit ./secrets/secrets/{{secret}}.age

# authenticate a steam account for lancache prefill, store the token as a secret
[group('secrets')]
auth-steam account: _add && rekey
  #!/usr/bin/env sh
  set -eu

  accounts=".#nixosConfigurations.lxc-lancache.config.services.lancache.prefill.steam.accounts"
  token_path=$(nix eval --raw "${accounts}.{{account}}.tokenFile" 2>/dev/null) || {
    echo "no steam account '{{account}}' on lxc-lancache, configured accounts are:" >&2
    nix eval --raw "$accounts" --apply 'a: builtins.concatStringsSep "\n" (map (n: "  " + n) (builtins.attrNames a))' >&2
    echo >&2
    exit 1
  }
  secret_name="${token_path#/run/agenix/}"
  [ "$secret_name" != "$token_path" ] || { echo "unexpected tokenFile: $token_path" >&2; exit 1; }
  secret="./secrets/secrets/${secret_name}.age"

  prefill=$(nix build --no-link --print-out-paths github:oake/nix-things#steam-lancache-prefill)/bin/SteamPrefill

  workdir=$(mktemp -d)
  trap 'rm -rf "$workdir"' EXIT
  token="$workdir/Config/account.config"

  echo "Logging in as steam account '{{account}}'. This will close itself once the login goes through."
  ( cd "$workdir" && exec "$prefill" select-apps ) < /dev/tty &
  app=$!

  while kill -0 "$app" 2>/dev/null; do
    if grep -q "Steam session initialization complete" "$workdir/app.log" 2>/dev/null; then
      kill -TERM "$app" 2>/dev/null || true
      break
    fi
    sleep 0.5
  done
  wait "$app" 2>/dev/null || true
  printf '\033[?25h'

  [ -s "$token" ] || { echo "login did not complete, no token was written" >&2; exit 1; }

  rm -f "$secret"
  nix run github:oddlama/agenix-rekey -- edit -i "$token" "$secret"

# rekey all agenix secrets
[group('secrets')]
@rekey: _add
  nix run github:oddlama/agenix-rekey -- rekey -a

# navigate config tree
[group('tools')]
@inspect:
  nix run nixpkgs#nix-inspect -- -p .

# prune nix store
[group('tools')]
clean:
  #!/usr/bin/env sh
  set -eu

  if command -v nh >/dev/null; then
    nh clean all
  else
    sudo nix-collect-garbage -d
  fi

# rebuild and switch this host to new configuration
[group('tools')]
rebuild: _add
  #!/usr/bin/env sh
  set -eu

  if [ -f /etc/NIXOS ]; then platform=os; else platform=darwin; fi

  if command -v nh >/dev/null; then
    nh "$platform" switch .
  elif [ "$platform" = os ]; then
    sudo nixos-rebuild switch --option always-allow-substitutes true --flake .
  else
    sudo darwin-rebuild switch --option always-allow-substitutes true --flake .
  fi

@_add:
    git add --all
