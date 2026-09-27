-- modernx/core/visibility.lua
-- OSC show/hide FSM, enable/disable, visibility_mode (auto/always/never/cycle).

local mp = require 'mp'
local msg = require 'mp.msg'
local state = require './state'
local config = require './config'

-- forward declaration; bound by main.lua
local request_tick, do_enable_keybindings

local M = {}

-- internal: compute hide-timeout in ms; -1 = always-on
function M.get_hidetimeout()
    if config.user_opts.visibility == 'always' then
        return -1
    end
    return config.user_opts.hidetimeout
end

function M.show_osc()
    -- show when disabled can happen (e.g. mouse_move) due to async/delayed unbinding
    if not state.enabled then return end

    msg.trace('show_osc')
    state.showtime = mp.get_time()
    M.osc_visible(true)

    if config.user_opts.keyboardnavigation == true then
        require('./ui/keyboard').osc_enable_key_bindings()
    end

    if config.user_opts.fadeduration > 0 then
        state.anitype = nil
    end
end

function M.hide_osc()
    msg.trace('hide_osc')
    if not state.enabled then
        state.osc_visible = false
        require('./render/set_osd').render_wipe()
        if config.user_opts.keyboardnavigation == true then
            require('./ui/keyboard').osc_disable_key_bindings()
        end
    elseif config.user_opts.fadeduration > 0 then
        if not (state.osc_visible == false) then
            state.anitype = 'out'
            request_tick()
        end
    else
        M.osc_visible(false)
    end
end

function M.osc_visible(visible)
    if state.osc_visible ~= visible then
        state.osc_visible = visible
    end
    request_tick()
end

function M.always_on(val)
    if state.enabled then
        if val then
            M.show_osc()
        else
            M.hide_osc()
        end
    end
end

function M.enable_osc(enable)
    state.enabled = enable
    if enable then
        do_enable_keybindings()
    else
        M.hide_osc()
        if state.showhide_enabled then
            mp.disable_key_bindings('showhide')
            mp.disable_key_bindings('showhide_wc')
        end
        state.showhide_enabled = false
    end
end

-- mode can be auto/always/never/cycle
-- the modes only affect internal variables and not stored on its own.
function M.visibility_mode(mode, no_osd)
    if mode == 'cycle' then
        if not state.enabled then
            mode = 'auto'
        elseif config.user_opts.visibility ~= 'always' then
            mode = 'always'
        else
            mode = 'never'
        end
    end

    if mode == 'auto' then
        M.always_on(false)
        M.enable_osc(true)
    elseif mode == 'always' then
        M.enable_osc(true)
        M.always_on(true)
    elseif mode == 'never' then
        M.enable_osc(false)
    else
        msg.warn('Ignoring unknown visibility mode \"' .. mode .. '\"')
        return
    end

    config.user_opts.visibility = mode
    mp.set_property_native('user-data/osc/visibility', config.user_opts.visibility)

    if not no_osd and tonumber(mp.get_property('osd-level')) >= 1 then
        mp.osd_message('OSC visibility: ' .. mode)
    end

    mp.disable_key_bindings('input')
    mp.disable_key_bindings('window-controls')
    state.input_enabled = false
    request_tick()
end

-- pause observer handler: drives state.paused and the showonpause behavior
function M.pause_state(_, enabled)
    state.paused = enabled
    mp.add_timeout(0.1, function() state.osd:update() end)
    if config.user_opts.showonpause then
        if enabled then
            state.lastvisibility = config.user_opts.visibility
            M.visibility_mode('always', true)
            M.show_osc()
        else
            M.visibility_mode(state.lastvisibility, true)
        end
    end
    request_tick()
end

-- main.lua wires forward references
function M.bind(refs)
    if refs.request_tick then request_tick = refs.request_tick end
    if refs.do_enable_keybindings then do_enable_keybindings = refs.do_enable_keybindings end
end

return M
