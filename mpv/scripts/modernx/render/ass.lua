-- modernx/render/ass.lua
-- ASS generation helpers.

local state = require './state'
local math_util = require './utils.math'

local M = {}

-- append \1a\2a\3a\4a overrides to an ass, multiplying with state.animation
function M.ass_append_alpha(ass, alpha, modifier)
    local ar = {}

    for ai, av in pairs(alpha) do
        av = math_util.mult_alpha(av, modifier)
        if state.animation then
            av = math_util.mult_alpha(av, state.animation)
        end
        ar[ai] = av
    end

    ass:append(string.format('{\\1a&H%X&\\2a&H%X&\\3a&H%X&\\4a&H%X&}',
        ar[1], ar[2], ar[3], ar[4]))
end

-- draw a filled circle (clockwise) at (x, y) with radius r
function M.ass_draw_cir_cw(ass, x, y, r)
    ass:round_rect_cw(x - r, y - r, x + r, y + r, r)
end

-- draw rounded rect (clockwise) or hexagon (clockwise) based on flag
function M.ass_draw_rr_h_cw(ass, x0, y0, x1, y1, r1, hexagon, r2)
    if hexagon then
        ass:hexagon_cw(x0, y0, x1, y1, r1, r2)
    else
        ass:round_rect_cw(x0, y0, x1, y1, r1, r2)
    end
end

-- draw rounded rect (counter-clockwise) or hexagon (counter-clockwise)
function M.ass_draw_rr_h_ccw(ass, x0, y0, x1, y1, r1, hexagon, r2)
    if hexagon then
        ass:hexagon_ccw(x0, y0, x1, y1, r1, r2)
    else
        ass:round_rect_ccw(x0, y0, x1, y1, r1, r2)
    end
end

return M
