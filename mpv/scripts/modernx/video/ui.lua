-- modernx/video/ui.lua
-- Video mode UI: the existing bottom OSC, unchanged. activate() only
-- (re)binds the video key; rendering is driven by the shared tick path.
-- Registered with ui/manager.lua as the 'video' mode.

local M = {}

function M.activate()
end

function M.deactivate()
end

return M
