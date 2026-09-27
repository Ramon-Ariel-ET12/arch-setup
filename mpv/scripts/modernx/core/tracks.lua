-- modernx/core/tracks.lua
-- Track list mirror + selection helpers.
-- Migrated: tracks_osc and tracks_mpv are now in state.lua
-- (no longer implicit globals).

local mp = require 'mp'
local state = require './state'
local config = require './config'

local M = {}

-- pretty labels per type
M.nicetypes = { video = config.texts.video, audio = config.texts.audio, sub = config.texts.subtitle }

-- rebuild state.tracks_osc / state.tracks_mpv from mpv's track-list
function M.update_tracklist()
    local tracktable = mp.get_property_native('track-list', {})

    state.tracks_osc = { video = {}, audio = {}, sub = {} }
    state.tracks_mpv = { video = {}, audio = {}, sub = {} }

    for n = 1, #tracktable do
        if not (tracktable[n].type == 'unknown') then
            local type = tracktable[n].type
            local mpv_id = tonumber(tracktable[n].id)

            -- by osc_id (1..N per type)
            table.insert(state.tracks_osc[type], tracktable[n])

            -- by mpv_id
            state.tracks_mpv[type][mpv_id] = tracktable[n]
            state.tracks_mpv[type][mpv_id].osc_id = #state.tracks_osc[type]
        end
    end
end

-- pretty list of tracks of a given type
function M.get_tracklist(type)
    local msg = config.texts.available .. M.nicetypes[type] .. config.texts.track
    if #state.tracks_osc[type] == 0 then
        msg = msg .. config.texts.none
    else
        for n = 1, #state.tracks_osc[type] do
            local track = state.tracks_osc[type][n]
            local lang, title, selected = 'unknown', '', '○'
            if not (track.lang == nil) then lang = track.lang end
            if not (track.title == nil) then title = track.title end
            if (track.id == tonumber(mp.get_property(type))) then
                selected = '●'
            end
            msg = msg .. '\n' .. selected .. ' ' .. n .. ': [' .. lang .. '] ' .. title
        end
    end
    return msg
end

-- change track of given <type> by <next> (e.g. +1 next, -1 previous)
function M.set_track(type, next)
    local current_track_mpv, current_track_osc
    if (mp.get_property(type) == 'no') then
        current_track_osc = 0
    else
        current_track_mpv = tonumber(mp.get_property(type))
        current_track_osc = state.tracks_mpv[type][current_track_mpv].osc_id
    end
    local new_track_osc = (current_track_osc + next) % (#state.tracks_osc[type] + 1)
    local new_track_mpv
    if new_track_osc == 0 then
        new_track_mpv = 'no'
    else
        new_track_mpv = state.tracks_osc[type][new_track_osc].id
    end

    mp.commandv('set', type, new_track_mpv)
end

-- get the currently selected track of <type>, OSC-style counted (0 = none)
function M.get_track(type)
    local track = mp.get_property(type)
    if track ~= 'no' and track ~= nil then
        local tr = state.tracks_mpv[type][tonumber(track)]
        if tr then
            return tr.osc_id
        end
    end
    return 0
end

return M
