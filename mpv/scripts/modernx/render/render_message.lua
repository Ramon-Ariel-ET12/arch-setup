-- modernx/render/render_message.lua
-- Render the OSD message overlay (playlist, chapter list, track list, etc.)

local mp = require 'mp'
local state = require './state'

local M = {}

-- append the current message to the master ass buffer
function M.render_message(ass)
    if state.message_hide_timer and state.message_hide_timer:is_enabled()
        and state.message_text
    then
        local _, lines = string.gsub(state.message_text, '\\N', '')

        local fontsize = tonumber(mp.get_property('options/osd-font-size'))
        local outline = tonumber(mp.get_property('options/osd-border-size'))
        local maxlines = math.ceil(state.osc_param.unscaled_y * 0.75 / fontsize)
        local counterscale = state.osc_param.playresy / state.osc_param.unscaled_y

        fontsize = fontsize * counterscale / math.max(0.65 + math.min(lines / maxlines, 1), 1)
        outline = outline * counterscale / math.max(0.75 + math.min(lines / maxlines, 1) / 2, 1)

        local style = '{\\bord' .. outline .. '\\fs' .. fontsize .. '}'

        ass:new_event()
        ass:append(style .. state.message_text)
    else
        state.message_text = nil
    end
end

return M
