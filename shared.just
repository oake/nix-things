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

# rekey all agenix secrets
[group('secrets')]
@rekey: _add
  nix run github:oddlama/agenix-rekey -- rekey -a

# navigate config tree
[group('tools')]
@inspect:
  nix run nixpkgs#nix-inspect -- -p .

# rebuild and switch this host to new configuration
[group('tools')]
@rebuild: _add
    if [ -f /etc/NIXOS ]; then \
        sudo nixos-rebuild switch --flake .; \
    else \
        sudo darwin-rebuild switch --flake .; \
    fi

@_add:
    git add --all
