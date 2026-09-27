-- modernx/ui/hitbox.lua
-- Hitbox computation and mouse hit-testing.

local geo = require './utils.geometry'

local M = {}

-- returns hitbox spanning coordinates (top left, bottom right corner)
-- according to alignment (1..9 numpad-style)
function M.get_hitbox_coords(x, y, an, w, h)
    local alignments = {
        [1] = function() return x, y - h, x + w, y end,
        [2] = function() return x - (w / 2), y - h, x + (w / 2), y end,
        [3] = function() return x - w, y - h, x, y end,

        [4] = function() return x, y - (h / 2), x + w, y + (h / 2) end,
        [5] = function() return x - (w / 2), y - (h / 2), x + (w / 2), y + (h / 2) end,
        [6] = function() return x - w, y - (h / 2), x, y + (h / 2) end,

        [7] = function() return x, y, x + w, y + h end,
        [8] = function() return x - (w / 2), y, x + (w / 2), y + h end,
        [9] = function() return x - w, y, x, y + h end,
    }

    return alignments[an]()
end

function M.get_hitbox_coords_geo(geometry)
    return M.get_hitbox_coords(geometry.x, geometry.y, geometry.an,
        geometry.w, geometry.h)
end

function M.get_element_hitbox(element)
    return element.hitbox.x1, element.hitbox.y1,
        element.hitbox.x2, element.hitbox.y2
end

function M.mouse_hit(element)
    return M.mouse_hit_coords(M.get_element_hitbox(element))
end

function M.mouse_hit_coords(bX1, bY1, bX2, bY2)
    local mX, mY = geo.get_virt_mouse_pos()
    return (mX >= bX1 and mX <= bX2 and mY >= bY1 and mY <= bY2)
end

return M
