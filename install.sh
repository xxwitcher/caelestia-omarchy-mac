#!/bin/bash
# Build and install Caelestia-Silicon (Apple Silicon: Asahi Linux, Arch Linux ARM; Omarchy-Mac too).
# Any other quickshell (Omarchy's) is left alone; Caelestia runs on quickshell-caelestia (/opt) via `caelestia-qs`.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
packaging="$here/packaging"
pkgbuilds="$packaging/pkgbuilds"

sudo pacman -S --needed vulkan-headers cli11 ninja cmake git aubio libqalculate \
  ttf-material-symbols-variable ttf-cascadia-code-nerd papirus-icon-theme swappy fish dart-sass cliphist fuzzel \
  python-build python-installer python-hatch python-hatch-vcs pybind11 meson autoconf-archive qmltermwidget wf-recorder \
  hyprsunset adw-gtk-theme python-gobject

build_install() {
  local pkg="$1"
  cd "$pkgbuilds/$pkg"

  # Skip rebuilding dependencies that are already installed
  if pacman -Q "$pkg" &>/dev/null && [[ "$pkg" != "caelestia-silicon" ]]; then
    echo "==> $pkg is already installed, skipping."
    return 0
  fi

  # Clean out any old or corrupted package files before building
  rm -f ./*.pkg.tar.*

  makepkg -f --noconfirm

  local pkg_file
  pkg_file=$(ls -t ./*.pkg.tar.* 2>/dev/null | head -n1)
  if [[ -z "$pkg_file" ]]; then
    echo "error: No package file generated for $pkg" >&2
    return 1
  fi

  # The shell's package under its old name owns the same files (--noconfirm won't swap it out)
  if [[ $pkg == caelestia-silicon ]] && pacman -Q caelestia-omarchy-mac &>/dev/null; then
    sudo pacman -Rdd --noconfirm caelestia-omarchy-mac
  fi

  sudo pacman -U --noconfirm "$pkg_file"
}

# Dependencies first: each later package needs the earlier ones installed to build
# mise-bin installs the coding agent picked in Settings > Apps > Agent (Omarchy already has it)
for pkg in libcava qt6-m3shapes-git ttf-rubik-vf python-materialyoucolor quickshell-caelestia caelestia-cli mise-bin; do
  # Any mise will do (another package, or mise's own installer); a second one would conflict
  [[ $pkg == mise-bin ]] && command -v mise &>/dev/null && { echo "==> mise is already installed, skipping."; continue; }
  build_install "$pkg"
done

# The settings search's index of every option on the settings pages, up to date with them
python3 -I "$here/scripts/settings-index.py" || echo "warning: the settings search index could not be updated" >&2

# The shell itself, from this checkout (it replaces caelestia-omarchy-mac, its old name)
CAELESTIA_SRC="$here" build_install caelestia-silicon

# The Agent tab's terminal colours: the shell writes them from Caelestia's scheme, but QMLTermWidget
# only reads schemes from its own folder
state="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
mkdir -p "$state"
for qml in /usr/lib/qt6/qml /usr/lib64/qt6/qml; do
  if [[ -d $qml/QMLTermWidget/color-schemes ]]; then
    sudo ln -sfn "$state/agent-terminal.colorscheme" "$qml/QMLTermWidget/color-schemes/Caelestia.colorscheme"
    break
  fi
done

# SiliconMotion SM77x USB display adapters (vendored in packaging/smidriver/ from the Witcher's
# Tweaks): the driver runs on the evdi kernel module (dkms), and a preloaded shim keeps it from
# crashing against upstream libevdi (packaging/smidriver/evdi-nullfix.c). Any step failing leaves
# the rest of the install be.
install_smi_driver() {
  local kernel_pkg build
  kernel_pkg=$(pacman -Qqo "/usr/lib/modules/$(uname -r)" 2>/dev/null | head -1)
  [[ -n $kernel_pkg ]] || { echo "SMI driver: can't tell which package owns the running kernel" >&2; return 1; }

  sudo pacman -S --needed dkms "$kernel_pkg-headers" libdrm python-setuptools gcc || return 1
  build_install evdi-dkms || return 1

  if [[ -x /opt/siliconmotion/SMIUSBDisplayManager ]]; then
    echo "==> SiliconMotion driver is already installed, skipping."
  else
    # Its installer copies its files by relative path, so it runs from its own folder
    sudo bash -c 'cd "$1" && ./install.sh install' _ "$packaging/smidriver/driver" || return 1
  fi

  build=$(mktemp -d)
  gcc -shared -fPIC -O2 -o "$build/libevdi-nullfix.so" "$packaging/smidriver/evdi-nullfix.c" -levdi || { rm -rf "$build"; return 1; }
  sudo install -D -m 755 "$build/libevdi-nullfix.so" /usr/local/lib/libevdi-nullfix.so
  sudo install -D -m 644 "$packaging/smidriver/nullfix.conf" /etc/systemd/system/smiusbdisplay.service.d/nullfix.conf
  sudo systemctl daemon-reload
  rm -rf "$build"

  # The driver's udev rule starts it when an adapter is plugged in; one already plugged in starts now
  if grep -qsx 090c /sys/bus/usb/devices/*/idVendor; then
    sudo systemctl reset-failed smiusbdisplay 2>/dev/null || true
    sudo systemctl restart smiusbdisplay
  else
    echo "==> SMI driver installed; plug the adapter in to start it (reboot if its monitors don't come up)."
  fi
}
install_smi_driver || echo "warning: the SMI USB display driver could not be set up (see above); the rest of Caelestia is fine" >&2

# Touch Bar layout with media keys and a screenshot key, as the Witcher's Tweaks set it up (MacBooks
# running tiny-dfr; skipped without it)
"$packaging/extras/install-touchbar.sh" || echo "warning: the Touch Bar layout could not be installed (see above)" >&2

"$packaging/link-omarchy-wallpapers.sh"
# Without Omarchy, also install a full Hyprland config, a polkit agent and GTK/Qt theming
if [[ -d /usr/share/omarchy ]]; then
  # Caelestia replaces the Omarchy shell, which was the polkit agent (hypr/caelestia.lua starts this one)
  sudo pacman -S --needed polkit-gnome
  "$here/install-hypr.sh"
else
  sudo pacman -S --needed hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk polkit-gnome gnome-keyring \
    foot thunar gvfs pipewire wireplumber networkmanager bluez bluez-utils
  "$here/install-hypr.sh" --standalone
fi

# The Witcher colour theme (packaging/defaults/witcher-theme.json: gruvbox soft dark with its colours
# changed) among the saved themes on Settings > Colours; a fresh install starts in it
install_witcher_theme() {
  local overrides="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/colour-overrides.json" fresh=0
  [[ -f $overrides ]] || fresh=1
  mkdir -p "$(dirname "$overrides")"
  python3 -I - "$packaging/defaults/witcher-theme.json" "$overrides" "$fresh" <<'PY' || return 1
import json, sys
theme_path, overrides_path, fresh = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
theme = json.load(open(theme_path))
try:
    data = json.load(open(overrides_path))
except (OSError, ValueError):
    data = {}
data.setdefault("overrides", {})
themes = data.setdefault("themes", [])
if not any(t.get("name") == theme["name"] for t in themes):
    themes.append(theme)
if fresh:
    # Its colours on its scheme, which the shell (and the CLI themes) pick up once it's set
    data["overrides"][f"{theme['scheme']} {theme['flavour']} {theme['mode']}"] = dict(theme["colours"])
json.dump(data, open(overrides_path, "w"), indent=4)
PY
  if ((fresh)); then
    local scheme flavour mode
    read -r scheme flavour mode < <(python3 -I -c 'import json, sys; t = json.load(open(sys.argv[1])); print(t["scheme"], t["flavour"], t["mode"])' "$packaging/defaults/witcher-theme.json")
    caelestia scheme set -n "$scheme" -f "$flavour" -m "$mode" || true
  fi
}
install_witcher_theme || echo "warning: the Witcher colour theme could not be added (see above)" >&2

# Instructions and rules for coding agents (the Agent tab, SUPER + A), written for this system
"$here/install-agent-skills.sh" || echo "warning: the agent skills could not be installed (see above)" >&2

# File pickers of apps that ask the desktop portal for one (browsers, Electron apps, Flatpaks, GTK4
# apps) are Caelestia's (assets/portal-filechooser.py): point the portal's FileChooser at it in the
# user's portal config, keeping the rest of what's preferred there
portal_dir="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-desktop-portal"
portal_conf="$portal_dir/hyprland-portals.conf"
[[ -f $portal_conf ]] || portal_conf="$portal_dir/portals.conf"
mkdir -p "$portal_dir"
[[ -f $portal_conf ]] || printf '[preferred]\ndefault=hyprland;gtk\n' >"$portal_conf"
grep -q '^\[preferred\]' "$portal_conf" || printf '\n[preferred]\n' >>"$portal_conf"
sed -i '/^org\.freedesktop\.impl\.portal\.FileChooser=/d' "$portal_conf"
sed -i '/^\[preferred\]/a org.freedesktop.impl.portal.FileChooser=caelestia' "$portal_conf"
# The portal reads its config at startup; the GTK one (still the fallback, and its other dialogs)
# its theme (adw-gtk3-dark, installed above)
for unit in xdg-desktop-portal-gtk.service xdg-desktop-portal.service; do
  systemctl --user is-active --quiet "$unit" && systemctl --user restart "$unit" || true
done

# Title bars on floating windows need the hyprbars plugin built for this Hyprland
"$packaging/titlebars/build-hyprbars" || echo "hyprbars could not be built; floating windows get no drag strip"

# Start the shell just installed. Only inside the Hyprland session it's for (not over SSH or from a
# TTY), and not when Omarchy's own shell was chosen (shell=omarchy in window-style.conf)
style="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/window-style.conf"
if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  echo "Done. Start Caelestia from your Hyprland session with: caelestia shell -d"
elif grep -qsx 'shell=omarchy' "$style"; then
  echo "Done. Omarchy's shell is the one chosen (shell=omarchy in $style), so Caelestia wasn't started."
else
  # Omarchy's shell runs until the next login (hypr-caelestia.lua swaps it out then): stop it,
  # its launcher first so it doesn't start it again
  if [[ -d /usr/share/omarchy ]]; then
    pkill -f 'omarchy-launch-shell' 2>/dev/null || true
    pkill -f "quickshell -n -p ${OMARCHY_PATH:-/usr/share/omarchy}/shell" 2>/dev/null || true
  fi
  caelestia shell -k &>/dev/null || true
  caelestia shell -d
  echo "Done. Caelestia is running."
fi
