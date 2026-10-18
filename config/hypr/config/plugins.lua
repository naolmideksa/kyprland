hl.plugin.load("/home/naolmid/.config/hypr/plugins/hyprbars.so")
hl.plugin.load("/home/naolmid/.config/hypr/plugins/kyprland.so")

hl.config({
    plugin = {
        hyprbars = {
            bar_height = 28,
            bar_color = "rgba(181825ee)",
            bar_title_enabled = false, -- Plain titlebar: no titles or descriptions
            icon_on_hover = true,      -- Clean solid colored dots, symbols on hover
            bar_buttons_alignment = "right",
            bar_part_of_window = false,
            bar_precedence_over_border = true,
            bar_padding = 12,
            bar_button_padding = 6,    -- Balanced spacing between buttons
            on_double_click = "hyprctl eval \"require('config.snapping').toggle_maximize()\"",
        },
    },
})

-- Buttons (Added Right-to-Left: Red/Close, Green/Maximize, Yellow/Minimize)

-- 1. Red: Close window (Rightmost)
hl.plugin.hyprbars.add_button({
    bg_color = "rgb(ed5454)",
    fg_color = "rgb(ffffff)",
    size = 12,
    icon = "✕",
    action = "hyprctl eval \"hl.dispatch(hl.dsp.window.close())\"",
})

-- 2. Green: Maximize / Restore window (Middle)
hl.plugin.hyprbars.add_button({
    bg_color = "rgb(38cd56)",
    fg_color = "rgb(ffffff)",
    size = 12,
    icon = "□",
    action = "hyprctl eval \"require('config.snapping').toggle_maximize()\"",
})

-- 3. Yellow: Minimize window (Leftmost of the 3)
hl.plugin.hyprbars.add_button({
    bg_color = "rgb(fdbb2d)",
    fg_color = "rgb(ffffff)",
    size = 12,
    icon = "−",
    action = "hyprctl eval \"require('config.minimizer').minimize()\"",
})
