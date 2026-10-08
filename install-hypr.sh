#!/bin/bash
# Load Caelestia's Hyprland integration from the end of hyprland.lua (idempotent).
# --standalone (no Omarchy): install the fork's full hyprland.lua, backing up the old one.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)/packaging"
conf="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr="$conf/hypr/hyprland.lua"

mkdir -p "$conf/caelestia"
ln -sfn "$here/hypr/caelestia.lua" "$conf/caelestia/hypr-caelestia.lua"

if [[ ${1:-} == --standalone ]]; then
  mkdir -p "$conf/hypr"
  [[ -e $hypr && ! -L $hypr ]] && mv "$hypr" "$hypr.bak.$(date +%s)"
  ln -sfn "$here/hypr/standalone/hyprland.lua" "$hypr"
  echo "Installed the standalone Caelestia Hyprland config at $hypr"
  exit 0
fi

if [[ ! -f $hypr ]]; then
  echo "No $hypr found; add this line to your Hyprland config:"
  echo "  dofile(os.getenv(\"HOME\") .. \"/.config/caelestia/hypr-caelestia.lua\")"
  exit 0
fi

# (An install from before the rename has the same block, marked caelestia-omarchy-mac)
if ! grep -q '>>> caelestia' "$hypr"; then
  cat >>"$hypr" <<'LUA'

-- >>> caelestia (managed by Caelestia-Silicon install-hypr.sh)
pcall(dofile, os.getenv("HOME") .. "/.config/caelestia/hypr-caelestia.lua")
-- <<< caelestia
LUA
fi
echo "Caelestia Hyprland integration loaded from $hypr"
