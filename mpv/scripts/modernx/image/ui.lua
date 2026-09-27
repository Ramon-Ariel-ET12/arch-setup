-- modernx/image/ui.lua
-- Image mode UI: sidebar + info panel over mpv's own image rendering.
-- Registers one element-tree entry ('image_ui') so the shared render
-- path picks it up; activate() is idempotent.

local mp = require 'mp'
local assdraw = require 'mp.assdraw'
local state = require './state'
local config = require './config'
local sidebar = require './image.sidebar'
local meta = require './image.metadata'

local M = {}

local active = false

-- info panel state lives here (not in sidebar): open/closed only.
M.info_open = false

function M.toggle_info()
    M.info_open = not M.info_open
    sidebar.info_open = M.info_open
end

function M.close_info()
    M.info_open = false
    sidebar.info_open = false
end

-- value or a clean placeholder; never leaks nil into ASS.
local function show(v)
    if v == nil or v == '' then return '—' end
    return tostring(v):gsub('{', '\\{')
end

-- draw the metadata panel as ASS events when open.
local function render_info(master_ass)
    if not M.info_open then return end
    local d = meta.collect()

    local w = 460
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

    local row_h, pad = 26, 18
    local h = #lines * row_h + pad * 2 + 34
    local x0 = (state.osc_param.playresx - w) / 2
    local y0 = (state.osc_param.playresy - h) / 2

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
    title:append(config.icons.info .. '  Image info  (i: close)')
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

-- element content callback: sidebar + info panel share one element.
-- Kept as a named function so the element tree can reference it.
function M.render_content()
    return ''
end

function M.activate()
    if active then return end
    active = true
    M.bind_image_keys()
end

function M.deactivate()
    active = false
    M.close_info()
    M.unbind_image_keys()
end

-- called by the shared render path after the video OSC elements.
function M.render(master_ass)
    if not active or state.ui.mode ~= 'image' then return end
    local ok, err = pcall(sidebar.render, master_ass)
    if not ok then
        require('mp.msg').error('image ui: sidebar render failed: ' .. tostring(err))
    end
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
