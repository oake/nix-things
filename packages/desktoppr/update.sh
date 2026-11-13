#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

source_updater=$1
package_file=$2
release=$(curl -fsSL https://api.github.com/repos/scriptingosx/desktoppr/releases/latest)
version=$(jq -er '
  [.assets[].name
    | select(endswith(".zip"))
    | capture("^desktoppr-(?<version>[0-9]+([.][0-9]+)*(-[0-9]+)?)[.]zip$").version]
  | unique
  | if length == 1 then .[0] else error("Expected one desktoppr ZIP version") end
' <<< "$release")
exec "$source_updater" "$package_file" --version "$version"
