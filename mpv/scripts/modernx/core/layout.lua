-- modernx/core/layout.lua
-- Default layout: geometry + style for every element in the bottom OSC strip.

local state = require './state'
local config = require './config'
local hitbox = require './ui.hitbox'
local geo = require './utils.geometry'

local M = {}

-- Image layout: no bottom OSC at all. A small corner click target
-- (the info button) is the only chrome; showhide covers the canvas
-- for autohide bookkeeping. Called by osc_init instead of layouts().
function M.image_layouts()
    state.osc_param.areas = {} -- delete areas

    local pw = state.osc_param.playresx
    local ph = state.osc_param.playresy
    local corner = 64 -- info button corner hit area (virtual px)

    -- info button corner handles clicks; add_area takes raw corners
    -- (x1,y1,x2,y2), unlike the an-based hitbox helper used below.
    geo.add_area('input', pw - corner, ph - corner, pw, ph)
    -- show/hide bookkeeping across the whole canvas.
    geo.add_area('showhide', 0, 0, pw, ph)

    local lo
    local add_layout = require('./core.osc_init').add_layout

    -- invisible click target over the info button corner (rendered by
    -- image/ui.lua itself; this only gives it a hitbox).
    lo = add_layout('image_ui')
    lo.geometry = { x = pw - corner / 2, y = ph - corner / 2, an = 5, w = corner, h = corner }
    lo.style = ''
    lo.layer = 10
end

-- The default bottom-bar layout. Called by osc_init after all element
-- factories have registered the elements.
function M.layouts()
    local osc_geo = {}
    osc_geo.w = state.osc_param.playresx
    osc_geo.h = 180

    -- origin of the controllers, left/bottom corner
    local posX = 0
    local posY = state.osc_param.playresy

    state.osc_param.areas = {} -- delete areas

    -- area for active mouse input
    geo.add_area('input', hitbox.get_hitbox_coords(posX, posY, 1, osc_geo.w, 104))
    -- area for show/hide
    geo.add_area('showhide', 0, 0, state.osc_param.playresx, state.osc_param.playresy)

    local osc_w = osc_geo.w

    --
    -- Controller Background
    --
    local lo
    local new_element, add_layout = require('./core.osc_init').new_element,
        require('./core.osc_init').add_layout

    new_element('TransBg', 'box')
    lo = add_layout('TransBg')
    lo.geometry = { x = posX, y = posY, an = 7, w = osc_w, h = 1 }
    lo.style = config.osc_styles.TransBg
    lo.layer = 10
    lo.alpha[3] = 0

    local refX = osc_w / 2
    local refY = posY

    --
    -- Seekbar
    --
    new_element('seekbarbg', 'box')
    lo = add_layout('seekbarbg')
    lo.geometry = { x = refX, y = refY - 96, an = 5, w = osc_geo.w - 50, h = 2 }
    lo.layer = 13
    lo.style = config.osc_styles.SeekbarBg
    lo.alpha[1] = 128
    lo.alpha[3] = 128

    lo = add_layout('seekbar')
    lo.geometry = { x = refX, y = refY - 96, an = 5, w = osc_geo.w - 50, h = 16 }
    lo.style = config.osc_styles.SeekbarFg
    lo.slider.gap = 7
    lo.slider.tooltip_style = config.osc_styles.Tooltip
    lo.slider.tooltip_an = 2

    local showjump = config.user_opts.showjump
    local offset = showjump and 60 or 0

    --
    -- Volumebar
    --
    lo = new_element('volumebarbg', 'box')
    lo.visible = (state.osc_param.playresx >= 750) and config.user_opts.volumecontrol
    lo = add_layout('volumebarbg')
    lo.geometry = { x = 155, y = refY - 40, an = 4, w = 80, h = 2 }
    lo.layer = 13
    lo.style = config.osc_styles.VolumebarBg

    lo = add_layout('volumebar')
    lo.geometry = { x = 155, y = refY - 40, an = 4, w = 80, h = 8 }
    lo.style = config.osc_styles.VolumebarFg
    lo.slider.gap = 3
    lo.slider.tooltip_style = config.osc_styles.Tooltip
    lo.slider.tooltip_an = 2

    -- buttons
    lo = add_layout('pl_prev')
    lo.geometry = { x = refX - 120 - offset, y = refY - 40, an = 5, w = 30, h = 24 }
    lo.style = config.osc_styles.Ctrl2

    lo = add_layout('skipback')
    lo.geometry = { x = refX - 60 - offset, y = refY - 40, an = 5, w = 30, h = 24 }
    lo.style = config.osc_styles.Ctrl2

    if showjump then
        lo = add_layout('jumpback')
        lo.geometry = { x = refX - 60, y = refY - 40, an = 5, w = 30, h = 24 }
        lo.style = config.osc_styles.Ctrl2
    end

    lo = add_layout('playpause')
    lo.geometry = { x = refX, y = refY - 40, an = 5, w = 45, h = 45 }
    lo.style = config.osc_styles.Ctrl1

    if showjump then
        lo = add_layout('jumpfrwd')
        lo.geometry = { x = refX + 60, y = refY - 40, an = 5, w = 30, h = 24 }
        -- HACK: jumpfrwd's icon must be mirrored for nonstandard # of seconds
        lo.style = (config.user_opts.jumpiconnumber and config.jumpicons[config.user_opts.jumpamount] ~= nil)
            and config.osc_styles.Ctrl2 or config.osc_styles.Ctrl2Flip
    end

    lo = add_layout('skipfrwd')
    lo.geometry = { x = refX + 60 + offset, y = refY - 40, an = 5, w = 30, h = 24 }
    lo.style = config.osc_styles.Ctrl2

    lo = add_layout('pl_next')
    lo.geometry = { x = refX + 120 + offset, y = refY - 40, an = 5, w = 30, h = 24 }
    lo.style = config.osc_styles.Ctrl2

    -- Time
    lo = add_layout('tc_left')
    lo.geometry = { x = 25, y = refY - 84, an = 7, w = 64, h = 20 }
    lo.style = config.osc_styles.Time

    lo = add_layout('tc_right')
    lo.geometry = { x = osc_geo.w - 25, y = refY - 84, an = 9, w = 64, h = 20 }
    lo.style = config.osc_styles.Time

    lo = add_layout('cy_audio')
    lo.geometry = { x = 37, y = refY - 40, an = 5, w = 24, h = 24 }
    lo.style = config.osc_styles.Ctrl3
    lo.visible = (state.osc_param.playresx >= 540)

    lo = add_layout('cy_sub')
    lo.geometry = { x = 87, y = refY - 40, an = 5, w = 24, h = 24 }
    lo.style = config.osc_styles.Ctrl3
    lo.visible = (state.osc_param.playresx >= 600)

    lo = add_layout('vol_ctrl')
    lo.geometry = { x = 137, y = refY - 40, an = 5, w = 24, h = 24 }
    lo.style = config.osc_styles.Ctrl3
    lo.visible = (state.osc_param.playresx >= 650) and config.user_opts.volumecontrol

    lo = add_layout('tog_fs')
    lo.geometry = { x = osc_geo.w - 37, y = refY - 40, an = 5, w = 24, h = 24 }
    lo.style = config.osc_styles.Ctrl3
    lo.visible = (state.osc_param.playresx >= 540)

    lo = add_layout('tog_info')
    lo.geometry = { x = osc_geo.w - 87, y = refY - 40, an = 5, w = 24, h = 24 }
    lo.style = config.osc_styles.Ctrl3
    lo.visible = (state.osc_param.playresx >= 600)

    local geo_ = { x = 25, y = refY - 132, an = 1, w = osc_geo.w - 50, h = 48 }
    lo = add_layout('title')
    lo.geometry = geo_
    lo.style = string.format('%s{\\clip(%f,%f,%f,%f)}', config.osc_styles.Title,
        geo_.x, geo_.y - geo_.h, geo_.x + geo_.w, geo_.y + 5)
    lo.alpha[3] = 0
    lo.button.maxchars = geo_.w / 23
end

return M
