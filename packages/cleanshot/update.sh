#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

source_updater=$1
package_file=$2
version=$(curl -fsSL https://cleanshot.com/changelog \
  | sed 's/class="number"/\nclass="number"/g' \
  | sed -nE 's/^class="number"[^>]*>([0-9]+([.][0-9]+)+).*/\1/p' \
  | sort -Vu | tail -1)
[[ -n $version ]] || { echo "Could not find the CleanShot version" >&2; exit 1; }
exec "$source_updater" "$package_file" --version "$version"
