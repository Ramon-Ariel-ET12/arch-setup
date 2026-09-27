-- modernx/utils/math.lua
-- Pure math helpers used across the OSC.

local M = {}

-- linear interpolation/scale
function M.scale_value(x0, x1, y0, y1, val)
    local m = (y1 - y0) / (x1 - x0)
    local b = y0 - (m * x0)
    return (m * val) + b
end

-- clamp val to [min, max]
function M.limit_range(min, max, val)
    if val > max then
        val = max
    elseif val < min then
        val = min
    end
    return val
end

-- multiply two alpha values (0..255)
function M.mult_alpha(alphaA, alphaB)
    return 255 - (((1 - (alphaA / 255)) * (1 - (alphaB / 255))) * 255)
end

-- countone adjusts index 1-based (mpv native) or 0-based (iamaprogrammer)
function M.countone(val, user_opts)
    if not user_opts.iamaprogrammer then
        val = val + 1
    end
    return val
end

return M
