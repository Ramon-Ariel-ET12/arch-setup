-- modernx/elements/toggles.lua
-- Toggle buttons: tog_fs, tog_info.

local mp = require 'mp'
local state = require './state'
local config = require './config'

local M = {}

function M.build(new_element)
    -- tog_fs: fullscreen toggle
    local ne = new_element('tog_fs', 'button')
    ne.content = function()
        if state.fullscreen then return config.icons.minimize end
        return config.icons.fullscreen
    end
    ne.visible = (state.osc_param.playresx >= 540)
    ne.eventresponder['mbtn_left_up'] = function() mp.commandv('cycle', 'fullscreen') end

    -- tog_info: stats display toggle
    ne = new_element('tog_info', 'button')
    ne.content = config.icons.info
    ne.visible = (state.osc_param.playresx >= 600)
    ne.eventresponder['mbtn_left_up'] =
        function() mp.commandv('script-binding', 'stats/display-stats-toggle') end
end

return M
