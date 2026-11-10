#!/usr/bin/env bash
# Copy the addon (only the files WoW needs) into a Forever AddOns folder for testing.
#   tools/install-dev.sh                       # default TUF/Omarchy Battle.net path
#   tools/install-dev.sh "/path/to/_forever_/Interface/AddOns"
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
addons="${1:-$HOME/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns}"
[ -d "$addons" ] || { echo "AddOns folder not found: $addons" >&2; exit 1; }
dest="$addons/TristansAddon"
mkdir -p "$dest"
rsync -a --delete \
  --include='*.toc' --include='Core/***' --include='Data/***' --include='Modules/***' --include='UI/***' \
  --include='LICENSE' --exclude='*' \
  "$repo/" "$dest/"
echo "Installed to: $dest"
echo "In game: /reload, then /tristan"
