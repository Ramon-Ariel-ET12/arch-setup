-- modernx/image/ui.lua
-- Image mode UI: media full-frame, no video OSC (no seekbar, play/pause,
-- volume, timers). Only chrome is the icon-only info button (bottom-right
-- corner, ⓘ) with the metadata panel it toggles. activate() is idempotent.

local mp = require 'mp'
local assdraw = require 'mp.assdraw'
local state = require './state'
local config = require './config'
local meta = require './image.metadata'

local M = {}

local active = false

-- info panel state: open/closed only.
M.info_open = false

-- corner button size (virtual ASS px) and its click hitbox.
local INFO_SIZE = 30
M._info_hit = nil

function M.toggle_info()
    M.info_open = not M.info_open
end

function M.close_info()
    M.info_open = false
end

-- value or a clean placeholder; never leaks nil into ASS.
local function show(v)
    if v == nil or v == '' then return '—' end
    return tostring(v):gsub('{', '\\{')
end

-- draw the icon-only info button (bottom-right, always visible in
-- image mode) and stash its hitbox for click handling.
local function render_info_button(master_ass)
    local pw = state.osc_param.playresx
    local ph = state.osc_param.playresy
    local margin = 16
    local btn = assdraw.ass_new()
    btn:new_event()
    btn:pos(pw - margin, ph - margin)
    btn:an(9)
    btn:append(config.osc_styles.Ctrl3)
    btn:append(config.icons.info)
    master_ass:merge(btn)
    M._info_hit = { x0 = pw - margin - INFO_SIZE, y0 = ph - margin - INFO_SIZE,
        x1 = pw, y1 = ph - margin + 6 }
end

-- draw the metadata panel as ASS events when open, centered on canvas.
local function render_info(master_ass)
    if not M.info_open then return end
    local d = meta.collect()

    local pad = 18
    local pw = state.osc_param.playresx
    local ph = state.osc_param.playresy
    local w = math.min(560, math.max(320, pw - pad * 2))
    local lines = {
        'Filename  ' .. show(d.filename),
        'Path  ' .. show(d.path),
        'Type  ' .. show(d.mime) .. (d.ext and '  (.' .. show(d.ext) .. ')' or ''),
        'Size  ' .. show(meta.format_size(d.size)),
        'Modified  ' .. show(d.mtime_text),
        'Dimensions  ' .. ((d.width and d.height)
            and string.format('%dx%d', d.width, d.height) or '—'),
        'Aspect  ' .. show(d.aspect),
        'Depth  ' .. show(d.depth),
        'Color  ' .. show(d.colorspace),
    }

    local row_h = 26
    local h = #lines * row_h + pad * 2 + 34
    local x0 = math.max(pad, (pw - w) / 2)
    local y0 = math.max(pad, (ph - h) / 2)

    local bg = assdraw.ass_new()
    bg:new_event()
    bg:pos(x0, y0)
    bg:an(7)
    bg:append(config.osc_styles.TransBg)
    bg:draw_start()
    bg:rect_cw(0, 0, w, h)
    bg:draw_stop()
    master_ass:merge(bg)

    local title = assdraw.ass_new()
    title:new_event()
    title:pos(x0 + pad, y0 + pad)
    title:an(7)
    title:append(config.osc_styles.Tooltip)
    title:append(config.icons.info .. '  Media info  (i / ESC: close)')
    master_ass:merge(title)

    for i, line in ipairs(lines) do
        local row = assdraw.ass_new()
        row:new_event()
        row:pos(x0 + pad, y0 + pad + 30 + (i - 1) * row_h)
        row:an(7)
        row:append(string.format('{\\fn%s\\fs14\\1c&HFFFFFF&}%s',
            config.user_opts.font, line))
        master_ass:merge(row)
    end
end

-- element content callback: keeps the click target in the element tree.
-- Kept as a named function so osc_init can reference it.
function M.render_content()
    return ''
end

-- click handling in virtual ASS coords; returns true when consumed.
function M.click(x, y)
    if not active or state.ui.mode ~= 'image' then return false end
    local hb = M._info_hit
    if hb and x >= hb.x0 and x <= hb.x1 and y >= hb.y0 and y <= hb.y1 then
        M.toggle_info()
        return true
    end
    return false
end

function M.activate()
    if active then return end
    active = true
    M.bind_image_keys()
end

function M.deactivate()
    active = false
    M.close_info()
    M._info_hit = nil
    M.unbind_image_keys()
end

-- called by the image render path (core/render.render_image).
function M.render(master_ass)
    if not active or state.ui.mode ~= 'image' then return end
    render_info_button(master_ass)
    render_info(master_ass)
end

function M.bind_image_keys()
    -- 'i' is bound twice on purpose: input.conf maps it to the
    -- script-message below (works even before Lua keybinds attach),
    -- and the forced binding here keeps it alive when mpv overrides
    -- user keys (e.g. builtin stats 'i' in some builds).
    mp.add_forced_key_binding('i', 'image-info', M.toggle_info, 'repeatable')
    mp.add_forced_key_binding('ESC', 'image-info-close', M.close_info)
end

function M.unbind_image_keys()
    mp.remove_key_binding('image-info')
    mp.remove_key_binding('image-info-close')
end

return M
