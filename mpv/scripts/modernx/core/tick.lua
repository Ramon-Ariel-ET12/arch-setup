-- modernx/core/tick.lua
-- Tick pump and request/init scheduling.
-- Holds the `tick` function and `request_tick` (which tick uses).
-- `request_tick` is resolved via bind_request_tick by main.lua
-- to break a load cycle with core/visibility and other consumers.

local mp = require 'mp'
local msg = require 'mp.msg'
local state = require './state'
local config = require './config'

-- forward declarations; bound in main.lua after all modules load
local request_init
local show_osc, hide_osc, osc_visible, enable_osc, always_on, visibility_mode
local do_enable_keybindings
local render

local M = {}

-- internal: rate-limited tick scheduler
local function _request_tick()
    if state.tick_timer == nil then
        state.tick_timer = mp.add_timeout(0, M.tick)
    end

    if not state.tick_timer:is_enabled() then
        local now = mp.get_time()
        local timeout = config.tick_delay - (now - state.tick_last_time)
        if timeout < 0 then
            timeout = 0
        end
        state.tick_timer.timeout = timeout
        state.tick_timer:resume()
    end
end

M.request_tick = _request_tick

-- request a full osc_init() on the next tick
function M.request_init()
    state.initREQ = true
    _request_tick()
end

-- request a full osc_init() and force an immediate update
function M.request_init_resize()
    M.request_init()
    if state.tick_timer then
        state.tick_timer:kill()
        state.tick_timer.timeout = 0
        state.tick_timer:resume()
    end
end

-- cache state observer handler (no-op beyond storing + tick)
function M.cache_state(_, st)
    state.cache_state = st
    _request_tick()
end

-- enable the showhide / showhide_wc key bindings
function M.do_enable_keybindings()
    if state.enabled then
        if not state.showhide_enabled then
            mp.enable_key_bindings('showhide', 'allow-vo-dragging+allow-hide-cursor')
            mp.enable_key_bindings('showhide_wc', 'allow-vo-dragging+allow-hide-cursor')
        end
        state.showhide_enabled = true
    end
end
M._do_enable_keybindings = M.do_enable_keybindings

-- duration is observed only for chapter-marker positions in live streams
function M.on_duration()
    M.request_init()
end

local duration_watched = false
-- (re)attach or detach the duration observer based on livemarkers + chapters
function M.update_duration_watch()
    local want_watch = config.user_opts.livemarkers
        and (mp.get_property_number('chapters', 0) or 0) > 0
        and true or false

    if want_watch ~= duration_watched then
        if want_watch then
            mp.observe_property('duration', nil, M.on_duration)
        else
            mp.unobserve_property(M.on_duration)
        end
        duration_watched = want_watch
    end
end

-- called by mpv on every frame
function M.tick()
    if not state.enabled then return end

    if state.idle then
        -- idle screen is rendered in core/idle.lua
        require('./core/idle').render_idle()
    elseif (state.fullscreen and config.user_opts.showfullscreen)
        or (not state.fullscreen and config.user_opts.showwindowed)
    then
        -- render the OSC
        render()
    else
        -- Flush OSD
        require('./render/set_osd').set_osd(
            state.osc_param.playresy, state.osc_param.playresy, '')
    end

    state.tick_last_time = mp.get_time()

    if state.anitype ~= nil then
        if not state.idle
            and (not state.anistart
                or mp.get_time() < 1 + state.anistart + config.user_opts.fadeduration / 1000)
        then
            -- animating or starting, or still within 1s past the deadline
            _request_tick()
        else
            state.anistart = nil
            state.animation = nil
            state.anitype = nil
        end
    end
end

-- main.lua wires forward references into the tick module
function M.bind(refs)
    if refs.request_init then request_init = refs.request_init end
    if refs.show_osc then show_osc = refs.show_osc end
    if refs.hide_osc then hide_osc = refs.hide_osc end
    if refs.osc_visible then osc_visible = refs.osc_visible end
    if refs.enable_osc then enable_osc = refs.enable_osc end
    if refs.always_on then always_on = refs.always_on end
    if refs.visibility_mode then visibility_mode = refs.visibility_mode end
    if refs.do_enable_keybindings then do_enable_keybindings = refs.do_enable_keybindings end
    if refs.render then render = refs.render end
end

return M
