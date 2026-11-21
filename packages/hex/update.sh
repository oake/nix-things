#!/usr/bin/env bash
set -euo pipefail

headers=()
if [[ -n ${GITHUB_TOKEN:-} ]]; then
  headers=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

version=$(curl -fsSL "${headers[@]}" https://api.github.com/repos/anomalyco/hex/releases/latest | jq -er '
  .tag_name as $tag
  | if ($tag | test("^v[0-9]+[.][0-9]+[.][0-9]+$")) then
      $tag[1:] as $version
      | if any(.assets[]; .name == "hex-\($version)-macos-arm64.zip") then $version
        else error("Hex \($tag) is missing the macOS arm64 ZIP")
        end
    else error("Unexpected Hex release tag: \($tag)")
    end
')

if [[ $version != "$UPDATE_NIX_OLD_VERSION" ]]; then
  exec "$@" --version="$version" "$UPDATE_NIX_ATTR_PATH"
fi
