-- modernx/ui/keyboard.lua
-- Directional keyboard navigation: up/down/left/right/enter/esc.
-- Bound to the user-defined `input` keymap when keyboardnavigation = true.

local mp = require 'mp'
local state = require './state'
local config = require './config'

-- forward refs (visibility functions resolved by main.lua bind)
local visibility_mode

local M = {}

-- all currently-registered mp.add_forced_key_binding names
M.osc_key_bindings = {}

-- build the keyboard navigation control tree
function M.build_keyboard_controls()
    local bottom_button_line = {}
    table.insert(bottom_button_line, 'cy_audio')
    table.insert(bottom_button_line, 'cy_sub')
    table.insert(bottom_button_line, 'pl_prev')
    table.insert(bottom_button_line, 'skipback')
    if config.user_opts.showjump then
        table.insert(bottom_button_line, 'jumpback')
    end
    table.insert(bottom_button_line, 'playpause')
    if config.user_opts.showjump then
        table.insert(bottom_button_line, 'jumpfrwd')
    end
    table.insert(bottom_button_line, 'skipfrwd')
    table.insert(bottom_button_line, 'pl_next')
    table.insert(bottom_button_line, 'tog_info')
    table.insert(bottom_button_line, 'tog_fs')

    local mapping = {}
    if require('./core/window_controls').window_controls_enabled() then
        table.insert(mapping, { 'minimize', 'maximize', 'close' })
    end
    table.insert(mapping, { 'seekbar' })
    table.insert(mapping, bottom_button_line)

    return mapping
end

local function find_active_row(keyboard_controls)
    local rows = {}
    local active_row_name = nil
    local active_row_index = 0
    local row_index = -1
    for row_name, row_controls in pairs(keyboard_controls) do
        row_index = row_index + 1
        rows[row_index] = row_name
        for _, control in pairs(row_controls) do
            if control == state.highlight_element then
                active_row_index = row_index
                active_row_name = row_name
            end
        end
    end
    return active_row_index, active_row_name, rows
end

function M.osc_kb_control_up()
    visibility_mode('always', true)
    local kc = M.build_keyboard_controls()
    local active_row_index, _, rows = find_active_row(kc)
    if active_row_index - 1 < 0 then return end
    local next_row = rows[active_row_index - 1]
    for _, control in pairs(kc[next_row]) do
        state.highlight_element = control
        return
    end
end

function M.osc_kb_control_down()
    visibility_mode('always', true)
    local kc = M.build_keyboard_controls()
    local active_row_index, _, rows = find_active_row(kc)
    if active_row_index + 1 > #rows then return end
    local next_row = rows[active_row_index + 1]
    for _, control in pairs(kc[next_row]) do
        state.highlight_element = control
        return
    end
end

function M.osc_kb_control_left()
    visibility_mode('always', true)
    local kc = M.build_keyboard_controls()
    for _, row_controls in pairs(kc) do
        local controls, controls_index = {}, -1
        local active_control_index, active_control_name
        for _, control in pairs(row_controls) do
            controls_index = controls_index + 1
            controls[controls_index] = control
            if control == state.highlight_element then
                active_control_index = controls_index
                active_control_name = control
            end
        end
        if active_control_name == 'seekbar' then
            mp.commandv('seek', -5, 'exact', 'keyframes')
            return
        end
        if active_control_name then
            if active_control_index - 1 < 0 then return end
            state.highlight_element = controls[active_control_index - 1]
            return
        end
    end
end

function M.osc_kb_control_right()
    visibility_mode('always', true)
    local kc = M.build_keyboard_controls()
    for _, row_controls in pairs(kc) do
        local controls, controls_index = {}, -1
        local active_control_index, active_control_name
        for _, control in pairs(row_controls) do
            controls_index = controls_index + 1
            controls[controls_index] = control
            if control == state.highlight_element then
                active_control_index = controls_index
                active_control_name = control
            end
        end
        if active_control_name == 'seekbar' then
            mp.commandv('seek', 5, 'exact', 'keyframes')
            return
        end
        if active_control_name then
            if active_control_index + 1 > #controls then return end
            state.highlight_element = controls[active_control_index + 1]
            return
        end
    end
end

function M.osc_kb_control_back()
    visibility_mode('auto', true)
end

function M.osc_kb_control_enter()
    visibility_mode('always', true)
    for n = 1, #state.elements do
        if state.elements[n].name == state.highlight_element then
            if require('./core/events').element_has_action(state.elements[n], 'enter') then
                state.elements[n].eventresponder['enter'](state.elements[n])
                return
            end
            if require('./core/events').element_has_action(state.elements[n], 'mbtn_left_up') then
                state.elements[n].eventresponder['mbtn_left_up'](state.elements[n])
                return
            end
        end
    end
end

local function osc_add_key_binding(key, name, fn, flags)
    M.osc_key_bindings[#M.osc_key_bindings + 1] = name
    mp.add_forced_key_binding(key, name, fn, flags)
end

-- register the keyboard nav bindings (called when visibility_mode 'always'
-- and keyboardnavigation is on)
function M.osc_enable_key_bindings()
    M.osc_key_bindings = {}
    osc_add_key_binding('up',    'osc-kb-control-prev1',   M.osc_kb_control_up,    'repeatable')
    osc_add_key_binding('down',  'osc-kb-control-next1',   M.osc_kb_control_down,  'repeatable')
    osc_add_key_binding('left',  'osc-kb-control-left1',   M.osc_kb_control_left,  'repeatable')
    osc_add_key_binding('right', 'osc-kb-control-right1',  M.osc_kb_control_right, 'repeatable')
    osc_add_key_binding('enter', 'osc-kb-control-select-alt3', M.osc_kb_control_enter, 'repeatable')
    osc_add_key_binding('esc',   'osc-kb-control-close',   M.osc_kb_control_back,  'repeatable')
end

-- unregister the keyboard nav bindings
function M.osc_disable_key_bindings()
    for _, name in ipairs(M.osc_key_bindings) do
        mp.remove_key_binding(name)
    end
    M.osc_key_bindings = {}
end

function M.bind(refs)
    if refs.visibility_mode then visibility_mode = refs.visibility_mode end
end

return M
