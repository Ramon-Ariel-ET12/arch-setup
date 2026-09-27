-- modernx/core/osc_init.lua
-- osc_init: builds the element tree (content + event responders) and
-- then invokes prepare_elements to compute hitboxes and static ASS.
-- Factories in modernx/elements/*.lua are passed new_element/add_layout
-- as arguments to break the load cycle.

local mp = require 'mp'
local msg = require 'mp.msg'
local assdraw = require 'mp.assdraw'
local state = require './state'
local config = require './config'
local hitbox = require './ui.hitbox'
local geo = require './utils.geometry'
local slider_math = require './ui.slider_math'
local ass_render = require './render.ass'
local tracks = require './core.tracks'

local M = {}

-- ============================================================
-- Element constructors (new_element, add_layout)
-- ============================================================

function M.new_element(name, type)
    state.elements[name] = {}
    local e = state.elements[name]
    e.type = type
    e.name = name
    e.eventresponder = {}
    e.visible = true
    e.enabled = true
    e.softrepeat = false
    e.styledown = (type == 'button')
    e.state = {}

    if type == 'slider' then
        e.slider = { min = { value = 0 }, max = { value = 100 } }
    end
    return e
end

function M.add_layout(name)
    if state.elements[name] == nil then
        msg.error('Can\'t add_layout to element \'' .. name .. '\', doesn\'t exist.')
        return
    end
    state.elements[name].layout = {}
    local lo = state.elements[name].layout
    lo.layer = 50
    lo.alpha = { [1] = 0, [2] = 255, [3] = 255, [4] = 255 }

    if state.elements[name].type == 'button' then
        lo.button = { maxchars = nil }
    elseif state.elements[name].type == 'slider' then
        lo.slider = {
            border = 1,
            gap = 1,
            nibbles_top = true,
            nibbles_bottom = true,
            adjust_tooltip = true,
            tooltip_style = '',
            tooltip_an = 2,
            alpha = { [1] = 0, [2] = 255, [3] = 88, [4] = 255 },
        }
    elseif state.elements[name].type == 'box' then
        lo.box = { radius = 0, hexagon = false }
    end
    return lo
end

-- ============================================================
-- prepare_elements: filters, sorts by layer, computes hitboxes,
-- pre-bakes style_ass and static_ass.
-- ============================================================

function M.prepare_elements()
    local elements2 = {}
    for _, element in pairs(state.elements) do
        if not (element.layout == nil) and element.visible then
            table.insert(elements2, element)
        end
    end
    state.elements = elements2

    table.sort(state.elements, function(a, b) return a.layout.layer < b.layout.layer end)

    for _, element in pairs(state.elements) do
        local elem_geo = element.layout.geometry

        local bX1, bY1, bX2, bY2 = hitbox.get_hitbox_coords_geo(elem_geo)
        element.hitbox = { x1 = bX1, y1 = bY1, x2 = bX2, y2 = bY2 }

        local style_ass = assdraw.ass_new()
        style_ass:append('{}')
        style_ass:new_event()
        style_ass:pos(elem_geo.x, elem_geo.y)
        style_ass:an(elem_geo.an)
        style_ass:append(element.layout.style)
        element.style_ass = style_ass

        local static_ass = assdraw.ass_new()

        if element.type == 'box' then
            static_ass:draw_start()
            ass_render.ass_draw_rr_h_cw(static_ass, 0, 0, elem_geo.w, elem_geo.h,
                element.layout.box.radius, element.layout.box.hexagon)
            static_ass:draw_stop()
        elseif element.type == 'slider' then
            local slider_lo = element.layout.slider
            element.slider.min.ele_pos = config.user_opts.seekbarhandlesize * elem_geo.h / 2
            element.slider.max.ele_pos = elem_geo.w - element.slider.min.ele_pos
            element.slider.min.glob_pos = element.hitbox.x1 + element.slider.min.ele_pos
            element.slider.max.glob_pos = element.hitbox.x1 + element.slider.max.ele_pos

            static_ass:draw_start()
            static_ass:rect_cw(0, 0, elem_geo.w, elem_geo.h)
            static_ass:rect_ccw(0, 0, elem_geo.w, elem_geo.h)
            if not (element.slider.markerF == nil) and (slider_lo.gap > 0) then
                local markers = element.slider.markerF()
                for _, marker in pairs(markers) do
                    if (marker >= element.slider.min.value)
                        and (marker <= element.slider.max.value)
                    then
                        local s = slider_math.get_slider_ele_pos_for(element, marker)
                        if slider_lo.gap > 5 then
                            if slider_lo.nibbles_top then
                                static_ass:move_to(s - 3, slider_lo.gap - 5)
                                static_ass:line_to(s + 3, slider_lo.gap - 5)
                                static_ass:line_to(s, slider_lo.gap - 1)
                            end
                            if slider_lo.nibbles_bottom then
                                static_ass:move_to(s - 3, elem_geo.h - slider_lo.gap + 5)
                                static_ass:line_to(s, elem_geo.h - slider_lo.gap + 1)
                                static_ass:line_to(s + 3, elem_geo.h - slider_lo.gap + 5)
                            end
                        else
                            if slider_lo.nibbles_top then
                                static_ass:rect_cw(s - 1, 0, s + 1, slider_lo.gap)
                            end
                            if slider_lo.nibbles_bottom then
                                static_ass:rect_cw(s - 1, elem_geo.h - slider_lo.gap, s + 1, elem_geo.h)
                            end
                        end
                    end
                end
            end
        end
        element.static_ass = static_ass

        if not element.enabled then
            element.layout.alpha[1] = 136
            element.eventresponder = nil
        end
        if element.off then
            element.layout.alpha[1] = 136
        end
    end
end

-- ============================================================
-- osc_init: the main build entry point, called on start-file,
-- track-list change, playlist change, etc.
-- ============================================================

function M.osc_init()
    msg.debug('osc_init')

    -- canvas resolution
    local baseResY = 720
    local display_w, display_h, display_aspect = mp.get_osd_size()
    local scale = 1
    if mp.get_property('video') == 'no' then
        scale = config.user_opts.scaleforcedwindow
    elseif state.fullscreen then
        scale = config.user_opts.scalefullscreen
    else
        scale = config.user_opts.scalewindowed
    end
    if config.user_opts.vidscale then
        state.osc_param.unscaled_y = baseResY
    else
        state.osc_param.unscaled_y = display_h
    end
    state.osc_param.playresy = state.osc_param.unscaled_y / scale
    if display_aspect > 0 then
        state.osc_param.display_aspect = display_aspect
    end
    state.osc_param.playresx = state.osc_param.playresy * state.osc_param.display_aspect

    -- prevent stale drag state from re-init
    state.active_element = nil
    state.elements = {}

    -- image mode: no video OSC (transport, sliders, track selectors,
    -- displays, toggles make no sense for stills -- no timeline,
    -- play/pause, or volume). Only the info-button click target exists.
    if state.ui.mode == 'image' then
        local ne = M.new_element('image_ui', 'button')
        ne.content = require('./image.ui').render_content
        ne.eventresponder['mbtn_left_up'] = function()
            local x, y = require('./utils.geometry').get_virt_mouse_pos()
            require('./image.ui').click(x, y)
        end
        -- layout still provides the canvas + input/showhide mouse areas.
        require('./core.layout').image_layouts()
        M.prepare_elements()
        return
    end

    -- commonly-needed values
    local pl_count = mp.get_property_number('playlist-count', 0)
    local have_pl = (pl_count > 1)
    local pl_pos = mp.get_property_number('playlist-pos', 0) + 1
    local have_ch = (mp.get_property_number('chapters', 0) > 0)
    local loop = mp.get_property('loop-playlist', 'no')

    local new_element = M.new_element
    local add_layout = M.add_layout

    -- refresh track mirror BEFORE factories read it
    tracks.update_tracklist()

    -- build all elements via factory modules
    require('./elements.transport').build(new_element, {
        pl_pos = pl_pos, pl_count = pl_count,
        have_pl = have_pl, have_ch = have_ch, loop = loop,
    })
    require('./elements.sliders').build(new_element, { have_ch = have_ch })
    require('./elements.track_selectors').build(new_element)
    require('./elements.displays').build(new_element)
    require('./elements.toggles').build(new_element)

    -- default layout
    require('./core.layout').layouts()

    -- window controls
    if require('./core.window_controls').window_controls_enabled() then
        require('./core.window_controls').window_controls()
    end

    M.prepare_elements()
end

return M
