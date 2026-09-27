-- modernx/elements/transport.lua
-- Transport control elements: pl_prev, pl_next, skipback, skipfrwd,
-- jumpback, jumpfrwd, playpause.

local mp = require 'mp'
local config = require './config'
local messages = require './core.messages'

local M = {}

-- build all transport elements with the given context
function M.build(new_element, ctx)
    local pl_pos = ctx.pl_pos
    local pl_count = ctx.pl_count
    local have_pl = ctx.have_pl
    local have_ch = ctx.have_ch
    local loop = ctx.loop

    -- pl_prev
    local ne = new_element('pl_prev', 'button')
    ne.content = config.icons.previous
    ne.enabled = (pl_pos > 1) or (loop ~= 'no')
    ne.eventresponder['mbtn_left_up'] = function() mp.commandv('playlist-prev', 'weak') end
    ne.eventresponder['mbtn_right_up'] = function() messages.show_message(messages.get_playlist()) end

    -- pl_next
    ne = new_element('pl_next', 'button')
    ne.content = config.icons.next
    ne.enabled = (have_pl and (pl_pos < pl_count)) or (loop ~= 'no')
    ne.eventresponder['mbtn_left_up'] = function() mp.commandv('playlist-next', 'weak') end
    ne.eventresponder['mbtn_right_up'] = function() messages.show_message(messages.get_playlist()) end

    -- playpause
    ne = new_element('playpause', 'button')
    ne.content = function()
        if mp.get_property('pause') == 'yes' then
            return config.icons.play
        else
            return config.icons.pause
        end
    end
    ne.eventresponder['mbtn_left_up'] = function()
        if mp.get_property_bool('eof-reached') then
            mp.command('no-osd seek 0 absolute')
            mp.set_property('pause', 'no')
        else
            mp.commandv('cycle', 'pause')
        end
    end

    if config.user_opts.showjump then
        local jumpamount = config.user_opts.jumpamount
        local jumpmode = config.user_opts.jumpmode
        local icons = config.jumpicons.default
        if config.user_opts.jumpiconnumber then
            icons = config.jumpicons[jumpamount] or config.jumpicons.default
        end

        -- jumpback
        ne = new_element('jumpback', 'button')
        ne.softrepeat = true
        ne.content = icons[1]
        ne.eventresponder['mbtn_left_down'] = function() mp.commandv('seek', -jumpamount, jumpmode) end
        ne.eventresponder['shift+mbtn_left_down'] = function() mp.commandv('frame-back-step') end
        ne.eventresponder['mbtn_right_down'] = function() mp.commandv('seek', -60, jumpmode) end
        ne.eventresponder['enter'] = function() mp.commandv('seek', -jumpamount, jumpmode) end

        -- jumpfrwd
        ne = new_element('jumpfrwd', 'button')
        ne.softrepeat = true
        ne.content = icons[2]
        ne.eventresponder['mbtn_left_down'] = function() mp.commandv('seek', jumpamount, jumpmode) end
        ne.eventresponder['shift+mbtn_left_down'] = function() mp.commandv('frame-step') end
        ne.eventresponder['mbtn_right_down'] = function() mp.commandv('seek', 60, jumpmode) end
        ne.eventresponder['enter'] = function() mp.commandv('seek', jumpamount, jumpmode) end
    end

    -- skipback
    ne = new_element('skipback', 'button')
    ne.softrepeat = true
    ne.content = config.icons.backward
    ne.enabled = have_ch
    ne.eventresponder['mbtn_left_down'] = function() mp.commandv('add', 'chapter', -1) end
    ne.eventresponder['mbtn_right_down'] = function() messages.show_message(messages.get_chapterlist()) end
    ne.eventresponder['enter'] = function() mp.commandv('add', 'chapter', -1) end

    -- skipfrwd
    ne = new_element('skipfrwd', 'button')
    ne.softrepeat = true
    ne.content = config.icons.forward
    ne.enabled = have_ch
    ne.eventresponder['mbtn_left_down'] = function() mp.commandv('add', 'chapter', 1) end
    ne.eventresponder['mbtn_right_down'] = function() messages.show_message(messages.get_chapterlist()) end
    ne.eventresponder['enter'] = function() mp.commandv('add', 'chapter', 1) end
end

return M
