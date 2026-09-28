-- See https://wiki.hypr.land/Configuring/Basics/Binds/ for more
local Hy = _G.Hy
local hs = require("hyprsplit")

-- Applications
hl.bind(Hy.mod .. " + Q", hl.dsp.exec_cmd(Hy.terminal), { description = "Open terminal" })
hl.bind(
	Hy.mod .. " + M",
	hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"),
	{ description = "Exit session" }
)
hl.bind(Hy.mod .. " + E", hl.dsp.exec_cmd(Hy.file_manager), { description = "Open file manager" })
hl.bind(Hy.mod .. " + R", hl.dsp.exec_cmd("ags toggle launcher"), { description = "Toggle launcher" })
hl.bind(Hy.mod .. " + V", hl.dsp.exec_cmd("ags toggle clipboard"), { description = "Toggle clipboard" })
hl.bind(Hy.mod .. " + W", hl.dsp.exec_cmd("ags toggle wallpaper"), { description = "Toggle wallpaper picker" })
hl.bind(Hy.mod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Lock session" })
hl.bind(Hy.mod .. " + SHIFT + slash", hl.dsp.exec_cmd("ags toggle binds"), { description = "Toggle keybinds helper" })

-- Windows
hl.bind(Hy.mod .. " + C", hl.dsp.window.close(), { description = "Close window" })
hl.bind(Hy.mod .. "+ SHIFT + C", hl.dsp.window.kill(), { description = "Force close window" })
hl.bind(Hy.mod .. " + SHIFT + Q", hl.dsp.exit(), { description = "Exit Hyprland" })
hl.bind(Hy.mod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle float" })
hl.bind(Hy.mod .. " + P", hl.dsp.window.pseudo(), { description = "Toggle pseudo (tiling)" })
hl.bind(Hy.mod .. " + J", hl.dsp.layout("togglesplit"), { description = "Toggle split direction" })

hl.bind(Hy.mod .. " + ALT + G", hl.dsp.layout("grabroguewindows"), { description = "Grab rogue windows" })

hl.bind(Hy.mod .. " + left", hl.dsp.focus({ direction = "left" }), { description = "Focus left" })
hl.bind(Hy.mod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
hl.bind(Hy.mod .. " + up", hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
hl.bind(Hy.mod .. " + down", hl.dsp.focus({ direction = "down" }), { description = "Focus down" })

hl.bind(Hy.mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }), { description = "Move window left" })
hl.bind(Hy.mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }), { description = "Move window right" })
hl.bind(Hy.mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }), { description = "Move window up" })
hl.bind(Hy.mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }), { description = "Move window down" })

hl.bind(Hy.mod .. " + CTRL + left", hl.dsp.window.swap({ direction = "left" }), { description = "Swap left" })
hl.bind(Hy.mod .. " + CTRL + right", hl.dsp.window.swap({ direction = "right" }), { description = "Swap right" })
hl.bind(Hy.mod .. " + CTRL + up", hl.dsp.window.swap({ direction = "up" }), { description = "Swap up" })
hl.bind(Hy.mod .. " + CTRL + down", hl.dsp.window.swap({ direction = "down" }), { description = "Swap down" })

hl.bind(Hy.mod .. " + ALT + left", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { description = "Shrink window left" })
hl.bind(Hy.mod .. " + ALT + right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }), { description = "Grow window right" })
hl.bind(Hy.mod .. " + ALT + up", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { description = "Shrink window up" })
hl.bind(Hy.mod .. " + ALT + down", hl.dsp.window.resize({ x = 0, y = 20, relative = true }), { description = "Grow window down" })

-- Workspaces (hyprsplit — per-monitor)
hl.bind(Hy.mod .. " + S", hl.dsp.workspace.toggle_special("magic"), { description = "Toggle special workspace" })
hl.bind(Hy.mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }), { description = "Move to special workspace" })
hl.bind(Hy.mod .. " + D", hs.dsp.workspace.swap_monitors({ monitor1 = "current", monitor2 = "+1" }), { description = "Swap monitors" })
hl.bind(Hy.mod .. " + G", hs.dsp.grab_rogue_windows(), { description = "Grab rogue windows" })

for i = 1, 10 do
	local key = i % 10
	hl.bind(Hy.mod .. " + " .. key, hs.dsp.focus({ workspace = i }), { description = "Focus workspace " .. i })
	hl.bind(Hy.mod .. " + SHIFT + " .. key, hs.dsp.window.move({ workspace = i, follow = false }), { description = "Move to workspace " .. i })
end

hl.bind(Hy.mod .. " + bracketleft", hs.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace" })
hl.bind(Hy.mod .. " + bracketright", hs.dsp.focus({ workspace = "e+1" }), { description = "Next workspace" })

-- Media
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true, description = "Volume up" }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true, description = "Volume down" }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true, description = "Toggle mute" }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true, description = "Toggle microphone mute" }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true, description = "Brightness down" })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/Pause" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/Pause" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous track" })

-- Mouse
hl.bind(Hy.mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(Hy.mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(Hy.mod .. " + mouse_down", hs.dsp.focus({ workspace = "e+1" }))
hl.bind(Hy.mod .. " + mouse_up", hs.dsp.focus({ workspace = "e-1" }))

-- Screenshots ------------------------------------------------------------
-- grim + satty: full-screen capture shown in Satty, opened true fullscreen
-- (whitelisted in fullscreen.lua; animation disabled in rules.lua).
-- Ctrl+S is the only finish key: it saves to ~/Pictures/Screenshots, closes
-- Satty, and the script copies that file to the clipboard. Satty's own
-- Ctrl+C is redundant by design, not a missing keybind. Esc cancels.
-- Logic lives in hypr/scripts/screenshot.sh so the shell does the
-- piping and the bind stays declarative.
hl.bind(
	"Print",
	hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/screenshot.sh"),
	{ description = "Screenshot full screen → Satty" }
)
