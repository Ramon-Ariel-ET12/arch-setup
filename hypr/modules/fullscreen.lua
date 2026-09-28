local Hy = _G.Hy

local FS_NONE = 0
local FS_FULL = 2

-- Applications allowed to keep true fullscreen.
local APP_WHITELIST = {
	["com.gabm.satty"] = true,
	["org.satty.satty"] = true,
}

-- Windows whose next fullscreen event was triggered by
-- SUPER + SHIFT + F.
local manual_fullscreen = {}

local function set_fullscreen(w, internal, client)
	if not w then
		return
	end

	hl.dispatch(hl.dsp.window.fullscreen_state({
		window = w,
		internal = internal,
		client = client,
		action = "set",
	}))
end

local function is_whitelisted(w)
	return w and (APP_WHITELIST[w.initial_class] == true or APP_WHITELIST[w.class] == true)
end

-- SUPER + F
-- 0/0 -> 0/2
-- 0/2 -> 0/0
-- 2/2 -> 0/0
hl.bind(
	Hy.mod .. " + F",
	hl.dsp.window.fullscreen_state({
		internal = FS_NONE,
		client = FS_FULL,
		action = "toggle",
	}),
	{
		description = "Toggle fake fullscreen",
	}
)

-- SUPER + SHIFT + F
-- 0/0 -> 2/2
-- 0/2 -> 2/2
-- 2/2 -> 0/0
hl.bind(Hy.mod .. " + SHIFT + F", function()
	local w = hl.get_active_window()
	if not w then
		return
	end

	local addr = w.address

	if w.fullscreen == FS_FULL then
		set_fullscreen(w, FS_NONE, FS_NONE)
		return
	end

	if addr then
		manual_fullscreen[addr] = true
	end

	set_fullscreen(w, FS_FULL, FS_FULL)
end, {
	description = "Toggle true fullscreen",
})

-- Downgrade client-requested true fullscreen to fake fullscreen.
hl.on("window.fullscreen", function(w)
	if not w or not w.address then
		return
	end

	local addr = w.address

	-- Fullscreen transition initiated by our keybind.
	if manual_fullscreen[addr] then
		manual_fullscreen[addr] = nil
		return
	end

	-- Whitelisted applications may use true fullscreen.
	if is_whitelisted(w) then
		return
	end

	-- All other client requests become fake fullscreen.
	if w.fullscreen == FS_FULL then
		set_fullscreen(w, FS_NONE, FS_FULL)
	end
end)

-- Cleanup.
hl.on("window.destroy", function(w)
	local addr = w and w.address
	if addr then
		manual_fullscreen[addr] = nil
	end
end)
