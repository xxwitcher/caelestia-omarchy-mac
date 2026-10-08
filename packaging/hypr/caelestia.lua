-- Caelestia-Silicon: shell integration for Hyprland.
-- Loaded from the end of hyprland.lua by install-hypr.sh. Settings made in Caelestia's
-- Displays and Keyboard pages live in ~/.config/caelestia/hypr-settings.lua; the Window style
-- page writes ~/.config/caelestia/window-style.conf.

local home = os.getenv("HOME")
local qs = "caelestia-qs -c caelestia"

-- Panels animate themselves
hl.layer_rule({ match = { namespace = "caelestia-(border-exclusion|area-picker|overview)" }, no_anim = true })
hl.layer_rule({ match = { namespace = "caelestia-(drawers|background)" }, animation = "fade" })

-- Shell shortcuts
-- (chosen to avoid Omarchy's own bindings, e.g. the SUPER + TAB family)
hl.bind("SUPER + GRAVE", hl.dsp.global("caelestia:overview"))
-- SUPER + SPACE opens the app launcher (instead of the Omarchy menu, on Omarchy)
pcall(hl.unbind, "SUPER + SPACE")
hl.bind("SUPER + SPACE", hl.dsp.global("caelestia:launcher"))
hl.bind("SUPER + N", hl.dsp.global("caelestia:sidebar"))
hl.bind("SUPER + COMMA", hl.dsp.exec_cmd(qs .. " ipc call nexus open"))

-- 3-finger swipe up opens the window overview, down closes it
hl.gesture({ fingers = 3, direction = "up", action = function()
  hl.dispatch(hl.dsp.global("caelestia:overviewOpen"))
end })
hl.gesture({ fingers = 3, direction = "down", action = function()
  hl.dispatch(hl.dsp.global("caelestia:overviewClose"))
end })

-- Window style (Settings > Window style writes window-style.conf: key=value lines)
local style = { gradient = "1", bordertheme = "1", colors = "c4b5fd a855f7 da70d6", inactive = "5b3a7a", fade = "1", swipe = "1", roundingon = "1", rounding = "60", bordersize = "1", gapsin = "1", gapsout = "3", columns = "0", floatnew = "0" }
local function read_conf(path, into)
  local f = io.open(path)
  if not f then return end
  for line in f:lines() do
    local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if k then into[k] = v end
  end
  f:close()
end
read_conf(home .. "/.config/caelestia/window-style.conf", style)
-- The border in the colour scheme's colours (theme-border.conf, written by the shell on every
-- scheme change) until colours are picked on the Window style page
if style.bordertheme ~= "0" then
  local theme = {}
  read_conf(home .. "/.config/caelestia/theme-border.conf", theme)
  if theme.colors and theme.inactive then
    style.colors, style.inactive = theme.colors, theme.inactive
  end
end

-- On Omarchy (its config defines the global `o`), Caelestia replaces the Omarchy shell;
-- shell=omarchy in window-style.conf keeps Omarchy's. Other distros start Caelestia themselves
-- (the standalone config does) and skip all of this.
local omarchy = type(_G.o) == "table" and type(_G.o.launch) == "function"
_G.caelestia_shell = style.shell or "caelestia"

if omarchy then
  -- Omarchy has no switch for its shell, so its launcher is swapped for Caelestia's wherever
  -- Hyprland runs it: the autostart (hl.exec_cmd) and omarchy-restart-shell (hl.dsp.exec_cmd).
  -- The functions are looked up when called, so wrapping them here, after Omarchy's config, is enough.
  local function swap_shell(fn)
    return function(cmd, ...)
      if cmd == "omarchy-launch-shell" and _G.caelestia_shell ~= "omarchy" then
        cmd = "caelestia shell -d"
      end
      return fn(cmd, ...)
    end
  end
  -- Wrap once per Lua state: a reload re-runs this file against the already wrapped functions
  if hl.exec_cmd ~= _G.caelestia_exec_cmd then
    _G.caelestia_exec_cmd = swap_shell(hl.exec_cmd)
    hl.exec_cmd = _G.caelestia_exec_cmd
  end
  if hl.dsp.exec_cmd ~= _G.caelestia_dsp_exec_cmd then
    _G.caelestia_dsp_exec_cmd = swap_shell(hl.dsp.exec_cmd)
    hl.dsp.exec_cmd = _G.caelestia_dsp_exec_cmd
  end

  -- Without Omarchy's shell, its polkit agent and lock are gone: run polkit-gnome, and point
  -- Omarchy's lock bindings (which go through omarchy-shell) at Caelestia's lock
  if _G.caelestia_shell ~= "omarchy" then
    hl.on("hyprland.start", function()
      hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    end)

    local lock = qs .. " ipc call lock lock"
    hl.unbind("SUPER + CTRL + L")
    hl.bind("SUPER + CTRL + L", hl.dsp.exec_cmd(lock))

    -- Same as omarchy-system-lid-close: lock when the lid closes with no external monitor
    local lid = "sh -c 'if omarchy-hw-laptop-closed && ! omarchy-hw-external-monitors; then " .. lock .. "; fi; omarchy-hyprland-monitor-clamshell'"
    for _, switch in ipairs({ "Lid Switch", "Apple SMC power/lid events" }) do
      hl.unbind("switch:on:" .. switch)
      hl.bind("switch:on:" .. switch, hl.dsp.exec_cmd(lid), { locked = true })
    end

    -- Display brightness keys (the Touch Bar's too) through Caelestia, as the standalone config
    -- does, so its brightness slider shows and follows them: Omarchy's script changes the
    -- backlight behind the shell's back and shows its own OSD, which went with its shell. Steps
    -- are Settings > Services' brightness step; ALT keeps Omarchy's 1% steps.
    for key, global in pairs({ XF86MonBrightnessUp = "caelestia:brightnessUp", XF86MonBrightnessDown = "caelestia:brightnessDown" }) do
      hl.unbind(key)
      hl.bind(key, hl.dsp.global(global), { locked = true, repeating = true })
    end
    for key, step in pairs({ XF86MonBrightnessUp = "+1%", XF86MonBrightnessDown = "1%-" }) do
      hl.unbind("ALT + " .. key)
      hl.bind("ALT + " .. key, hl.dsp.exec_cmd(qs .. " ipc call brightness set " .. step), { locked = true, repeating = true })
    end

    -- Media keys (the Touch Bar's too) went to omarchy-shell, which isn't running: play/pause,
    -- previous and next act on the player Caelestia's media panel shows, and SHIFT + play/pause
    -- switches to the next player
    local media = {
      ["XF86AudioPlay"] = "caelestia:mediaToggle",
      ["XF86AudioPause"] = "caelestia:mediaToggle",
      ["XF86AudioNext"] = "caelestia:mediaNext",
      ["ALT + XF86AudioPlay"] = "caelestia:mediaNext",
      ["XF86AudioPrev"] = "caelestia:mediaPrev",
      ["ALT + SHIFT + XF86AudioPlay"] = "caelestia:mediaPrev",
      ["SHIFT + XF86AudioPlay"] = "caelestia:mediaSwitch",
      ["SHIFT + XF86AudioPause"] = "caelestia:mediaSwitch",
    }
    for key, global in pairs(media) do
      pcall(hl.unbind, key)
      hl.bind(key, hl.dsp.global(global), { locked = true })
    end
  end
end

-- Windows (same as the witchers-tweaks rounding, wide-columns and window-mode; border size and
-- gaps are set at the end of this file). New windows tile unless floatnew is on.
if style.roundingon == "1" then
  local percent = tonumber(style.rounding) or 60
  hl.config({ decoration = { rounding = math.floor(math.min(100, percent) * 32 / 100 + 0.5) } })
end
if style.columns == "1" then
  hl.config({ scrolling = { column_width = 0.97 } })
end
if style.floatnew == "1" then
  hl.window_rule({ match = { class = ".*" }, float = true })
end

-- File pickers and other dialogs open like Caelestia's settings: centred above everything, the
-- rest dimmed, no border or shadow. Every dialog the desktop portal shows (whichever app asked),
-- and the usual Open/Save dialogs apps draw themselves, by title. modules/windowcontrols in the
-- shell matches the same windows (no window buttons on them).
local dialog_class = "^(xdg-desktop-portal-gtk)$"
local dialog_title = "^(Open (File|Files|Folder)|Select (a File|Folder|Directory)|Save (File|As|Image|Image As)|Choose (a )?File)(…|\\.\\.\\.)?$"
for _, match in ipairs({ { class = dialog_class }, { title = dialog_title } }) do
  hl.window_rule({ match = match, float = true, center = true, size = { 900, 600 }, border_size = 0, no_shadow = true, pin = true, dim_around = true })
end

if style.fade == "1" then
  hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "default", style = "slidefade 20%" })
end

-- 3-finger horizontal swipe between workspaces, tuned like the witchers-tweaks swipe: a short
-- swipe is enough and a quick flick commits. Omarchy doesn't define the gesture, and neither does
-- the standalone config, so it's only here (defining it twice in your own config is an error).
if style.swipe == "1" then
  pcall(hl.gesture, { fingers = 3, direction = "horizontal", action = "workspace" })
  hl.config({ gestures = {
    workspace_swipe_distance = 150, -- px for a full swipe (default 300)
    workspace_swipe_cancel_ratio = 0.15, -- commit after 15% instead of 50%
    workspace_swipe_min_speed_to_force = 5, -- a quick flick switches (default 30)
    workspace_swipe_create_new = true, -- past the last workspace makes a new one
    workspace_swipe_forever = true, -- keep going past neighbours in one swipe
  } })
end

-- Keybindings from the witchers-tweaks: CTRL+Q closes the window, SUPER+M minimizes it (into
-- special:minimized, where the dock brings it back), SUPER+B opens the browser and SUPER+A the
-- default agent in a terminal (on Omarchy instead of SUPER+SHIFT+B and SUPER+SHIFT+A)
hl.bind("CTRL + Q", hl.dsp.window.close(), { description = "Close window" })
hl.bind("SUPER + M", hl.dsp.window.move({ workspace = "special:minimized", follow = false }), { description = "Minimize window" })
if omarchy then
  pcall(hl.unbind, "SUPER + SHIFT + B")
  o.bind("SUPER + B", "Browser", { omarchy = "browser" })
  pcall(hl.unbind, "SUPER + SHIFT + A")
  o.bind("SUPER + A", "Agent", "omarchy-agent")
else
  -- The standalone config binds SUPER + B to the browser itself
  hl.bind("SUPER + A", hl.dsp.global("caelestia:agent"), { description = "Agent" })
end

-- Keyboard options from the witchers-tweaks, added to the ones already set: left Ctrl and left
-- Super trade places (the right-hand keys stay), and Caps Lock is a plain Caps Lock: not Omarchy's
-- compose key, and not cancelled by Shift (Omarchy's shift:both_capslock_cancel, which made
-- Shift + 1 turn Caps Lock off and type 1 instead of !). Settings > Keyboard & trackpad changes either; what it saves there is
-- loaded after this (hypr-settings.lua) and wins.
pcall(function()
  local options = hl.get_config("input.kb_options")
  options = (type(options) == "string" and options ~= "[[EMPTY]]") and options or ""
  local kept = {}
  for option in options:gmatch("[^,]+") do
    if option ~= "compose:caps" and option ~= "shift:both_capslock_cancel" and option ~= "ctrl:swap_lwin_lctl" then
      kept[#kept + 1] = option
    end
  end
  kept[#kept + 1] = "ctrl:swap_lwin_lctl"
  local new = table.concat(kept, ",")
  if new ~= options then
    hl.config({ input = { kb_options = new } })
  end
end)

-- Three-colour gradient border turning around the active window. Hyprland's borderangle loop
-- stops after one turn on 0.56, so a timer turns it (~13 s per turn at ~30 fps); one timer per
-- session calls a tick each reload redefines. The shell changes the colours live (on a scheme
-- change) through caelestia_set_border, so it needn't reload Hyprland, which would close its
-- settings.
if style.gradient == "1" then
  local function gradient_of(spec)
    local colors = {}
    for hex in (spec or ""):gmatch("%x%x%x%x%x%x") do colors[#colors + 1] = hex:lower() end
    if #colors ~= 3 then return nil end
    local gradient, weights = {}, { 3, 3, 2 }
    for i, hex in ipairs(colors) do
      for _ = 1, weights[i] do gradient[#gradient + 1] = "rgba(" .. hex .. "ee)" end
    end
    return gradient
  end

  _G.caelestia_border_angle = _G.caelestia_border_angle or 45
  function _G.caelestia_set_border(colors, inactive)
    _G.caelestia_border_gradient = gradient_of(colors) or _G.caelestia_border_gradient or gradient_of("c4b5fd a855f7 da70d6")
    local col = { active_border = { colors = _G.caelestia_border_gradient, angle = _G.caelestia_border_angle } }
    if inactive and inactive:match("^%x%x%x%x%x%x$") then col.inactive_border = "rgba(" .. inactive .. "aa)" end
    hl.config({ general = { col = col } })
  end
  _G.caelestia_border_gradient = nil
  _G.caelestia_set_border(style.colors, style.inactive)

  function _G.caelestia_border_tick()
    _G.caelestia_border_angle = (_G.caelestia_border_angle + 360 * 33 / 13330) % 360
    hl.config({ general = { col = { active_border = { colors = _G.caelestia_border_gradient, angle = _G.caelestia_border_angle } } } })
  end
  if not _G.caelestia_border_timer then
    _G.caelestia_border_timer = hl.timer(function()
      if _G.caelestia_border_tick then _G.caelestia_border_tick() end
    end, { timeout = 33, type = "repeat" })
  end
else
  _G.caelestia_border_tick = nil
  _G.caelestia_set_border = nil
end

-- Title bars on floating windows (ported from the witchers-tweaks titlebars tweak): the
-- hyprbars plugin (built by titlebars/build-hyprbars) as an invisible strip just above the
-- window's top edge, to drag it by (double-click maximizes). The close, minimize and maximize
-- buttons grow out of the window's top-left corner on hover (modules/windowcontrols). Tiled
-- windows get no strip. A build for another Hyprland version doesn't load (Hyprland checks).
if style.titlebars ~= "0" then
  pcall(function()
    local so = home .. "/.local/share/caelestia/hyprbars/hyprbars.so"
    local f = io.open(home .. "/.local/share/caelestia/hyprbars/built-for")
    -- hl.plugin.load only lists the plugin; it has to be listed on every parse, loaded or not,
    -- or Hyprland unloads it, reloads the config and loops
    if f then
      f:close()
      pcall(hl.plugin.load, so)
    end
    if hl.plugin.hyprbars then
      hl.config({ plugin = { hyprbars = {
        bar_height = 14,
        bar_color = "rgba(00000000)",
        bar_title_enabled = false,
        bar_part_of_window = false,
        bar_precedence_over_border = false,
        bar_blur = false,
        on_double_click = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\" })'",
      } } })
      hl.window_rule({ match = { float = false }, ["hyprbars:no_bar"] = true })
      hl.window_rule({ match = { fullscreen = true }, ["hyprbars:no_bar"] = true })
      hl.window_rule({ match = { class = dialog_class }, ["hyprbars:no_bar"] = true })
      hl.window_rule({ match = { title = dialog_title }, ["hyprbars:no_bar"] = true })
    end
  end)
end

-- Floating windows resize by dragging their border; tiled windows don't. Follows Hyprland's
-- events, nothing polls.
if style.borderresize ~= "0" then
  local resizing = nil
  local function follow()
    local w = hl.get_active_window()
    local want = w ~= nil and w.floating == true and (tonumber(w.fullscreen) or 0) == 0
    if want ~= resizing then
      resizing = want
      hl.config({ general = { resize_on_border = want } })
    end
  end
  for _, event in ipairs({ "window.active", "window.update_rules", "window.fullscreen", "window.close", "workspace.active" }) do
    hl.on(event, function() pcall(follow) end)
  end
  pcall(follow)
end

-- Settings from the Caelestia settings app (last, so they win)
pcall(dofile, home .. "/.config/caelestia/hypr-settings.lua")

-- Border size and gaps from the Window style page, after hypr-settings.lua so they win over the
-- same options set on the old Hyprland page
hl.config({ general = {
  border_size = tonumber(style.bordersize) or 1,
  gaps_in = tonumber(style.gapsin) or 1,
  gaps_out = tonumber(style.gapsout) or 3,
} })
