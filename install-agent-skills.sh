#!/bin/bash
# Copyright (C) 2026 George Dobreff ("Witcher") and contributors
# SPDX-License-Identifier: GPL-3.0-only

# Instructions and rules for coding agents (skills), linked where the agents look for them:
# ~/.agents, ~/.claude, ~/.codex, ~/.pi (and ~/.gemini, ~/.hermes when those agents are set up).
# {{REPO}} in them is this checkout. Safe to re-run.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
here="$repo/packaging"
data="${XDG_DATA_HOME:-$HOME/.local/share}/caelestia/agent-skills"
skills=(caelestia asahi-desktop diagnose-crash)

rm -rf "$data"
mkdir -p "$data"
for skill in "${skills[@]}"; do
  mkdir -p "$data/$skill"
  for file in "$here/agents/skills/$skill"/*; do
    sed "s|{{REPO}}|$repo|g" "$file" >"$data/$skill/${file##*/}"
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
