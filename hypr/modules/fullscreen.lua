-- Fullscreen policy.
-- Apps requesting fullscreen themselves (players, F11, games...) get fake
-- fullscreen: the client believes it's fullscreen but the window stays
-- normal. True fullscreen is only reachable via SUPER+SHIFT+F, which
-- whitelists its target below; SUPER+F is a manual fake-fullscreen toggle.
local Hy = _G.Hy

-- Fullscreen::eFullscreenMode (Hyprland FullscreenTypes.hpp)
local FS_NONE       = 0
local FS_FULLSCREEN = 2

local FAKE_FULLSCREEN = { internal = FS_NONE, client = FS_FULLSCREEN }
local TRUE_FULLSCREEN = { internal = FS_FULLSCREEN, client = FS_FULLSCREEN }

-- Addresses of windows the user fullscreened via SUPER+SHIFT+F; the
-- interceptor lets those through and downgrades everything else.
local userFullscreen = {}

local function applyFullscreenState(state, action, window)
	hl.dispatch(hl.dsp.window.fullscreen_state({
		internal = state.internal,
		client   = state.client,
		action   = action,
		window   = window,
	}))
end

hl.bind(
	Hy.mod .. " + F",
	hl.dsp.window.fullscreen_state({ internal = FS_NONE, client = FS_FULLSCREEN, action = "toggle" }),
	{ description = "Toggle fake fullscreen" }
)

hl.bind(
	Hy.mod .. " + SHIFT + F",
	function()
		local w = hl.get_active_window()
		if w == nil then
			return
		end
		userFullscreen[w.address] = true
		applyFullscreenState(TRUE_FULLSCREEN, "toggle")
	end,
	{ description = "Toggle fullscreen" }
)

hl.on("window.fullscreen", function(w)
	if w == nil then
		return
	end
	if userFullscreen[w.address] then
		userFullscreen[w.address] = nil
		return
	end
	-- Satty requests fullscreen itself when launched with --fullscreen
	-- (screenshot flow): let it through, keep the downgrade for the rest.
	if w.class == "com.gabm.satty" then
		return
	end
	if w.fullscreen == FS_FULLSCREEN then
		applyFullscreenState(FAKE_FULLSCREEN, "set", w)
	end
end)

hl.on("window.destroy", function(w)
	-- at destroy the window object is already expired: w.address is nil,
	-- and userFullscreen[nil] = nil would raise "table index is nil"
	local addr = w ~= nil and w.address
	if addr ~= nil then
		userFullscreen[addr] = nil
	end
end)
