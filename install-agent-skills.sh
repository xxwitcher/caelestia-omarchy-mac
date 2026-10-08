#!/bin/bash
# Copyright (C) 2026 George Dobreff ("Witcher") and contributors
# SPDX-License-Identifier: GPL-3.0-only

# Instructions and rules for coding agents (skills), linked where the agents look for them, the
# same places Omarchy links its own: ~/.agents, ~/.claude, ~/.codex, ~/.pi (and ~/.gemini, ~/.hermes
# when those agents are set up). Each skill is written for this system: the agents/skills sources
# keep what only holds on Omarchy between <!-- omarchy --> lines and what only holds without it
# between <!-- asahi --> lines, and {{REPO}} is this checkout.
# On Omarchy only the caelestia skill is added (Omarchy ships its own omarchy and diagnose-crash);
# without it, asahi-desktop and diagnose-crash take their place. Safe to re-run.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
here="$repo/packaging"
data="${XDG_DATA_HOME:-$HOME/.local/share}/caelestia/agent-skills"

if [[ -d /usr/share/omarchy ]]; then
  system=omarchy other=asahi
  skills=(caelestia)
else
  system=asahi other=omarchy
  skills=(caelestia asahi-desktop diagnose-crash)
fi

rm -rf "$data"
mkdir -p "$data"
for skill in "${skills[@]}"; do
  mkdir -p "$data/$skill"
  for file in "$here/agents/skills/$skill"/*; do
    awk -v keep="$system" -v drop="$other" '
      $0 == "<!-- " keep " -->" || $0 == "<!-- /" keep " -->" { next }
      $0 == "<!-- " drop " -->" { skip = 1; next }
      $0 == "<!-- /" drop " -->" { skip = 0; next }
      !skip
    ' "$file" | sed "s|{{REPO}}|$repo|g" >"$data/$skill/${file##*/}"
  done
done

dirs=("$HOME/.agents/skills" "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.pi/agent/skills")
[[ -d $HOME/.gemini ]] && dirs+=("$HOME/.gemini/config/skills")
if [[ -d $HOME/.hermes ]]; then
  dirs+=("$HOME/.hermes/skills")
  for profile in "$HOME"/.hermes/profiles/*/; do
    [[ -d $profile ]] && dirs+=("${profile}skills")
  done
fi

for dir in "${dirs[@]}"; do
  mkdir -p "$dir"
  # Links left from an earlier run whose skill this system no longer gets
  for link in "$dir"/*; do
    [[ -L $link && $(readlink "$link") == "$data/"* && ! -e $link ]] && rm -f "$link"
  done
  for skill in "${skills[@]}"; do
    link="$dir/$skill"
    if [[ -e $link && ! -L $link ]]; then
      echo "Skipping $link: it exists and is not a link"
      continue
    fi
    ln -sfn "$data/$skill" "$link"
  done
done

echo "Agent skills installed: ${skills[*]}"
