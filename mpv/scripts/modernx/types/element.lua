-- modernx/types/element.lua
-- LuaLS type annotations for the modernx element model.

---@class modernx.element_geometry
---@field x number
---@field y number
---@field an integer  -- numpad-style alignment 1..9
---@field w number
---@field h number

---@class modernx.element_slider_layout
---@field border integer
---@field gap integer
---@field nibbles_top boolean
---@field nibbles_bottom boolean
---@field adjust_tooltip boolean
---@field tooltip_style string
---@field tooltip_an integer
---@field alpha integer[]

---@class modernx.element_button_layout
---@field maxchars integer|nil

---@class modernx.element_box_layout
---@field radius integer
---@field hexagon boolean

---@alias modernx.element_alpha { [1]: integer, [2]: integer, [3]: integer, [4]: integer }

---@class modernx.element_layout
---@field layer integer
---@field alpha modernx.element_alpha
---@field geometry modernx.element_geometry
---@field style string
---@field button modernx.element_button_layout
---@field slider modernx.element_slider_layout
---@field box modernx.element_box_layout

---@class modernx.element_slider
---@field min { value: number, ele_pos: number, glob_pos: number }
---@field max { value: number, ele_pos: number, glob_pos: number }
---@field markerF fun(): number[]
---@field posF fun(): number|nil
---@field seekRangesF fun(): table[]|nil
---@field tooltipF fun(pos: number): string

---@class modernx.element_eventresponder
---@field mbtn_left_down fun(element: modernx.element)|nil
---@field mbtn_left_up fun(element: modernx.element)|nil
---@field mbtn_right_down fun(element: modernx.element)|nil
---@field mbtn_right_up fun(element: modernx.element)|nil
---@field shift+mbtn_left_down fun(element: modernx.element)|nil
---@field wheel_up_press fun(element: modernx.element)|nil
---@field wheel_down_press fun(element: modernx.element)|nil
---@field enter fun(element: modernx.element)|nil
---@field mouse_move fun(element: modernx.element)|nil
---@field render fun(element: modernx.element)|nil
---@field reset fun(element: modernx.element)|nil

---@class modernx.element
---@field name string
---@field type 'button'|'slider'|'box'
---@field visible boolean
---@field enabled boolean
---@field off boolean
---@field softrepeat boolean
---@field styledown boolean
---@field eventresponder modernx.element_eventresponder
---@field layout modernx.element_layout
---@field hitbox { x1: number, y1: number, x2: number, y2: number }
---@field style_ass mp.ass
---@field static_ass mp.ass
---@field slider modernx.element_slider|nil
---@field state table
---@field content (string|fun(): string)|nil
---@field tooltipF (string|fun(): string)|nil
---@field tooltip_style string|nil
