-- modernx/core/render.lua
-- The main render() function: animates, registers mouse areas, dispatches
-- to render_message and render_elements, and submits to the OSD.

local mp = require 'mp'
local msg = require 'mp.msg'
local state = require './state'
local config = require './config'
local hitbox = require './ui.hitbox'
local geo = require './utils.geometry'
local set_osd_mod = require './render.set_osd'
local render_message = require './render.render_message'
local render_elements = require './render.render_elements'
local math_util = require './utils.math'

-- forward refs bound by main.lua
local request_tick, request_init_resize, hide_osc

local M = {}

-- register showhide/showhide_wc/input/window-controls mouse areas
-- and toggle key bindings as needed
local function register_mouse_areas()
    for _, cords in pairs(state.osc_param.areas['showhide']) do
        geo.set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, 'showhide')
    end
    if state.osc_param.areas['showhide_wc'] then
        for _, cords in pairs(state.osc_param.areas['showhide_wc']) do
            geo.set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, 'showhide_wc')
        end
    else
        geo.set_virt_mouse_area(0, 0, 0, 0, 'showhide_wc')
    end
    require('./core/tick').do_enable_keybindings()

    local mouse_over_osc = false
    for _, cords in ipairs(state.osc_param.areas['input']) do
        if state.osc_visible then
            geo.set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, 'input')
        end
        if state.osc_visible ~= state.input_enabled then
            if state.osc_visible then
                mp.enable_key_bindings('input')
            else
                mp.disable_key_bindings('input')
            end
            state.input_enabled = state.osc_visible
        end
        if hitbox.mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2) then
            mouse_over_osc = true
        end
    end

    if state.osc_param.areas['window-controls'] then
        for _, cords in ipairs(state.osc_param.areas['window-controls']) do
            if state.osc_visible then
                geo.set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, 'window-controls')
                mp.enable_key_bindings('window-controls')
            else
                mp.disable_key_bindings('window-controls')
            end
            if hitbox.mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2) then
                mouse_over_osc = true
            end
        end
    end

    if state.osc_param.areas['window-controls-title'] then
        for _, cords in ipairs(state.osc_param.areas['window-controls-title']) do
            if hitbox.mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2) then
                mouse_over_osc = true
            end
        end
    end
    return mouse_over_osc
end

-- advance the fade animation; returns true if the animation finished
local function tick_animation(now)
    if state.anitype == nil then
        state.anistart = nil
        state.animation = nil
        return
    end
    if state.anistart == nil then
        state.anistart = now
    end
    if now < state.anistart + (config.user_opts.fadeduration / 1000) then
        if state.anitype == 'in' then
            require('./core/visibility').osc_visible(true)
            state.animation = math_util.scale_value(
                state.anistart,
                state.anistart + config.user_opts.fadeduration / 1000,
                255, 0, now)
        else
            state.animation = math_util.scale_value(
                state.anistart,
                state.anistart + config.user_opts.fadeduration / 1000,
                0, 255, now)
        end
    else
        if state.anitype == 'out' then
            require('./core/visibility').osc_visible(false)
        end
        state.anistart = nil
        state.animation = nil
        state.anitype = nil
    end
end

-- autohide: re-arm hide_timer or hide now
local function autohide_tick(now, mouse_over_osc)
    if state.showtime ~= nil and require('./core/visibility').get_hidetimeout() >= 0 then
        local timeout = state.showtime + require('./core/visibility').get_hidetimeout() / 1000 - now
        if timeout <= 0 then
            if state.active_element == nil and not mouse_over_osc then
                hide_osc()
            end
        else
            if not state.hide_timer then
                state.hide_timer = mp.add_timeout(0, require('./core/tick').tick)
            end
            state.hide_timer.timeout = timeout
            state.hide_timer:kill()
            state.hide_timer:resume()
        end
    end
end

-- the main render entry point
function M.render()
    msg.trace('rendering')
    local current_screen_sizeX, current_screen_sizeY = mp.get_osd_size()
    local now = mp.get_time()

    -- check if display changed, if so request reinit
    if not (state.mp_screen_sizeX == current_screen_sizeX
            and state.mp_screen_sizeY == current_screen_sizeY)
    then
        request_init_resize()
        state.mp_screen_sizeX = current_screen_sizeX
        state.mp_screen_sizeY = current_screen_sizeY
    end

    -- init management
    if state.active_element then
        -- mouse held down on some element: keep ticking and ignore initReq
        request_tick()
    elseif state.initREQ then
        require('./core/osc_init').osc_init()
        state.initREQ = false
    end

    -- fade animation
    tick_animation(now)

    -- mouse area registration
    local mouse_over_osc = register_mouse_areas()

    -- autohide
    autohide_tick(now, mouse_over_osc)

    -- actual rendering
    local ass = require('mp.assdraw').ass_new()
    render_message.render_message(ass)
    if state.osc_visible then
        render_elements.render_elements(ass)
    end
    set_osd_mod.set_osd(
        state.osc_param.playresy * state.osc_param.display_aspect,
        state.osc_param.playresy, ass.text)
end

function M.bind(refs)
    if refs.request_tick then request_tick = refs.request_tick end
    if refs.request_init_resize then request_init_resize = refs.request_init_resize end
    if refs.hide_osc then hide_osc = refs.hide_osc end
end

return M
