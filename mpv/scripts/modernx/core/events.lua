-- modernx/core/events.lua
-- Mouse and keyboard event routing.

local mp = require 'mp'
local state = require './state'
local config = require './config'
local hitbox = require './ui/hitbox'
local geo = require './utils/geometry'

-- forward refs bound by main.lua
local show_osc, request_tick, get_hidetimeout

local M = {}

-- returns true if element has a registered eventresponder for `action`
function M.element_has_action(element, action)
    return element and element.eventresponder
        and element.eventresponder[action]
end

-- route a mouse/keyboard event to the matching element
function M.process_event(source, what)
    local action = string.format('%s%s', source,
        what and ('_' .. what) or '')

    if what == 'down' or what == 'press' then
        for n = 1, #state.elements do
            if hitbox.mouse_hit(state.elements[n])
                and state.elements[n].eventresponder
                and (state.elements[n].eventresponder[source .. '_up']
                    or state.elements[n].eventresponder[action])
            then
                if what == 'down' then
                    state.active_element = n
                    state.active_event_source = source
                end
                if M.element_has_action(state.elements[n], action) then
                    state.elements[n].eventresponder[action](state.elements[n])
                end
            end
        end
    elseif what == 'up' then
        if state.elements[state.active_element] then
            local n = state.active_element
            if n == 0 then
                -- click on background (does not work)
            elseif M.element_has_action(state.elements[n], action)
                and hitbox.mouse_hit(state.elements[n])
            then
                state.elements[n].eventresponder[action](state.elements[n])
            end
            if M.element_has_action(state.elements[n], 'reset') then
                state.elements[n].eventresponder['reset'](state.elements[n])
            end
        end
        state.active_element = nil
        state.mouse_down_counter = 0
    elseif source == 'mouse_move' then
        state.mouse_in_window = true

        local mouseX, mouseY = geo.get_virt_mouse_pos()
        if (config.user_opts.minmousemove == 0)
            or (not ((state.last_mouseX == nil) or (state.last_mouseY == nil))
                and ((math.abs(mouseX - state.last_mouseX) >= config.user_opts.minmousemove)
                    or (math.abs(mouseY - state.last_mouseY) >= config.user_opts.minmousemove))
            )
        then
            show_osc()
        end
        state.last_mouseX, state.last_mouseY = mouseX, mouseY

        local n = state.active_element
        if M.element_has_action(state.elements[n], action) then
            state.elements[n].eventresponder[action](state.elements[n])
        end
    end

    -- ensure rendering after any (mouse) event - icons could change etc
    request_tick()
end

-- mouse leave handler
function M.mouse_leave()
    if get_hidetimeout() >= 0 then
        require('./core/visibility').hide_osc()
    end
    state.last_mouseX, state.last_mouseY = nil, nil
    state.mouse_in_window = false
end

function M.bind(refs)
    if refs.show_osc then show_osc = refs.show_osc end
    if refs.request_tick then request_tick = refs.request_tick end
    if refs.get_hidetimeout then get_hidetimeout = refs.get_hidetimeout end
end

return M
