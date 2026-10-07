#!/bin/bash
# Remove an app from the app drawer's menu (Remove…): remove-app.sh <desktop-id> <name> <terminal...>
# On Omarchy its own remover does it (web apps, TUIs, launchers you made, packages, flatpaks, as
# the Witcher's Tweaks app drawer did). Without Omarchy: a launcher of your own is deleted, a
# package or flatpak is uninstalled in a terminal (the given terminal command), where it asks for
# your password and to confirm.

id="${1%.desktop}"
name="${2:-$id}"
shift 2
terminal=("$@")
[[ ${#terminal[@]} -gt 0 ]] || terminal=(foot)

[[ -n $id ]] || exit 1

omarchy_bin="${OMARCHY_PATH:-/usr/share/omarchy}/bin"
if [[ -x $omarchy_bin/omarchy-remove-launcher-entry ]]; then
  # Its helpers are called by name
  [[ :$PATH: == *":$omarchy_bin:"* ]] || export PATH="$omarchy_bin:$PATH"
  exec omarchy-remove-launcher-entry "$id" "$name"
fi

user_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
dirs=("$user_dir")
IFS=: read -ra data_dirs <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
for d in "${data_dirs[@]}"; do dirs+=("$d/applications"); done

file=""
for d in "${dirs[@]}"; do
  if [[ -f $d/$id.desktop ]]; then
    file="$d/$id.desktop"
    break
  fi
done
[[ -n $file ]] || { echo "No launcher found for $id" >&2; exit 1; }

# In a terminal that stays open on the result
in_terminal() {
  exec "${terminal[@]}" bash -c "$1"'; printf "\nPress Enter to close."; read -r'
}

if [[ ${file%/*} == "$user_dir" ]]; then
  rm -f "$file"
  update-desktop-database "$user_dir" &>/dev/null || true
  exit 0
fi

if package=$(pacman -Qqo "$file" 2>/dev/null | head -1) && [[ -n $package ]]; then
  in_terminal "echo $(printf '%q' "Uninstalling $name ($package)..."); sudo pacman -Rns $(printf '%q' "$package")"
fi

if command -v flatpak >/dev/null && flatpak info "$id" &>/dev/null; then
  in_terminal "flatpak uninstall $(printf '%q' "$id")"
fi

echo "Don't know how to uninstall $id" >&2
exit 1
