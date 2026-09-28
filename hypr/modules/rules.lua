-- Window rules

hl.window_rule({
	name = "suppress-maximize-events",
	match = {
		class = ".*",
	},
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
	match = {
		class = "hyprland-run",
	},
	move = "20 monitor_h-120",
	float = true,
})

--
-- Games
--
hl.window_rule({
	name = "confine-pointer-games",
	match = {
		content = "^game$",
	},
	confine_pointer = true,
})

--
-- Workspace rules
--
-- hl.workspace_rule({
-- 	workspace = "w[tv1]",
-- 	gaps_out = 0,
-- 	gaps_in = 0,
-- })
--
-- hl.workspace_rule({
-- 	workspace = "f[1]",
-- 	gaps_out = 0,
-- 	gaps_in = 0,
-- })

--
-- Layer rules
--
hl.layer_rule({
	name = "ags-popup-anim",
	match = {
		namespace = "^(launcher|clipboard|notifcenter|notifdetail|monitors|wallpaper|binds|calendar|osd|notifications)$",
	},
	animation = "popin 85%",
})
