#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

package_file=$1
package_dir=$(dirname -- "$package_file")
repo_root=$(git -C "$package_dir" rev-parse --show-toplevel)

latest=$(nix eval --impure --refresh --json --expr '
  let
    source = builtins.fetchTree {
      type = "github";
      owner = "oake";
      repo = "infra";
    };
  in { inherit (source) rev narHash; }
' | jq .)

rev=$(jq -er .rev <<< "$latest")
hash=$(jq -er .narHash <<< "$latest")
current_rev=$(sed -nE 's/^[[:space:]]*rev = "([^"]*)";$/\1/p' "$package_file")
current_hash=$(sed -nE 's/^[[:space:]]*narHash = "([^"]*)";$/\1/p' "$package_file")
if [[ -z $current_rev || -z $current_hash || $current_rev == *$'\n'* || $current_hash == *$'\n'* ]]; then
  echo "Expected exactly one rev and narHash assignment in $package_file" >&2
  exit 1
fi
if [[ $rev == "$current_rev" && $hash == "$current_hash" ]]; then
  echo "infra is already up to date ($rev)"
  exit 0
fi

sed -i -E \
  -e "s|^([[:space:]]*rev = \")[^\"]*(\";)$|\1$rev\2|" \
  -e "s|^([[:space:]]*narHash = \")[^\"]*(\";)$|\1$hash\2|" \
  "$package_file"

cd -- "$repo_root"
for component in infra-hub infra-beacon infra-deployer; do
  nix-update --flake --version=skip --no-src "$component"
done

echo "Updated infra to $rev"
