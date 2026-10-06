#!/bin/bash
# Link every Omarchy theme's backgrounds into Caelestia's wallpaper folder, one category per theme.
# Safe to re-run: existing links are refreshed, real files and folders are never touched.
set -euo pipefail

walls="${CAELESTIA_WALLPAPERS_DIR:-$HOME/Pictures/Wallpapers}"
mkdir -p "$walls"

for backgrounds in "${OMARCHY_PATH:-/usr/share/omarchy}"/themes/*/backgrounds "$HOME"/.config/omarchy/themes/*/backgrounds; do
  [[ -d $backgrounds ]] || continue
  theme="$(basename "$(dirname "$backgrounds")")"
  link="$walls/$theme"

  if [[ -e $link && ! -L $link ]]; then
    echo "Skipping $theme: $link already exists and is not a link"
    continue
  fi
  ln -sfn "$backgrounds" "$link"
done

echo "Omarchy wallpapers linked into $walls"
