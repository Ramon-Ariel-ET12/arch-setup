-- modernx/image/navigation.lua
-- Image playlist movement. Thin wrapper over mpv's own playlist,
-- which stays the authoritative media sequence.

local mp = require 'mp'
local msg = require 'mp.msg'
local state = require './state'
local media = require './core.media'

local M = {}

-- move by delta entries; returns true when a move was issued.
function M.move(delta)
    local entries = media.playlist_entries()
    if #entries < 2 then return false end
    local idx = media.playlist_index(entries)
    if idx == nil then return false end
    local target = idx + delta
    if target < 1 or target > #entries then return false end
    mp.commandv('playlist-play-index', target - 1)
    return true
end

function M.next()
    return M.move(1)
end

function M.prev()
    return M.move(-1)
end

-- jump to a 1-based playlist entry; bounds-checked.
function M.goto_index(idx)
    local entries = media.playlist_entries()
    if type(idx) ~= 'number' or idx < 1 or idx > #entries then
        msg.verbose('image navigation: index out of range: ' .. tostring(idx))
        return false
    end
    mp.commandv('playlist-play-index', idx - 1)
    return true
end

-- keep state.media in sync after mpv reports a playlist change.
function M.sync()
    local entries = media.playlist_entries()
    state.media.count = #entries
    state.media.index = media.playlist_index(entries)
    state.media.path = media.current_path()
end

return M
