#!/bin/bash
# Build and install Caelestia for omarchy-mac (Apple Silicon, Arch Linux ARM).
# Omarchy's own quickshell is left alone; Caelestia runs on quickshell-caelestia (/opt) via `caelestia-qs`.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
pkgbuilds="$here/pkgbuilds"

sudo pacman -S --needed vulkan-headers cli11 ninja cmake git aubio libqalculate \
  ttf-material-symbols-variable ttf-cascadia-code-nerd papirus-icon-theme swappy fish dart-sass cliphist fuzzel \
  python-build python-installer python-hatch python-hatch-vcs pybind11 meson autoconf-archive qmltermwidget wf-recorder

build_install() {
  cd "$pkgbuilds/$1"
  makepkg -f --noconfirm
  sudo pacman -U --needed --noconfirm ./*.pkg.tar.*
}

# Dependencies first: each later package needs the earlier ones installed to build
for pkg in libcava qt6-m3shapes-git ttf-rubik-vf python-materialyoucolor quickshell-caelestia caelestia-cli; do
  build_install "$pkg"
done

# The shell itself, from this checkout
CAELESTIA_SRC="$(dirname "$here")" build_install caelestia-omarchy-mac

"$here/link-omarchy-wallpapers.sh"
# Without Omarchy, also install a full Hyprland config, a polkit agent and GTK/Qt theming
if [[ -d /usr/share/omarchy ]]; then
  "$here/install-hypr.sh"
else
  sudo pacman -S --needed hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk polkit-gnome gnome-keyring \
    adw-gtk-theme foot thunar pipewire wireplumber networkmanager bluez bluez-utils
  "$here/install-hypr.sh" --standalone
fi

# Title bars on floating windows need the hyprbars plugin built for this Hyprland
"$here/titlebars/build-hyprbars" || echo "hyprbars could not be built; floating windows get no drag strip"

echo "Done. Start Caelestia with: caelestia shell -d"
