#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

source_updater=$1
package_file=$2
version=$(curl -fsSL https://easyeda.com/page/download \
  | sed 's/easyeda-pro-linux-x64-/\neasyeda-pro-linux-x64-/g' \
  | sed -nE 's/^easyeda-pro-linux-x64-([0-9]+([.][0-9]+)*)[.]zip.*/\1/p' \
  | sort -Vu | tail -1)
[[ -n $version ]] || { echo "Could not find the EasyEDA Pro version" >&2; exit 1; }
exec "$source_updater" "$package_file" --version "$version"
