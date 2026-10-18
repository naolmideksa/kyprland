local mainMod = "SUPER"
local noctCall = "noctalia msg "
local launchPrefix = "uwsm app -- " -- if you are not using UWSM, make this empty (e.g. "")

-- AZERTY fix: the number-row keys emit symbols (& é " ' ...) without Shift, so
-- binding to the digit characters fails. Bind by physical keycode instead.
-- Digit d -> evdev keycode: 1..9 => 10..18, 0 => 19
local function digitCode(d)
    return "code:" .. (d == 0 and 19 or (9 + d))
end

local snap = require("config.snapping")
local minimizer = require("config.minimizer")

---------------------------
---- WINDOW MANAGEMENT ----
---------------------------

-- 1. Close & Kill Window (KDE Plasma standard)
hl.bind("ALT + F4",                   hl.dsp.window.close())
hl.bind(mainMod .. " + Q",            hl.dsp.window.close())
hl.bind("CONTROL + ALT + Escape",     hl.dsp.exec_cmd("hyprctl kill"))

-- 2. Maximize & Restore (KDE Plasma standard)
hl.bind(mainMod .. " + Page_Up",      function() snap.toggle_maximize() end)
hl.bind(mainMod .. " + Up",           function() snap.snap_up() end)

-- 3. Minimize Window (KDE Plasma standard)
hl.bind(mainMod .. " + Page_Down",    function() minimizer.minimize() end)
hl.bind(mainMod .. " + Down",         function() snap.snap_down() end)
hl.bind(mainMod .. " + M",            function() minimizer.toggle() end)
hl.bind(mainMod .. " + SHIFT + M",    function() minimizer.restore_last() end)

-- 4. Show Desktop (KDE Plasma standard Meta+D)
hl.bind(mainMod .. " + D",            function() minimizer.toggle_desktop() end)

-- 5. Fullscreen Toggle (KDE standard F11 & Meta+F)
hl.bind("F11",                        hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + F",            hl.dsp.window.fullscreen())

-- 6. Window Snapping / Quick Tile (KDE standard Meta + Arrow keys)
hl.bind(mainMod .. " + Left",         function() snap.snap_left() end)
hl.bind(mainMod .. " + Right",        function() snap.snap_right() end)

-- Corner snapping (Alt + Direction or Keypad)
hl.bind(mainMod .. " + ALT + Up",     function() snap.snap_top_left() end)
hl.bind(mainMod .. " + ALT + Right",  function() snap.snap_top_right() end)
hl.bind(mainMod .. " + ALT + Left",   function() snap.snap_bottom_left() end)
hl.bind(mainMod .. " + ALT + Down",   function() snap.snap_bottom_right() end)
hl.bind(mainMod .. " + KP_Home",      function() snap.snap_top_left() end)
hl.bind(mainMod .. " + KP_Prior",     function() snap.snap_top_right() end)
hl.bind(mainMod .. " + KP_End",       function() snap.snap_bottom_left() end)
hl.bind(mainMod .. " + KP_Next",      function() snap.snap_bottom_right() end)

-- 7. Window Switching & Overview (KDE Plasma standard)
hl.bind("ALT + Tab",                  hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + Tab",          hl.dsp.window.cycle_next("prev"))
-- Meta+W = Present Windows / Overview (KDE standard, NOT Firefox!)
hl.bind(mainMod .. " + W",            hl.dsp.exec_cmd(noctCall .. "window-switcher"))
hl.bind(mainMod .. " + Tab",          hl.dsp.exec_cmd(noctCall .. "window-switcher"))

-- Move active window to monitors
hl.bind(mainMod .. " + SHIFT + " .. digitCode(1),     hl.dsp.window.move({ monitor = MONITOR1 }))
hl.bind(mainMod .. " + SHIFT + " .. digitCode(2),     hl.dsp.window.move({ monitor = MONITOR2 }))
hl.bind(mainMod .. " + SHIFT + " .. digitCode(3),     hl.dsp.window.move({ monitor = MONITOR3 }))
hl.bind(mainMod .. " + SHIFT + mouse_up",             hl.dsp.window.move({ monitor   = "-1" }))
hl.bind(mainMod .. " + SHIFT + mouse_down",           hl.dsp.window.move({ monitor   = "+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Right",      hl.dsp.window.move({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Left",       hl.dsp.window.move({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_up",   hl.dsp.window.move({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "m+1" }))
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + SHIFT + CONTROL + " .. digitCode(key), hl.dsp.window.move({ workspace = "m~" .. i }))
end
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + SHIFT + ALT + " .. digitCode(key), hl.dsp.window.move({ workspace = "m~" .. i, follow = false }))
end

-- Move & Resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())
hl.bind("ALT + mouse:272",         hl.dsp.window.drag())
hl.bind("ALT + mouse:273",         hl.dsp.window.resize())

-- Zoom
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 3.0 then
        hl.config({ cursor = { zoom_factor = 3.0 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind(mainMod .. " + Minus",   function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + Plus",    function() zoomfunction(0.3) end,  { repeating = true })
hl.bind(mainMod .. " + code:82", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + code:86", function() zoomfunction(0.3) end,  { repeating = true })

--------------------------------
---- LAUNCHERS & SYSTEM OPS ----
--------------------------------

-- Application Launcher / KRunner (KDE Plasma standard)
hl.bind(mainMod .. " + Space",      hl.dsp.exec_cmd(noctCall .. "panel-toggle launcher"))
hl.bind("ALT + Space",              hl.dsp.exec_cmd(noctCall .. "panel-toggle launcher"))
hl.bind("ALT + F1",                 hl.dsp.exec_cmd(noctCall .. "panel-toggle launcher"))

-- Terminal (KDE Plasma standard Ctrl+Alt+T)
hl.bind("CONTROL + ALT + T",        hl.dsp.exec_cmd(launchPrefix .. TERMINAL))
hl.bind(mainMod .. " + Return",     hl.dsp.exec_cmd(launchPrefix .. TERMINAL))

-- File Manager Dolphin (KDE Plasma standard Meta+E)
hl.bind(mainMod .. " + E",          hl.dsp.exec_cmd(launchPrefix .. FILE_MANAGER))

-- System Activity / Task Manager (KDE Plasma standard Ctrl+Shift+Esc)
hl.bind("CONTROL + SHIFT + Escape", hl.dsp.exec_cmd(launchPrefix .. TERMINAL .. " -e btop"))

-- System Settings (KDE Plasma 6 standard Meta+I)
hl.bind(mainMod .. " + I",          hl.dsp.exec_cmd(noctCall .. "settings-toggle"))

-- Lock Screen (KDE Plasma standard Meta+L & Ctrl+Alt+L)
hl.bind(mainMod .. " + L",          hl.dsp.exec_cmd(noctCall .. "session lock"))
hl.bind("CONTROL + ALT + L",        hl.dsp.exec_cmd(noctCall .. "session lock"))

-- Leave / Shutdown / Session Menu (KDE Plasma standard Ctrl+Alt+Del)
hl.bind("CONTROL + ALT + Delete",   hl.dsp.exec_cmd(noctCall .. "panel-toggle session"))

-- Clipboard (KDE Plasma 6 Klipper Meta+V)
hl.bind(mainMod .. " + V",          hl.dsp.exec_cmd(noctCall .. "panel-toggle clipboard"))

-- Emoji Picker (KDE Plasma standard Meta+.)
hl.bind(mainMod .. " + period",     hl.dsp.exec_cmd(noctCall .. "panel-toggle launcher /emo"))

-- Notifications / Control Center (KDE Plasma standard Meta+N)
hl.bind(mainMod .. " + N",          hl.dsp.exec_cmd(noctCall .. "panel-toggle control-center notifications"))

-- Dedicated Calculator key if present on keyboard
hl.bind("XF86Calculator",           hl.dsp.exec_cmd(launchPrefix .. CALCULATOR))

---------------------------
---- HARDWARE CONTROLS ----
---------------------------

-- Audio
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(noctCall .. "volume-up"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(noctCall .. "volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(noctCall .. "volume-mute"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(noctCall .. "mic-mute"),    { locked = true })

-- Media
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(noctCall .. "media toggle"),   { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(noctCall .. "media toggle"),   { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(noctCall .. "media next"),     { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(noctCall .. "media previous"), { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(noctCall .. "brightness-up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(noctCall .. "brightness-down"), { locked = true, repeating = true })

-------------------
---- UTILITIES ----
-------------------

-- Screenshots (Spectacle standard)
hl.bind("Print",               hl.dsp.exec_cmd(noctCall .. "screenshot-region"))
hl.bind("SHIFT + Print",       hl.dsp.exec_cmd(noctCall .. "screenshot-region"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(noctCall .. "screenshot-fullscreen"))
hl.bind("CONTROL + Print",     hl.dsp.exec_cmd(noctCall .. "screenshot-fullscreen"))

-- Color Picker
hl.bind(mainMod .. " + P",     hl.dsp.exec_cmd("hyprpicker -a -n"))

-- Wallpaper
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(noctCall .. "panel-toggle wallpaper"))

-------------------------------
---- WORKSPACES & MONITORS ----
-------------------------------

-- Switch to Virtual Desktops (KDE Plasma standard Ctrl+F1..F4)
for i = 1, 4 do
    hl.bind("CONTROL + F" .. i, hl.dsp.focus({ workspace = i }))
end

-- Focus on monitors
hl.bind(mainMod .. " + " .. digitCode(1), hl.dsp.focus({ monitor = MONITOR1 }))
hl.bind(mainMod .. " + " .. digitCode(2), hl.dsp.focus({ monitor = MONITOR2 }))
hl.bind(mainMod .. " + " .. digitCode(3), hl.dsp.focus({ monitor = MONITOR3 }))

-- Focus on workspace number
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + ALT + " .. digitCode(key),     hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + CONTROL + " .. digitCode(key), hl.dsp.focus({ workspace = "m~" .. i }))
end

local function cycle_safe_ws(delta)
    local cur = hl.get_active_workspace()
    local cur_id = (cur and cur.id) or 1
    local next_id = cur_id + delta
    if next_id < 1 then next_id = 1 end
    if next_id >= 99 then next_id = cur_id end
    hl.dispatch(hl.dsp.focus({ workspace = next_id }))
end

-- Move to adjacent workspaces (KDE standard Meta + Ctrl + Left / Right)
hl.bind(mainMod .. " + CONTROL + Right",       function() cycle_safe_ws(1) end)
hl.bind(mainMod .. " + CONTROL + Left",        function() cycle_safe_ws(-1) end)
hl.bind(mainMod .. " + CONTROL + Down",        hl.dsp.focus({ workspace = "emptym" }))

-- Scroll through existing workspaces & monitors
hl.bind(mainMod .. " + mouse_down",           function() cycle_safe_ws(-1) end)
hl.bind(mainMod .. " + mouse_up",             function() cycle_safe_ws(1) end)
hl.bind(mainMod .. " + CONTROL + mouse_up",   function() cycle_safe_ws(-1) end)
hl.bind(mainMod .. " + CONTROL + mouse_down", function() cycle_safe_ws(1) end)

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }))
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special())
