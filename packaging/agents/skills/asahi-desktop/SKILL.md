---
name: asahi-desktop
description: >
  REQUIRED for end-user customization of this Linux desktop (Arch Linux ARM on Apple Silicon /
  Asahi Linux, Hyprland, Caelestia shell). Use when editing ~/.config/hypr/, ~/.config/foot/,
  ~/.config/kitty/, ~/.config/alacritty/, ~/.config/ghostty/ or other files in ~/.config/.
  Triggers: Hyprland, window rules, animations, keybindings, monitors, gaps, borders, blur,
  opacity, layer rules, workspace settings, display config, terminal config, packages, default
  apps, system updates, bug reports. For the shell itself (bar, dock, launcher, notifications,
  wallpaper, colours, lock, idle) use the caelestia skill.
---

# Asahi Desktop Skill

Manage this machine: Arch Linux ARM on an Apple Silicon Mac (Asahi Linux), with Hyprland as the
window manager and Caelestia as the desktop shell (see the caelestia skill). The desktop was set up
by `{{REPO}}/install.sh`.

This skill is for end-user customization. It is not for developing Caelestia or the install
scripts in `{{REPO}}`.

## When This Skill MUST Be Used

- Editing ANY file in `~/.config/hypr/` (keybindings, monitors, window rules, animations...)
- Editing terminal configs (foot, kitty, alacritty, ghostty)
- Window behavior, animations, opacity, blur, gaps, borders, layer rules, workspaces
- Display/monitor configuration
- Installing or removing packages, system updates
- Reporting a bug in this setup

**If you're about to edit a config file in ~/.config/ on this system, STOP and use this skill first.**

## Topic Guides

- [`hyprland.md`](hyprland.md) - keybindings, monitors, window rules, and other Hyprland config

## Critical Safety Rules

For privileged commands, follow the Privilege Escalation rules below: `sudo` when a terminal is
available for the password prompt, `pkexec` when it is not. Do not wrap commands that already
manage privilege elevation themselves.

**Never modify files owned by packages** (`/usr/`, `/etc/xdg/quickshell/caelestia/`), and never
edit files in `{{REPO}}` for a customization: `~/.config/hypr/hyprland.lua` and
`~/.config/caelestia/hypr-caelestia.lua` are symlinks into that checkout, so editing them changes
the checkout. Reading all of these is safe and useful.

**Always use these safe locations instead:**
- `~/.config/hypr/user.lua` - personal Hyprland changes (loaded last)
- `~/.config/` - other user configuration

Back up a file before changing it: `cp file file.bak.$(date +%s)`.

## Privilege Escalation

For an interactive script or command run in a visible terminal, use `sudo` for privileged work;
the terminal is the appropriate place to request a password.

Use `pkexec` only when the caller cannot interact with a terminal or cannot enter a password there,
such as a command launched by an agent or a graphical background process. Do not replace `sudo`
with `pkexec` merely because a command changes system state.

## System Architecture

| Component | Purpose | Config Location |
|-----------|---------|-----------------|
| **Arch Linux ARM** (Asahi) | Base OS, kernel and Apple Silicon support | `/etc/`, `~/.config/` |
| **Hyprland** | Wayland compositor/WM (Lua config) | `~/.config/hypr/` |
| **Caelestia** | Shell: bar, dock, launcher, notifications, OSD, lock, idle (Quickshell) | `~/.config/caelestia/` |
| **foot** | Default terminal (`$TERMINAL` overrides it) | `~/.config/foot/foot.ini` |
| **Thunar** | File manager | |
| **PipeWire / WirePlumber** | Audio | `~/.config/wireplumber/` |
| **NetworkManager, BlueZ** | Network, Bluetooth (also in Caelestia's settings) | |
| **tiny-dfr** | Touch Bar (MacBooks that have one) | `/etc/tiny-dfr/config.toml` |

## Packages and Updates

```bash
pacman -Q <name>                      # Is it installed?
pacman -Ss <term>                     # Search the repositories
sudo pacman -S --needed <pkgs...>     # Install
sudo pacman -Rns <pkgs...>            # Remove
sudo pacman -Syu                      # Full system update
```

Packages come from the Arch Linux ARM repositories (aarch64): not everything in Arch's x86_64
repos or the AUR has an aarch64 build. No AUR helper is set up by default; AUR packages are built
with `makepkg` from their PKGBUILD, and only when the user asks for one.

Caelestia's own packages (`caelestia-silicon`, `quickshell-caelestia`, `caelestia-cli` and their
dependencies) are built from `{{REPO}}/packaging/pkgbuilds/` by `install.sh`, not from a
repository; `pacman -Syu` does not update them.

## Terminals

```
~/.config/foot/foot.ini
~/.config/kitty/kitty.conf
~/.config/alacritty/alacritty.toml
~/.config/ghostty/config
```

Changes apply to new terminal windows. Terminal colours come from Caelestia's colour scheme (see
the caelestia skill), so don't hardcode colours there unless the user wants them fixed.

## Other Configs

| App | Location |
|-----|----------|
| btop | `~/.config/btop/btop.conf` |
| fuzzel | `~/.config/fuzzel/fuzzel.ini` |
| git | `~/.config/git/config` |
| Apps started at login | `~/.config/autostart/*.desktop` (the dock's Open at Login sets them) |

## System Information

```bash
uname -r                              # Kernel
hyprctl version                       # Hyprland version
pacman -Q hyprland caelestia-silicon quickshell-caelestia caelestia-cli
journalctl --user -b                  # This session's user log
journalctl -b -p warning              # This boot's system warnings and errors
caelestia shell -l                    # The shell's log
```

## Decision Framework

1. **Is it about the shell** (bar, dock, launcher, notifications, wallpaper, colours, lock, idle)?
   Use the caelestia skill.
2. **Is it a Hyprland change?** Follow [`hyprland.md`](hyprland.md); put it in `~/.config/hypr/user.lua`.
3. **Is it another config edit?** Edit in `~/.config/`, never in `/usr/` or the checkout.
4. **Is it a package install?** `sudo pacman -S --needed <pkgs...>` in a terminal.
5. **Is it automation on an event?** Use a systemd user unit (`~/.config/systemd/user/`) or a
   Hyprland event handler (`hl.on(...)`) in `user.lua`.
6. **Unsure a command exists?** Check with `command -v <name>` before suggesting it.

## Reporting Bugs

Route a problem to where it belongs, and only once it is a verified bug:

- **Caelestia on this machine, its install scripts or the Hyprland config it ships:**
  https://github.com/xxwitcher/caelestia-silicon
- **Apple Silicon hardware support, the Asahi kernel or drivers:** Asahi Linux
  (https://asahilinux.org/, issues at https://github.com/AsahiLinux)
- **A package built by Arch Linux ARM:** https://archlinuxarm.org/
- **A bug inside an application:** that application's own project

Before filing anything: show the user the exact title and body and wait for a yes, search existing
issues (open and closed) first, and only use `gh` when `gh auth status` succeeds. Never install or
authenticate `gh` yourself; hand the user the text instead. Include what happened, what was
expected, steps to reproduce, and the System Information above. `gh` cannot attach media: save a
screenshot (`caelestia screenshot`) and give the user its path. End the report with a line naming
the model and agent harness that wrote it ("Filed by <model> via <harness>.").

## Out of Scope

- Changing Caelestia's code or the install scripts in `{{REPO}}` (development: only when asked)
- Editing package-owned files in `/usr/` or `/etc/xdg/quickshell/caelestia/`
