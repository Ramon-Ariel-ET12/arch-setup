-- modernx/render/set_osd.lua
-- OSD submission helpers.

local state = require './state'

local M = {}

-- submit ASS to the OSD overlay (dedup if res/text unchanged)
function M.set_osd(res_x, res_y, text)
    if state.osd.res_x == res_x
        and state.osd.res_y == res_y
        and state.osd.data == text
    then
        return
    end
    state.osd.res_x = res_x
    state.osd.res_y = res_y
    state.osd.data = text
    state.osd.z = 1000
    state.osd:update()
end

-- remove the OSD overlay entirely
function M.render_wipe()
    state.osd:remove()
end

return M
