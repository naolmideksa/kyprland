-- Minimizer Module — Native KDE Plasma Window Management
-- Powered by native C++ Kyprland plugin (kyprland.so)
-- Zero workspace switching, zero cursor warping, native in-process state

local M = {}

function M.minimize(addr)
    if hl.plugin and hl.plugin.kyprland and hl.plugin.kyprland.minimize then
        return hl.plugin.kyprland.minimize(addr or "")
    else
        return hl.dispatch(hl.dsp.exec_raw("kypr_minimize", addr or ""))
    end
end

function M.restore(addr)
    if hl.plugin and hl.plugin.kyprland and hl.plugin.kyprland.restore then
        return hl.plugin.kyprland.restore(addr or "")
    else
        return hl.dispatch(hl.dsp.exec_raw("kypr_restore", addr or ""))
    end
end

function M.toggle(addr)
    if hl.plugin and hl.plugin.kyprland and hl.plugin.kyprland.toggle then
        return hl.plugin.kyprland.toggle(addr or "")
    else
        return hl.dispatch(hl.dsp.exec_raw("kypr_toggle", addr or ""))
    end
end

function M.is_minimized(addr)
    if not addr then return false end
    if hl.plugin and hl.plugin.kyprland and hl.plugin.kyprland.is_minimized then
        return hl.plugin.kyprland.is_minimized(addr)
    end
    local a = addr:lower()
    if not a:match("^0x") then a = "0x" .. a end
    for _, win in ipairs(hl.get_windows()) do
        if win.address and win.address:lower() == a then
            return win.hidden == true
        end
    end
    return false
end

function M.restore_last()
    return M.restore("")
end

local desktop_hidden_addrs = {}

function M.toggle_desktop()
    local ws = hl.get_active_workspace()
    local ws_id = ws and ws.id

    if #desktop_hidden_addrs > 0 then
        for _, addr in ipairs(desktop_hidden_addrs) do
            M.restore(addr)
        end
        desktop_hidden_addrs = {}
        return
    end

    local to_hide = {}
    for _, win in ipairs(hl.get_windows()) do
        if win.workspace and win.workspace.id == ws_id and not win.hidden then
            table.insert(to_hide, win.address)
        end
    end

    if #to_hide > 0 then
        for _, addr in ipairs(to_hide) do
            M.minimize(addr)
            table.insert(desktop_hidden_addrs, addr)
        end
    end
end

return M
