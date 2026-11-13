#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

source_updater=$1
package_file=$2
version=$(curl -fsSL https://ilyabirman.ru/typography-layout/ \
  | sed 's/ilya-birman-typolayout-/\nilya-birman-typolayout-/g' \
  | sed -nE 's/^ilya-birman-typolayout-([0-9]+([.][0-9]+)*)-mac[.]zip.*/\1/p' \
  | sort -Vu | tail -1)
[[ -n $version ]] || { echo "Could not find the typography layout version" >&2; exit 1; }
exec "$source_updater" "$package_file" --version "$version"
