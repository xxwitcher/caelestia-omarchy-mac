#!/bin/bash
# Copyright (C) 2026 George Dobreff ("Witcher") and contributors
# SPDX-License-Identifier: GPL-3.0-only

# Touch Bar layout for MacBooks running tiny-dfr (media/brightness keys and a screenshot key).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
[[ -d /etc/tiny-dfr || -x /usr/bin/tiny-dfr ]] || { echo "tiny-dfr is not installed; nothing to do"; exit 0; }
sudo install -Dm644 "$here/tiny-dfr/config.toml" /etc/tiny-dfr/config.toml
sudo install -Dm644 "$here/tiny-dfr/screenshot.png" /etc/tiny-dfr/screenshot.png
sudo systemctl restart tiny-dfr 2>/dev/null || true
echo "Touch Bar layout installed"
