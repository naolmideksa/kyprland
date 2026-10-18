-- Window Snapping Module (KDE / Windows style)
-- Universal snapping for ALL applications (current and future)

local M = {}
local minimizer = require("config.minimizer")

-- Store un-snapped window geometries for restore
local prev_geom = {}

local BAR_HEIGHT = 28  -- hyprbars titlebar height (matches bar_height in plugins.lua)

local function get_work_area()
    local m = hl.get_active_monitor()
    if not m then return nil end

    local mx = m.x
    local mw = m.width
    local mh = m.height

    local half_w = math.floor(mw / 2)
    local other_w = mw - half_w
    local half_h = math.floor(mh / 2)
    local other_h = mh - half_h

    -- Full height: window client placed so titlebar begins at top of screen (0..mh)
    local full_y = m.y + BAR_HEIGHT
    local full_h = mh - BAR_HEIGHT

    -- Top quarter: container occupies 0..half_h
    local top_y = m.y + BAR_HEIGHT
    local top_h = half_h - BAR_HEIGHT

    -- Bottom quarter: container occupies half_h..mh
    local bottom_y = m.y + half_h + BAR_HEIGHT
    local bottom_h = other_h - BAR_HEIGHT

    return {
        mx = mx,
        mw = mw,
        half_w = half_w,
        other_w = other_w,

        -- Full height (left/right/maximize)
        my = full_y,
        mh = full_h,

        -- Quarters
        top_y = top_y,
        top_h = top_h,

        bottom_y = bottom_y,
        bottom_h = bottom_h,
    }
end

local function apply_geom(w, x, y, width, height)
    -- If window was fullscreen, unfullscreen first
    if w.fullscreen and w.fullscreen ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = 0 }))
    end

    -- If not floating, float it
    if not w.floating then
        hl.dispatch(hl.dsp.window.float({ action = "on", address = w.address }))
    end

    hl.dispatch(hl.dsp.window.resize({ x = width, y = height, relative = false }))
    hl.dispatch(hl.dsp.window.move({ x = x, y = y, relative = false }))
end

function M.snap_left()
    local w = hl.get_active_window()
    if not w or not w.address then return end
    local area = get_work_area()
    if not area then return end

    if not prev_geom[w.address] then
        prev_geom[w.address] = { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
    end

    apply_geom(w, area.mx, area.my, area.half_w, area.mh)
end

function M.snap_right()
    local w = hl.get_active_window()
    if not w or not w.address then return end
    local area = get_work_area()
    if not area then return end

    if not prev_geom[w.address] then
        prev_geom[w.address] = { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
    end

    apply_geom(w, area.mx + area.half_w, area.my, area.other_w, area.mh)
end

function M.snap_top_left()
    local w = hl.get_active_window()
    if not w or not w.address then return end
    local area = get_work_area()
    if not area then return end

    if not prev_geom[w.address] then
        prev_geom[w.address] = { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
    end

    apply_geom(w, area.mx, area.top_y, area.half_w, area.top_h)
end

function M.snap_bottom_left()
    local w = hl.get_active_window()
    if not w or not w.address then return end
    local area = get_work_area()
    if not area then return end

    if not prev_geom[w.address] then
        prev_geom[w.address] = { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
    end

    apply_geom(w, area.mx, area.bottom_y, area.half_w, area.bottom_h)
end

function M.snap_top_right()
    local w = hl.get_active_window()
    if not w or not w.address then return end
    local area = get_work_area()
    if not area then return end

    if not prev_geom[w.address] then
        prev_geom[w.address] = { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
    end

    apply_geom(w, area.mx + area.half_w, area.top_y, area.other_w, area.top_h)
end

function M.snap_bottom_right()
    local w = hl.get_active_window()
    if not w or not w.address then return end
    local area = get_work_area()
    if not area then return end

    if not prev_geom[w.address] then
        prev_geom[w.address] = { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
    end

    apply_geom(w, area.mx + area.half_w, area.bottom_y, area.other_w, area.bottom_h)
end

function M.snap_up()
    local w = hl.get_active_window()
    if not w or not w.address then
        minimizer.restore_last()
        return
    end
    local area = get_work_area()
    if not area then return end

    local tol = 50
    local is_left = math.abs(w.at.x - area.mx) <= tol
    local is_right = math.abs((w.at.x + w.size.x) - (area.mx + area.mw)) <= tol or math.abs(w.at.x - (area.mx + area.half_w)) <= tol

    -- Contextual: if window is on the left -> snap Top-Left
    if is_left and not is_right then
        M.snap_top_left()
    -- If on the right -> snap Top-Right
    elseif is_right and not is_left then
        M.snap_top_right()
    else
        -- Maximize to full screen height
        if not prev_geom[w.address] then
            prev_geom[w.address] = { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
        end
        apply_geom(w, area.mx, area.my, area.mw, area.mh)
    end
end

function M.snap_down()
    local w = hl.get_active_window()
    if not w or not w.address then
        minimizer.restore_last()
        return
    end
    local area = get_work_area()
    if not area then return end

    local tol = 50
    local is_left = math.abs(w.at.x - area.mx) <= tol
    local is_right = math.abs((w.at.x + w.size.x) - (area.mx + area.mw)) <= tol or math.abs(w.at.x - (area.mx + area.half_w)) <= tol
    local is_maximized = math.abs(w.size.x - area.mw) <= tol and math.abs(w.size.y - area.mh) <= tol

    -- If maximized -> restore
    if is_maximized then
        local prev = prev_geom[w.address]
        if prev then
            apply_geom(w, prev.x, prev.y, prev.w, prev.h)
            prev_geom[w.address] = nil
            return
        end
    end

    -- Contextual: if window is on the left -> snap Bottom-Left
    if is_left and not is_right then
        M.snap_bottom_left()
    -- If window is on the right -> snap Bottom-Right
    elseif is_right and not is_left then
        M.snap_bottom_right()
    else
        local prev = prev_geom[w.address]
        if prev then
            apply_geom(w, prev.x, prev.y, prev.w, prev.h)
            prev_geom[w.address] = nil
        else
            minimizer.minimize(w.address)
        end
    end
end

function M.toggle_maximize(addr)
    local w = nil
    if addr and addr ~= "" then
        local a = addr:lower()
        if not a:match("^0x") then a = "0x" .. a end
        for _, win in ipairs(hl.get_windows()) do
            if win.address and win.address:lower() == a then
                w = win
                break
            end
        end
    end
    if not w then w = hl.get_active_window() end
    if not w or not w.address then return end
    local area = get_work_area()
    if not area then return end

    local tol = 50
    local is_maximized = math.abs(w.size.x - area.mw) <= tol and math.abs(w.size.y - area.mh) <= tol and math.abs(w.at.y - area.my) <= tol

    if is_maximized then
        local prev = prev_geom[w.address]
        if prev then
            apply_geom(w, prev.x, prev.y, prev.w, prev.h)
            prev_geom[w.address] = nil
        end
    else
        if not prev_geom[w.address] then
            prev_geom[w.address] = { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
        end
        apply_geom(w, area.mx, area.my, area.mw, area.mh)
    end
end

return M
