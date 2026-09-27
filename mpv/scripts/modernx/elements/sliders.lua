-- modernx/elements/sliders.lua
-- Slider elements: seekbar and volumebar.

local mp = require 'mp'
local config = require './config'
local tracks = require './core.tracks'
local state = require './state'

local M = {}

function M.build(new_element, ctx)
    -- seekbar
    local ne = new_element('seekbar', 'slider')
    ne.enabled = not (mp.get_property('percent-pos') == nil)
    state.slider_element = ne.enabled and ne or nil
    ne.slider.markerF = function()
        local duration = mp.get_property_number('duration', nil)
        if not (duration == nil) then
            local chapters = mp.get_property_native('chapter-list', {})
            local markers = {}
            for n = 1, #chapters do
                markers[n] = (chapters[n].time / duration * 100)
            end
            return markers
        else
            return {}
        end
    end
    ne.slider.posF = function() return mp.get_property_number('percent-pos', nil) end
    ne.slider.tooltipF = function(pos)
        local duration = mp.get_property_number('duration', nil)
        if not ((duration == nil) or (pos == nil)) then
            local possec = duration * (pos / 100)
            return mp.format_time(possec)
        else
            return ''
        end
    end
    ne.slider.seekRangesF = function()
        if not config.user_opts.seekrange then return nil end
        local cache_state = state.cache_state
        if not cache_state then return nil end
        local duration = mp.get_property_number('duration', nil)
        if (duration == nil) or duration <= 0 then return nil end
        local ranges = cache_state['seekable-ranges']
        if #ranges == 0 then return nil end
        local nranges = {}
        for _, range in pairs(ranges) do
            nranges[#nranges + 1] = {
                ['start'] = 100 * range['start'] / duration,
                ['end'] = 100 * range['end'] / duration,
            }
        end
        return nranges
    end
    ne.eventresponder['mouse_move'] = function(element)
        if not element.state.mbtnleft then return end
        local seekto = require('./ui/slider_math').get_slider_value(element)
        if (element.state.lastseek == nil)
            or (not (element.state.lastseek == seekto))
        then
            local flags = 'absolute-percent'
            if not config.user_opts.seekbarkeyframes then
                flags = flags .. '+exact'
            end
            mp.commandv('seek', seekto, flags)
            element.state.lastseek = seekto
        end
    end
    ne.eventresponder['mbtn_left_down'] = function(element)
        mp.commandv('seek',
            require('./ui/slider_math').get_slider_value(element),
            'absolute-percent', 'exact')
        element.state.mbtnleft = true
    end
    ne.eventresponder['mbtn_left_up'] = function(element) element.state.mbtnleft = false end
    ne.eventresponder['mbtn_right_down'] = function(element)
        local duration = mp.get_property_number('duration', nil)
        if not (duration == nil) then
            local chapters = mp.get_property_native('chapter-list', {})
            if #chapters > 0 then
                local pos = require('./ui/slider_math').get_slider_value(element)
                local ch = #chapters
                for n = 1, ch do
                    if chapters[n].time / duration * 100 >= pos then
                        ch = n - 1
                        break
                    end
                end
                mp.commandv('set', 'chapter', ch - 1)
            end
        end
    end
    ne.eventresponder['reset'] = function(element) element.state.lastseek = nil end

    -- volumebar
    ne = new_element('volumebar', 'slider')
    ne.visible = (state.osc_param.playresx >= 700) and config.user_opts.volumecontrol
    ne.enabled = (tracks.get_track('audio') > 0)
    ne.slider.markerF = function() return {} end
    ne.slider.seekRangesF = function() return nil end
    ne.slider.posF = function()
        local val = mp.get_property_number('volume', nil)
        return val * val / 100
    end
    ne.eventresponder['mouse_move'] = function(element)
        if not element.state.mbtnleft then return end
        local seekto = require('./ui/slider_math').get_slider_value(element)
        if (element.state.lastseek == nil)
            or (not (element.state.lastseek == seekto))
        then
            mp.commandv('set', 'volume', 10 * math.sqrt(seekto))
            element.state.lastseek = seekto
        end
    end
    ne.eventresponder['mbtn_left_down'] = function(element)
        local seekto = require('./ui/slider_math').get_slider_value(element)
        mp.commandv('set', 'volume', 10 * math.sqrt(seekto))
        element.state.mbtnleft = true
    end
    ne.eventresponder['mbtn_left_up'] = function(element) element.state.mbtnleft = false end
    ne.eventresponder['reset'] = function(element) element.state.lastseek = nil end
    ne.eventresponder['wheel_up_press'] = function() mp.commandv('osd-auto', 'add', 'volume', 5) end
    ne.eventresponder['wheel_down_press'] = function() mp.commandv('osd-auto', 'add', 'volume', -5) end
end

return M
