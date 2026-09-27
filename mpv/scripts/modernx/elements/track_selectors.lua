-- modernx/elements/track_selectors.lua
-- Track cycler buttons: cy_audio, cy_sub, vol_ctrl.

local mp = require 'mp'
local config = require './config'
local tracks = require './core.tracks'
local messages = require './core.messages'
local state = require './state'

local M = {}

function M.build(new_element)
    -- cy_audio
    local ne = new_element('cy_audio', 'button')
    ne.enabled = (#state.tracks_osc.audio > 0)
    ne.off = (tracks.get_track('audio') == 0)
    ne.visible = (state.osc_param.playresx >= 540)
    ne.content = config.icons.audio
    ne.tooltip_style = config.osc_styles.Tooltip
    ne.tooltipF = function()
        local msg = config.texts.off
        if not (tracks.get_track('audio') == 0) then
            msg = (config.texts.audio .. ' [' .. tracks.get_track('audio') .. ' ∕ ' .. #state.tracks_osc.audio .. '] ')
            local prop = mp.get_property('current-tracks/audio/title')
            if not prop then prop = config.texts.na end
            msg = msg .. '[' .. prop .. ']'
            prop = mp.get_property('current-tracks/audio/lang')
            if prop then msg = msg .. ' ' .. prop end
            return msg
        end
        return msg
    end
    ne.eventresponder['mbtn_left_up'] = function() tracks.set_track('audio', 1) end
    ne.eventresponder['mbtn_right_up'] = function() tracks.set_track('audio', -1) end
    ne.eventresponder['shift+mbtn_left_down'] = function() messages.show_message(tracks.get_tracklist('audio')) end
    ne.eventresponder['enter'] = function()
        tracks.set_track('audio', 1)
        messages.show_message(tracks.get_tracklist('audio'))
    end

    -- cy_sub
    ne = new_element('cy_sub', 'button')
    ne.enabled = (#state.tracks_osc.sub > 0)
    ne.off = (tracks.get_track('sub') == 0)
    ne.visible = (state.osc_param.playresx >= 600)
    ne.content = config.icons.sub
    ne.tooltip_style = config.osc_styles.Tooltip
    ne.tooltipF = function()
        local msg = config.texts.off
        if not (tracks.get_track('sub') == 0) then
            msg = (config.texts.subtitle .. ' [' .. tracks.get_track('sub') .. ' ∕ ' .. #state.tracks_osc.sub .. '] ')
            local prop = mp.get_property('current-tracks/sub/lang')
            if not prop then prop = config.texts.na end
            msg = msg .. '[' .. prop .. ']'
            prop = mp.get_property('current-tracks/sub/title')
            if prop then msg = msg .. ' ' .. prop end
            return msg
        end
        return msg
    end
    ne.eventresponder['mbtn_left_up'] = function() tracks.set_track('sub', 1) end
    ne.eventresponder['mbtn_right_up'] = function() tracks.set_track('sub', -1) end
    ne.eventresponder['shift+mbtn_left_down'] = function() messages.show_message(tracks.get_tracklist('sub')) end
    ne.eventresponder['enter'] = function()
        tracks.set_track('sub', 1)
        messages.show_message(tracks.get_tracklist('sub'))
    end

    -- vol_ctrl
    ne = new_element('vol_ctrl', 'button')
    ne.enabled = (tracks.get_track('audio') > 0)
    ne.visible = (state.osc_param.playresx >= 650) and config.user_opts.volumecontrol
    ne.content = function()
        if state.mute then return config.icons.volume_mute end
        return config.icons.volume
    end
    ne.eventresponder['mbtn_left_up'] = function() mp.commandv('cycle', 'mute') end
    ne.eventresponder['wheel_up_press'] = function() mp.commandv('osd-auto', 'add', 'volume', 5) end
    ne.eventresponder['wheel_down_press'] = function() mp.commandv('osd-auto', 'add', 'volume', -5) end
end

return M
