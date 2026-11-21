#!/usr/bin/env bash
set -euo pipefail

headers=()
if [[ -n ${GITHUB_TOKEN:-} ]]; then
  headers=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

# Pass the release version explicitly so nix-update preserves tags like v0.8.7-e.
version=$(curl -fsSL "${headers[@]}" https://api.github.com/repos/partydeck/partydeck/releases/latest | jq -er '
  .tag_name
  | if test("^v[0-9]+[.][0-9]+[.][0-9]+(-[a-z])?$") then .[1:]
    else error("Unexpected PartyDeck release tag: \(.)")
    end
')

if [[ $version != "$UPDATE_NIX_OLD_VERSION" ]]; then
  exec nix-update --flake --version="$version" "$UPDATE_NIX_ATTR_PATH"
fi
