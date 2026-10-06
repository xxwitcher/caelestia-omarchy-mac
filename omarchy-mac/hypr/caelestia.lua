-- Caelestia (omarchy-mac fork): shell integration for Hyprland.
-- Loaded from the end of hyprland.lua by install-hypr.sh. Settings made in Caelestia's
-- Hyprland, Displays and Keyboard pages live in ~/.config/caelestia/hypr-settings.lua.

local home = os.getenv("HOME")
local qs = "caelestia-qs -c caelestia"

-- Panels animate themselves
hl.layer_rule({ match = { namespace = "caelestia-(border-exclusion|area-picker|overview)" }, no_anim = true })
hl.layer_rule({ match = { namespace = "caelestia-(drawers|background)" }, animation = "fade" })

-- Shell shortcuts
-- (chosen to avoid Omarchy's own bindings, e.g. the SUPER + TAB family and SUPER + SPACE)
hl.bind("SUPER + GRAVE", hl.dsp.global("caelestia:overview"))
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
local style = { gradient = "1", colors = "c4b5fd a855f7 da70d6", inactive = "5b3a7a", fade = "1", swipe = "1", roundingon = "1", rounding = "60", gaps = "1", columns = "0", floatnew = "0" }
local f = io.open(home .. "/.config/caelestia/window-style.conf")
if f then
  for line in f:lines() do
    local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if k then style[k] = v end
  end
  f:close()
end

-- Windows (same as the witchers-tweaks rounding, no-gaps, wide-columns and window-mode)
if style.roundingon == "1" then
  local percent = tonumber(style.rounding) or 60
  hl.config({ decoration = { rounding = math.floor(math.min(100, percent) * 32 / 100 + 0.5) } })
end
if style.gaps == "0" then
  hl.config({ general = { gaps_in = 0, gaps_out = 0 } })
end
if style.columns == "1" then
  hl.config({ scrolling = { column_width = 0.97 } })
end
if style.floatnew == "1" then
  hl.window_rule({ match = { class = ".*" }, float = true })
end

if style.fade == "1" then
  hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "default", style = "slidefade 20%" })
end

-- Short swipes and quick flicks switch workspace
if style.swipe == "1" then
  -- Tunes the 3-finger horizontal workspace gesture; the gesture itself comes from your
  -- Hyprland config (the standalone config defines it), since defining it twice is an error.
  hl.config({ gestures = { workspace_swipe_distance = 150, workspace_swipe_cancel_ratio = 0.15, workspace_swipe_min_speed_to_force = 5, workspace_swipe_create_new = true } })
end

-- Three-colour gradient border turning around the active window. Hyprland's borderangle loop
-- stops after one turn on 0.56, so a timer turns it (~13 s per turn at ~30 fps); one timer per
-- session calls a tick each reload redefines.
if style.gradient == "1" then
  local colors = {}
  for hex in style.colors:gmatch("%x%x%x%x%x%x") do colors[#colors + 1] = hex:lower() end
  if #colors ~= 3 then colors = { "c4b5fd", "a855f7", "da70d6" } end
  local gradient, weights = {}, { 3, 3, 2 }
  for i, hex in ipairs(colors) do
    for _ = 1, weights[i] do gradient[#gradient + 1] = "rgba(" .. hex .. "ee)" end
  end
  hl.config({ general = { col = { active_border = { colors = gradient, angle = 45 }, inactive_border = "rgba(" .. style.inactive .. "aa)" } } })

  _G.caelestia_border_angle = _G.caelestia_border_angle or 45
  function _G.caelestia_border_tick()
    _G.caelestia_border_angle = (_G.caelestia_border_angle + 360 * 33 / 13330) % 360
    hl.config({ general = { col = { active_border = { colors = gradient, angle = _G.caelestia_border_angle } } } })
  end
  if not _G.caelestia_border_timer then
    _G.caelestia_border_timer = hl.timer(function()
      if _G.caelestia_border_tick then _G.caelestia_border_tick() end
    end, { timeout = 33, type = "repeat" })
  end
else
  _G.caelestia_border_tick = nil
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
