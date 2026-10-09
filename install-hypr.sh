#!/bin/bash
# Copyright (C) 2026 George Dobreff ("Witcher") and contributors
# SPDX-License-Identifier: GPL-3.0-only

# Install Taris's Hyprland config (packaging/hypr/standalone/hyprland.lua, which loads the shell
# integration, hypr-taris.lua), backing up a hyprland.lua that isn't ours.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)/packaging"
conf="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr="$conf/hypr/hyprland.lua"

mkdir -p "$conf/taris" "$conf/hypr"
ln -sfn "$here/hypr/taris.lua" "$conf/taris/hypr-taris.lua"
[[ -e $hypr && ! -L $hypr ]] && mv "$hypr" "$hypr.bak.$(date +%s)"
ln -sfn "$here/hypr/standalone/hyprland.lua" "$hypr"
echo "Installed the TarisOS Hyprland config at $hypr"
