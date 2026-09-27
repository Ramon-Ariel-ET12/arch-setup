-- General settings, theming, decorations, animations and layouts.
local colors = require("generated.color")

hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 18,
		border_size = 2,
		layout = "scrolling",
		resize_on_border = false,
		allow_tearing = false,

		col = {
			active_border = { colors = { colors.primary, colors.primary .. "ee" }, angle = 45 },
			inactive_border = colors.outline,
		},
	},
})

hl.config({
	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		force_default_wallpaper = 0,
	},
})

hl.config({
	cursor = {
		default_monitor = "",
		no_hardware_cursors = false,
	},
})

hl.config({
	render = {
		direct_scanout = 1,
	},
})

hl.config({
	decoration = {
		rounding = 8,
		rounding_power = 2,
		active_opacity = 0.92,
		inactive_opacity = 0.82,
		shadow = {
			enabled = true,
			range = 10,
			render_power = 3,
			color = colors.surface .. "55",
		},
		blur = {
			enabled = true,
			size = 6,
			passes = 2,
			vibrancy = 0.10,
			noise = 0.01,
			new_optimizations = true,
			ignore_opacity = false,
		},
	},
})

hl.config({
	animations = {
		enabled = true,
	},
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 1.0, bezier = "almostLinear" })
hl.animation({ leaf = "border", enabled = true, speed = 0.8, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 1.0, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 0.55, bezier = "quick", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 0.45, bezier = "quick", style = "popin 85%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 0.25, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 0.2, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 0.35, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 0.7, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 0.5, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 0.35, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 0.45, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 0.35, bezier = "almostLinear" })
hl.animation({
	leaf = "workspacesIn",
	enabled = true,
	speed = 0.8,
	bezier = "almostLinear",
	style = "slidefade 15%",
})
hl.animation({
	leaf = "workspacesOut",
	enabled = true,
	speed = 0.7,
	bezier = "almostLinear",
	style = "slidefade 15%",
})
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 0.7, bezier = "almostLinear", style = "slidevert" })

hl.config({
	dwindle = {
		preserve_split = true,
	},
	master = {
		new_status = "slave",
		new_on_top = true,
	},
	scrolling = {
		fullscreen_on_one_column = true,
		follow_focus = true,
		direction = "right",
		column_width = 1.0,
	},
})
