-- modernx/core/idle.lua
-- Idle-screen render path (mpv logo, optional santa hat, welcome text).

local mp = require 'mp'
local assdraw = require 'mp.assdraw'
local msg = require 'mp.msg'
local state = require './state'
local config = require './config'
local set_osd = require './render/set_osd'
local gfx = require './render/idle_gfx'

local M = {}

-- render the idle screen (logo + optional santa + welcome text)
function M.render_idle()
    msg.trace('idle message')
    local _, _, display_aspect = mp.get_osd_size()
    local display_h = 360
    local display_w = display_h * display_aspect
    -- logo is rendered at 2^(6-1) = 32 times resolution with size 1800x1800
    local icon_x, icon_y = (display_w - 1800 / 32) / 2, 140
    local line_prefix = ('{\\rDefault\\an7\\1a&H00&\\bord0\\shad0\\pos(%f,%f)}'):format(icon_x, icon_y)

    local ass = assdraw.ass_new()
    -- mpv logo
    if config.user_opts.idlescreen then
        for _, line in ipairs(gfx.logo_lines) do
            ass:new_event()
            ass:append(line_prefix .. line)
        end
    end

    -- Santa hat
    if config.is_december and config.user_opts.idlescreen and not config.user_opts.greenandgrumpy then
        for _, line in ipairs(gfx.santa_hat_lines) do
            ass:new_event()
            ass:append(line_prefix .. line)
        end
    end

    if config.user_opts.idlescreen then
        ass:new_event()
        ass:pos(display_w / 2, icon_y + 65)
        ass:an(8)
        ass:append(config.texts.welcome)
    end
    set_osd.set_osd(display_w, display_h, ass.text)

    if state.showhide_enabled then
        mp.disable_key_bindings('showhide')
        mp.disable_key_bindings('showhide_wc')
        state.showhide_enabled = false
    end
end

return M
