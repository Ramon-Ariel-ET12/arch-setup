-- modernx/ui/manager.lua
-- Coordinates high-level UI mode transitions (video <-> image).
-- Owns state.ui.mode; feature modules only implement activate/deactivate.

local mp = require 'mp'
local msg = require 'mp.msg'
local state = require './state'
local media = require './core.media'
local tick = require './core.tick'

local M = {}

local modes = {} -- name -> module with activate/deactivate

function M.register(name, mod)
    modes[name] = mod
end

-- switch mode if different; idempotent and safe to call repeatedly.
function M.set_mode(name)
    if state.ui.mode == name and modes[name] then return end
    local old = modes[state.ui.mode]
    if old and old.deactivate then
        local ok, err = pcall(old.deactivate)
        if not ok then msg.error('ui manager: deactivate failed: ' .. tostring(err)) end
    end
    state.ui.mode = name
    local new = modes[name]
    if new and new.activate then
        local ok, err = pcall(new.activate)
        if not ok then msg.error('ui manager: activate failed: ' .. tostring(err)) end
    end
    -- the element tree changed: rebuild + redraw on the next tick.
    tick.request_init()
end

function M.mode()
    return state.ui.mode
end

-- refresh state.media from mpv and route to the matching UI mode.
function M.update_media_state()
    local t = media.current_type()
    state.media.type = t
    state.media.path = media.current_path()
    local entries = media.playlist_entries()
    state.media.count = #entries
    state.media.index = media.playlist_index(entries)
    if t == media.TYPE_IMAGE then
        M.set_mode('image')
    else
        M.set_mode('video')
    end
end

return M
