#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

source_updater=$1
package_file=$2
version=$(curl -fsSL https://www.charlesproxy.com/download/ \
  | sed -nE 's/.*name="version" value="([0-9]+([.][0-9]+)*)".*/\1/p' \
  | sort -Vu | tail -1)
[[ -n $version ]] || { echo "Could not find the Charles version" >&2; exit 1; }

# Both downloads share a version but have independent hashes.
package=${UPDATE_NIX_ATTR_PATH##*.}
outputs=${UPDATE_NIX_ATTR_PATH%.*}
outputs=${outputs%.*}
for system in x86_64-linux aarch64-darwin; do
  UPDATE_NIX_ATTR_PATH="$outputs.$system.$package" \
    "$source_updater" "$package_file" --version "$version"
done
