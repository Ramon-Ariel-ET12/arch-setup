-- modernx/utils/geometry.lua
-- Coordinate-system helpers (real <-> virtual ASS).

local mp = require 'mp'
local state = require './state'

local M = {}

-- scale factor for translating between real and virtual ASS coordinates
function M.get_virt_scale_factor()
    local w, h = mp.get_osd_size()
    if w <= 0 or h <= 0 then
        return 0, 0
    end
    return state.osc_param.playresx / w, state.osc_param.playresy / h
end

-- return mouse position in virtual ASS coordinates (playresx/y)
function M.get_virt_mouse_pos()
    if state.mouse_in_window then
        local sx, sy = M.get_virt_scale_factor()
        local x, y = mp.get_mouse_pos()
        return x * sx, y * sy
    else
        return -1, -1
    end
end

-- set a mouse area in real coordinates given a virtual ASS rect
function M.set_virt_mouse_area(x0, y0, x1, y1, name)
    local sx, sy = M.get_virt_scale_factor()
    if sx == 0 or sy == 0 then
        mp.set_mouse_area(0, 0, 0, 0, name)
    else
        mp.set_mouse_area(x0 / sx, y0 / sy, x1 / sx, y1 / sy, name)
    end
end

-- add a rectangle to an osc_param area (creates the area if missing)
function M.add_area(name, x1, y1, x2, y2)
    if state.osc_param.areas[name] == nil then
        state.osc_param.areas[name] = {}
    end
    table.insert(state.osc_param.areas[name], { x1 = x1, y1 = y1, x2 = x2, y2 = y2 })
end

return M
