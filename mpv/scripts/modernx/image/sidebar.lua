-- modernx/image/sidebar.lua
-- Image playlist sidebar: text rows + info icon, rendered as ASS events
-- on the shared OSD. No thumbnails here (see thumbnails.lua doc):
-- decoding hundreds of images for a sidebar is the wrong tradeoff,
-- so rows are filename text with a clear active marker instead.
-- Consumes state.media + core/media; owns no global state of its own.

local mp = require 'mp'
local assdraw = require 'mp.assdraw'
local utils = require 'mp.utils'
local state = require './state'
local config = require './config'
local media = require './core.media'
local nav = require './image.navigation'

local M = {}

-- layout constants (virtual ASS px); tweak here, not in render math.
M.WIDTH = 300
M.ROW_H = 30
M.MAX_ROWS = 15
M.MARGIN = 16

-- scroll offset into the playlist; kept local to this module.
M.offset = 0
M.visible = true
M.info_open = false

-- basename without extension noise; truncates to fit the column.
local function short_name(filename, maxlen)
    maxlen = maxlen or 34
    local _, base = utils.split_path(filename or '')
    if base == '' then base = filename or '?' end
    if #base > maxlen then base = base:sub(1, maxlen - 3) .. '...' end
    return base
end

-- keep the active row inside the visible window.
local function clamp_offset(active, count)
    local max_off = math.max(0, count - M.MAX_ROWS)
    if active - M.offset > M.MAX_ROWS then M.offset = active - M.MAX_ROWS end
    if active - M.offset < 1 then M.offset = active - 1 end
    if M.offset > max_off then M.offset = max_off end
    if M.offset < 0 then M.offset = 0 end
end

-- sidebar state snapshot for render + hit-testing.
-- NB: mpv populates the playlist asynchronously, so entries may be empty
-- on the very first file-loaded; render() then draws nothing until the
-- playlist observer fires and requests a fresh tick.
function M.view()
    local entries = media.playlist_entries()
    local active = media.playlist_index(entries) or 1
    if #entries == 0 then active = 0 end
    clamp_offset(active, #entries)
    return { entries = entries, active = active, offset = M.offset }
end

-- draw the sidebar into the master ASS buffer.
-- Empty playlist (mpv still building it) renders a slim "loading" panel
-- instead of nothing, so image mode never looks broken on fast machines.
function M.render(master_ass)
    if not M.visible or state.ui.mode ~= 'image' then return end
    local v = M.view()

    local w, h = mp.get_osd_size()
    if w <= 0 or h <= 0 then
        -- headless/test fallback: assume 720p canvas so the sidebar
        -- still renders (and stays testable) without a VO.
        w, h = 1280, 720
    end
    if state.osc_param.playresx == 0 or state.osc_param.playresy == 0 then
        state.osc_param.playresx = w
        state.osc_param.playresy = h
    end

    local x0 = state.osc_param.playresx - M.WIDTH
    local rows = math.min(M.MAX_ROWS, math.max(0, #v.entries - v.offset))
    local panel_h, y0
    if #v.entries == 0 then
        panel_h = 2 * M.MARGIN + M.ROW_H
        y0 = math.max(0, (state.osc_param.playresy - panel_h) / 2)
    else
        panel_h = rows * M.ROW_H + 2 * M.MARGIN + M.ROW_H
        y0 = math.max(0, (state.osc_param.playresy - panel_h) / 2)
    end

    local bg = assdraw.ass_new()
    bg:new_event()
    bg:pos(x0, y0)
    bg:an(7)
    bg:append(config.osc_styles.TransBg)
    bg:draw_start()
    bg:rect_cw(0, 0, M.WIDTH, panel_h)
    bg:draw_stop()
    master_ass:merge(bg)

    local header = assdraw.ass_new()
    header:new_event()
    header:pos(x0 + M.MARGIN, y0 + M.MARGIN)
    header:an(7)
    header:append(config.osc_styles.Tooltip)
    if #v.entries == 0 then
        header:append(config.icons.picture .. '  loading…')
    else
        header:append(string.format('%s  %d/%d', config.icons.folder, v.active, #v.entries))
    end
    master_ass:merge(header)

    for i = 1, rows do
        local idx = v.offset + i
        local entry = v.entries[idx]
        if entry == nil then break end
        local y = y0 + M.MARGIN + M.ROW_H + (i - 1) * M.ROW_H
        local current = (idx == v.active)

        local row = assdraw.ass_new()
        row:new_event()
        row:pos(x0 + M.MARGIN, y)
        row:an(7)
        if current then
            row:append('{\\1c&HE39C42&\\b1}')
        else
            row:append('{\\1c&HFFFFFF&}')
        end
        row:append(string.format('{\\fn%s\\fs14}%s %s',
            config.user_opts.font, current and '●' or '○',
            short_name(entry.filename):gsub('{', '\\{')))
        master_ass:merge(row)

        -- stash row hitbox for click-to-select (virtual coords)
        entry._sb = { x0 = x0, y0 = y, x1 = x0 + M.WIDTH, y1 = y + M.ROW_H, idx = idx }
    end

    local info = assdraw.ass_new()
    info:new_event()
    info:pos(x0 + M.WIDTH - M.MARGIN, y0 + panel_h - M.MARGIN)
    info:an(9)
    info:append(config.osc_styles.Ctrl3)
    info:append(config.icons.info)
    master_ass:merge(info)
    M._info_hit = { x0 = x0 + M.WIDTH - M.MARGIN - 30, y0 = y0 + panel_h - M.MARGIN - 30,
        x1 = x0 + M.WIDTH, y1 = y0 + panel_h - M.MARGIN + 6 }
end

-- click handling in virtual ASS coords; returns true when consumed.
function M.click(x, y)
    if not M.visible or state.ui.mode ~= 'image' then return false end
    if M._info_hit and x >= M._info_hit.x0 and x <= M._info_hit.x1
        and y >= M._info_hit.y0 and y <= M._info_hit.y1 then
        require('./image.ui').toggle_info()
        return true
    end
    local v = M.view()
    for i = 1, math.min(M.MAX_ROWS, #v.entries - v.offset) do
        local entry = v.entries[v.offset + i]
        local hb = entry and entry._sb
        if hb and x >= hb.x0 and x <= hb.x1 and y >= hb.y0 and y <= hb.y1 then
            nav.goto_index(hb.idx)
            return true
        end
    end
    return false
end

function M.scroll(delta)
    local entries = media.playlist_entries()
    M.offset = M.offset + delta
    local max_off = math.max(0, #entries - M.MAX_ROWS)
    if M.offset > max_off then M.offset = max_off end
    if M.offset < 0 then M.offset = 0 end
end

function M.toggle()
    M.visible = not M.visible
end

return M
