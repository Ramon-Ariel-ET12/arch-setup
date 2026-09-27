-- modernx/core/messages.lua
-- OSD message display, playlist and chapter list pretty-print.

local mp = require 'mp'
local utils = require 'mp.utils'
local state = require './state'
local config = require './config'

-- forward declaration; resolved when tick module is loaded (mutual package load order)
local request_tick

local M = {}

-- build a windowed slice of a list prop, marking the current item
-- pos is 1-based
function M.limited_list(prop, pos)
    local proplist = mp.get_property_native(prop, {})
    local count = #proplist
    if count == 0 then
        return count, proplist
    end

    local fs = tonumber(mp.get_property('options/osd-font-size'))
    local max = math.ceil(state.osc_param.unscaled_y * 0.75 / fs)
    if max % 2 == 0 then
        max = max - 1
    end
    local delta = math.ceil(max / 2) - 1
    local begi = math.max(math.min(pos - delta, count - max + 1), 1)
    local endi = math.min(begi + max - 1, count)

    local reslist = {}
    for i = begi, endi do
        local item = proplist[i]
        item.current = (i == pos) and true or nil
        table.insert(reslist, item)
    end
    return count, reslist
end

-- pretty playlist text
function M.get_playlist()
    local pos = mp.get_property_number('playlist-pos', 0) + 1
    local count, limlist = M.limited_list('playlist', pos)
    if count == 0 then
        return config.texts.nolist
    end

    local message = string.format(config.texts.playlist .. ' [%d/%d]:\n', pos, count)
    for i, v in ipairs(limlist) do
        local title = v.title
        local _, filename = utils.split_path(v.filename)
        if title == nil then
            title = filename
        end
        message = string.format('%s %s %s\n', message,
            (v.current and '●' or '○'), title)
    end
    return message
end

-- pretty chapter list text
function M.get_chapterlist()
    local pos = mp.get_property_number('chapter', 0) + 1
    local count, limlist = M.limited_list('chapter-list', pos)
    if count == 0 then
        return config.texts.nochapter
    end

    local message = string.format(config.texts.chapter .. ' [%d/%d]:\n', pos, count)
    for i, v in ipairs(limlist) do
        local time = mp.format_time(v.time)
        local title = v.title
        if title == nil then
            title = string.format(config.texts.chapter .. ' %02d', i)
        end
        message = string.format('%s[%s] %s %s\n', message, time,
            (v.current and '●' or '○'), title)
    end
    return message
end

-- queue an OSD message for display
function M.show_message(text, duration)
    if duration == nil then
        duration = tonumber(mp.get_property('options/osd-duration')) / 1000
    end

    -- cut text short to avoid massive slowdowns
    text = string.sub(text, 0, 4000)
    -- replace linebreaks with ASS linebreaks
    text = string.gsub(text, '\n', '\\N')

    state.message_text = text

    if not state.message_hide_timer then
        state.message_hide_timer = mp.add_timeout(0, request_tick)
    end
    state.message_hide_timer:kill()
    state.message_hide_timer.timeout = duration
    state.message_hide_timer:resume()
    request_tick()
end

-- resolve the forward declaration late to break the load cycle
function M.bind_request_tick(fn)
    request_tick = fn
end

return M
