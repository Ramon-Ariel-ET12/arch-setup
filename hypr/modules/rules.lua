-- Window rules
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})

-- Games (wlr-content-type = "game"): lock the mouse cursor inside the game
-- window so it can't escape to the desktop (i.e. windowed games/menus).
-- Per official docs → confine_pointer window rule.
hl.window_rule({
	name = "confine-pointer-games",
	match = { content = "^game$" },
	confine_pointer = true,
})

-- Workspace rules
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })

-- Layer rules
-- Every AGS transient surface is treated like a window: same `popin 85%`
-- open animation as `windowsIn` in general.lua, so launcher, cards,
-- pickers, OSD and toasts all appear identically. The bar is persistent
-- chrome (not a popup) and inherits the global layers fade — no rule for it.
-- GTK cannot animate a layer-surface unmap, so hide animations come from the
-- compositor's layersOut. Note: Gtk.Popover bubbles (bar audio/network/bt/
-- media) live inside the bar window, not as layer surfaces — their appear
-- animation is the in-app `Reveal` fade in components/Popover.tsx.
hl.layer_rule({
    name = "ags-popup-anim",
    match = { namespace = "^(launcher|clipboard|notifcenter|notifdetail|monitors|wallpaper|binds|calendar|osd|notifications)$" },
    animation = "popin 85%",
})
