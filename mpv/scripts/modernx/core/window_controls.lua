-- modernx/core/window_controls.lua
-- Title-bar window controls (minimize, maximize, close).
-- Gated on user_opts.windowcontrols ('auto'/'yes'/'no').

local state = require './state'
local config = require './config'
local mp = require 'mp'
local hitbox = require './ui.hitbox'
local geo = require './utils.geometry'

local M = {}

-- returns true if the window controls should be shown
function M.window_controls_enabled()
    local val = config.user_opts.windowcontrols
    if val == 'auto' then
        return (not state.border) or state.fullscreen
    else
        return val ~= 'no'
    end
end

-- add the window control elements + their hit area
-- Called by osc_init after new_element/add_layout are available.
function M.window_controls()
    local new_element, add_layout = require('./core/osc_init').new_element,
        require('./core/osc_init').add_layout

    local wc_geo = {
        x = 0,
        y = 32,
        an = 1,
        w = state.osc_param.playresx,
        h = 32,
    }

    local controlbox_w = config.window_control_box_width

    -- default alignment is 'right'
    local controlbox_left = wc_geo.w - controlbox_w

    geo.add_area('window-controls',
        hitbox.get_hitbox_coords(controlbox_left, wc_geo.y, wc_geo.an,
            controlbox_w, wc_geo.h))

    local button_y = wc_geo.y - (wc_geo.h / 2)
    local first_geo =
    { x = controlbox_left + 27, y = button_y, an = 5, w = 40, h = wc_geo.h }
    local second_geo =
    { x = controlbox_left + 69, y = button_y, an = 5, w = 40, h = wc_geo.h }
    local third_geo =
    { x = controlbox_left + 115, y = button_y, an = 5, w = 40, h = wc_geo.h }

    -- Close
    local ne = new_element('close', 'button')
    ne.content = '\238\132\149'
    ne.eventresponder['mbtn_left_up'] = function() mp.commandv('quit') end
    local lo = add_layout('close')
    lo.geometry = third_geo
    lo.style = config.osc_styles.WinCtrl
    lo.alpha[3] = 0

    -- Minimize
    ne = new_element('minimize', 'button')
    ne.content = '\\n\238\132\146'
    ne.eventresponder['mbtn_left_up'] =
        function() mp.commandv('cycle', 'window-minimized') end
    lo = add_layout('minimize')
    lo.geometry = first_geo
    lo.style = config.osc_styles.WinCtrl
    lo.alpha[3] = 0

    -- Maximize / restore
    ne = new_element('maximize', 'button')
    if state.maximized or state.fullscreen then
        ne.content = '\238\132\148'
    else
        ne.content = '\238\132\147'
    end
    ne.eventresponder['mbtn_left_up'] = function()
        if state.fullscreen then
            mp.commandv('cycle', 'fullscreen')
        else
            mp.commandv('cycle', 'window-maximized')
        end
    end
    lo = add_layout('maximize')
    lo.geometry = second_geo
    lo.style = config.osc_styles.WinCtrl
    lo.alpha[3] = 0
end

return M
