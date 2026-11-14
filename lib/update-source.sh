#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

package_file=$1
shift

# Discover and edit the version without trying to build the target's fetcher.
nix-update --flake --no-src --src-only "$@"

UPDATE_SOURCE_INFO=$(nix eval --json --no-write-lock-file \
  --apply 'pkg: let src = pkg.src; in {
    urls = src.urls or [ src.url ];
    inherit (src) name;
    hash = src.outputHash;
    recursive = (src.outputHashMode or "flat") == "recursive";
    stripRoot = src.stripRoot or true;
    curlOptsList = src.curlOptsList or [ ];
  }' \
  ".#$UPDATE_NIX_ATTR_PATH")
export UPDATE_SOURCE_INFO

# Recreate only the download/unpack operation using the runner's native tools.
log=$(mktemp)
trap 'rm -f -- "$log"' EXIT
if nix build --impure --no-link --expr '
  let
    pkgs = import <nixpkgs> { };
    source = builtins.fromJSON (builtins.getEnv "UPDATE_SOURCE_INFO");
    fetch = if source.recursive then pkgs.fetchzip else pkgs.fetchurl;
  in fetch ({
    inherit (source) urls name curlOptsList;
    hash = pkgs.lib.fakeHash;
  } // pkgs.lib.optionalAttrs source.recursive {
    inherit (source) stripRoot;
  })
' 2>"$log"; then
  echo "Expected a hash mismatch while prefetching the source" >&2
  exit 1
fi

hash=$(sed -nE 's/^[[:space:]]*got:[[:space:]]*(sha256-[A-Za-z0-9+/]+=*)$/\1/p' "$log" | tail -1)
if [[ -z $hash ]]; then
  cat "$log" >&2
  exit 1
fi
old_hash=$(jq -er .hash <<< "$UPDATE_SOURCE_INFO")
sed -i "s|$old_hash|$hash|g" "$package_file"
echo "Source hash: $hash"
