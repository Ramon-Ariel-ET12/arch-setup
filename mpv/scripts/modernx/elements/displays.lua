-- modernx/elements/displays.lua
-- Display elements: tc_left, tc_right, title.

local mp = require 'mp'
local state = require './state'
local config = require './config'

local M = {}

function M.build(new_element)
    -- tc_left: current playback time
    local ne = new_element('tc_left', 'button')
    ne.content = function()
        if state.fulltime then
            return mp.get_property_osd('playback-time/full')
        else
            return mp.get_property_osd('playback-time')
        end
    end
    ne.eventresponder['mbtn_left_up'] = function()
        state.fulltime = not state.fulltime
        require('./core/tick').request_init()
    end

    -- tc_right: total / remaining
    ne = new_element('tc_right', 'button')
    ne.content = function()
        if mp.get_property_number('duration', 0) <= 0 then return '--:--:--' end
        if state.rightTC_trem then
            if state.fulltime then
                return '-' .. mp.get_property_osd('playtime-remaining/full')
            else
                return '-' .. mp.get_property_osd('playtime-remaining')
            end
        else
            if state.fulltime then
                return mp.get_property_osd('duration/full')
            else
                return mp.get_property_osd('duration')
            end
        end
    end
    ne.eventresponder['mbtn_left_up'] = function() state.rightTC_trem = not state.rightTC_trem end

    -- title
    ne = new_element('title', 'button')
    ne.content = function()
        local title = state.forced_title
            or mp.command_native({ 'expand-text', config.user_opts.title })
        title = title:gsub('\\n', ' '):gsub('\\$', ''):gsub('{', '\\{')
        return not (title == '') and title or ' '
    end
    ne.visible = state.osc_param.playresy >= 320 and config.user_opts.showtitle
end

return M
