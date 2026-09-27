-- modernx/ui/slider_math.lua
-- Coordinate <-> value translation for sliders.

local geo = require './utils.geometry'
local math_util = require './utils.math'

local M = {}

-- translate a value into element-local x coordinate
function M.get_slider_ele_pos_for(element, val)
    local ele_pos = math_util.scale_value(
        element.slider.min.value, element.slider.max.value,
        element.slider.min.ele_pos, element.slider.max.ele_pos,
        val)

    return math_util.limit_range(
        element.slider.min.ele_pos, element.slider.max.ele_pos,
        ele_pos)
end

-- translates global (mouse) coordinate to slider value
function M.get_slider_value_at(element, glob_pos)
    local val = math_util.scale_value(
        element.slider.min.glob_pos, element.slider.max.glob_pos,
        element.slider.min.value, element.slider.max.value,
        glob_pos)

    return math_util.limit_range(
        element.slider.min.value, element.slider.max.value,
        val)
end

-- get slider value at the current mouse position
function M.get_slider_value(element)
    return M.get_slider_value_at(element, geo.get_virt_mouse_pos())
end

return M
