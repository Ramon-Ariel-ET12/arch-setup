-- main.lua
-- Entry point. Loaded by modernx.lua (the stub).
-- Orchestrates module loading, forward-ref binding, mpv event
-- registration, and boot.

local mp     = require 'mp'
local opt    = require 'mp.options'
local msg    = require 'mp.msg'
local utils  = require 'mp.utils'

-- ============================================================
-- 1. Load modules
-- ============================================================
local config = require './config'
local state  = require './state'

-- apply language
config.texts = config.language[config.user_opts.language] or config.language['eng']
-- seed user_opts from mpv.conf and osc.conf
opt.read_options(config.user_opts, 'osc', function(list) update_options(list) end)

-- core modules
local visibility        = require './core/visibility'
local messages          = require './core/messages'
local tick              = require './core/tick'
local events            = require './core/events'
local chapters          = require './core/chapters'
local tracks            = require './core/tracks'
local osc_init          = require './core/osc_init'
local render            = require './core/render'
local idle              = require './core/idle'
local layout            = require './core/layout'
local window_controls   = require './core/window_controls'

-- ui / render
local ui_kb             = require './ui/keyboard'
local thumbfast_m       = require './ui/thumbfast'

-- ============================================================
-- 2. Seed state from user_opts (toggles that depend on config)
-- ============================================================
state.rightTC_trem      = not config.user_opts.timetotal
state.fulltime          = config.user_opts.timems
state.lastvisibility    = config.user_opts.visibility
state.highlight_element = 'cy_audio'

-- ============================================================
-- 3. Resolve forward references between modules
-- ============================================================
tick.bind({
    request_tick = tick.request_tick,
    show_osc = visibility.show_osc,
    hide_osc = visibility.hide_osc,
    osc_visible = visibility.osc_visible,
    enable_osc = visibility.enable_osc,
    always_on = visibility.always_on,
    visibility_mode = visibility.visibility_mode,
    do_enable_keybindings = tick.do_enable_keybindings,
    render = render.render,
    image_render = render.render_image,
})
visibility.bind({
    request_tick = tick.request_tick,
    do_enable_keybindings = tick.do_enable_keybindings,
})
events.bind({
    show_osc = visibility.show_osc,
    request_tick = tick.request_tick,
    get_hidetimeout = visibility.get_hidetimeout,
})
render.bind({
    request_tick = tick.request_tick,
    request_init_resize = tick.request_init_resize,
    hide_osc = visibility.hide_osc,
})
ui_kb.bind({ visibility_mode = visibility.visibility_mode })
messages.bind_request_tick(tick.request_tick)

-- ============================================================
-- 4. User-options validation and on-change
-- ============================================================
function validate_user_opts()
    if config.user_opts.windowcontrols ~= 'auto'
        and config.user_opts.windowcontrols ~= 'yes'
        and config.user_opts.windowcontrols ~= 'no'
    then
        msg.warn('windowcontrols cannot be \'' ..
            config.user_opts.windowcontrols .. '\'. Ignoring.')
        config.user_opts.windowcontrols = 'auto'
    end
end

function update_options(_)
    validate_user_opts()
    tick.request_tick()
    visibility.visibility_mode(config.user_opts.visibility, true)
    tick.update_duration_watch()
    tick.request_init()
end

validate_user_opts()
tick.update_duration_watch()

-- ============================================================
-- 4b. Application layer: shared services + UI mode routing.
-- Thin by design: media detection lives in core/media.lua,
-- mode switching in ui/manager.lua, feature UI in video/ + image/.
-- ============================================================
local manager = require './ui.manager'
manager.register('video', require('./video.ui'))
manager.register('image', require('./image.ui'))

local function on_media_changed()
    manager.update_media_state()
    tick.request_init()
end

-- ============================================================
-- 5. Automatically disable mpv's built-in OSC
-- ============================================================
local builtin_osc_enabled = mp.get_property_native('osc')
if builtin_osc_enabled then
    mp.set_property_native('osc', false)
end

-- ============================================================
-- 6. Register mpv event handlers, observers, and message handlers
-- ============================================================
mp.register_event('shutdown', function() end) -- no-op
mp.register_event('start-file', tick.request_init)
mp.register_event('file-loaded', on_media_changed)
mp.register_event('end-file', on_media_changed)
mp.observe_property('track-list', nil, function() on_media_changed() end)
mp.observe_property('playlist', nil, function()
    require('./image.navigation').sync()
    on_media_changed()
end)
mp.observe_property('chapter-list', 'native', function(_, list)
    list = list or {}
    table.sort(list, function(a, b) return a.time < b.time end)
    state.chapter_list = list
    tick.update_duration_watch()
    tick.request_init()
end)
mp.observe_property('fullscreen', 'bool', function(_, val)
    state.fullscreen = val
    tick.request_init_resize()
end)
mp.observe_property('mute', 'bool', function(_, val) state.mute = val end)
mp.observe_property('border', 'bool', function(_, val)
    state.border = val
    tick.request_init_resize()
end)
mp.observe_property('window-maximized', 'bool', function(_, val)
    state.maximized = val
    tick.request_init_resize()
end)
mp.observe_property('idle-active', 'bool', function(_, val)
    state.idle = val
    tick.request_tick()
end)
mp.observe_property('pause', 'bool', visibility.pause_state)
mp.observe_property('demuxer-cache-state', 'native', tick.cache_state)
mp.observe_property('vo-configured', 'bool', function() tick.request_tick() end)
mp.observe_property('playback-time', 'number', function() tick.request_tick() end)
mp.observe_property('osd-dimensions', 'native', function() tick.request_init_resize() end)

-- script messages
mp.register_script_message('osc-message', messages.show_message)
mp.register_script_message('osc-chapterlist', function(dur)
    messages.show_message(messages.get_chapterlist(), dur)
end)
mp.register_script_message('osc-playlist', function(dur)
    messages.show_message(messages.get_playlist(), dur)
end)
mp.register_script_message('osc-tracklist', function(dur)
    local buf = {}
    for k, _ in pairs(tracks.nicetypes) do
        table.insert(buf, tracks.get_tracklist(k))
    end
    messages.show_message(table.concat(buf, '\n\n'), dur)
end)
mp.register_script_message('osc-visibility', visibility.visibility_mode)
mp.register_script_message('thumbfast-info', thumbfast_m.handle)
-- image mode: input.conf maps keys here so they survive even when
-- mpv's builtin scripts claim the key for themselves.
mp.register_script_message('image-info-toggle', function()
    require('./image.ui').toggle_info()
    tick.request_tick()
end)

-- mouse showhide keymaps
mp.set_key_bindings({
    { 'mouse_move',  function() events.process_event('mouse_move', nil) end },
    { 'mouse_leave', events.mouse_leave },
}, 'showhide', 'force')
mp.set_key_bindings({
    { 'mouse_move',  function() events.process_event('mouse_move', nil) end },
    { 'mouse_leave', events.mouse_leave },
}, 'showhide_wc', 'force')
tick.do_enable_keybindings()

-- mouse input keymap
mp.set_key_bindings({
    { 'mbtn_left', function() events.process_event('mbtn_left', 'up') end,
        function() events.process_event('mbtn_left', 'down') end },
    { 'shift+mbtn_left', function() events.process_event('shift+mbtn_left', 'up') end,
        function() events.process_event('shift+mbtn_left', 'down') end },
    { 'mbtn_right', function() events.process_event('mbtn_right', 'up') end,
        function() events.process_event('mbtn_right', 'down') end },
    { 'mbtn_mid', function() events.process_event('shift+mbtn_left', 'up') end,
        function() events.process_event('shift+mbtn_left', 'down') end },
    { 'wheel_up',            function() events.process_event('wheel_up', 'press') end },
    { 'wheel_down',          function() events.process_event('wheel_down', 'press') end },
    { 'mbtn_left_dbl',       'ignore' },
    { 'shift+mbtn_left_dbl', 'ignore' },
    { 'mbtn_right_dbl',      'ignore' },
}, 'input', 'force')
mp.enable_key_bindings('input')

-- window-controls keymap
mp.set_key_bindings({
    { 'mbtn_left', function() events.process_event('mbtn_left', 'up') end,
        function() events.process_event('mbtn_left', 'down') end },
}, 'window-controls', 'force')
mp.enable_key_bindings('window-controls')

-- global visibility cycle key
mp.add_key_binding(nil, 'visibility', function() visibility.visibility_mode('cycle') end)

-- ============================================================
-- 7. Boot: initial visibility_mode kicks the first tick
-- ============================================================
visibility.visibility_mode(config.user_opts.visibility, true)

-- zero-size mouse areas so the events don't fire before init
require('./utils/geometry').set_virt_mouse_area(0, 0, 0, 0, 'input')
require('./utils/geometry').set_virt_mouse_area(0, 0, 0, 0, 'window-controls')
