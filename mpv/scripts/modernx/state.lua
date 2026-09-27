-- modernx/state.lua
-- Runtime state singleton. All modules share this table.

local mp = require 'mp'

local M = {}

-- playback / lifecycle
M.showtime = nil
M.osc_visible = false
M.anistart = nil
M.anitype = nil
M.animation = nil
M.initREQ = false
M.enabled = true
M.input_enabled = true
M.showhide_enabled = false

-- mouse / input
M.last_mouseX = nil
M.last_mouseY = nil
M.mouse_in_window = false
M.mouse_down_counter = 0
M.active_element = nil
M.active_event_source = nil

-- window state
M.fullscreen = false
M.border = true
M.maximized = false
M.mute = false
M.idle = false
M.paused = false

-- timers
M.tick_timer = nil
M.tick_last_time = 0
M.hide_timer = nil
M.message_hide_timer = nil

-- message subsystem
M.message_text = nil

-- cache state (seekable-ranges)
M.cache_state = nil

-- track mirror (formerly implicit globals tracks_osc / tracks_mpv)
M.tracks_osc = { video = {}, audio = {}, sub = {} }
M.tracks_mpv = { video = {}, audio = {}, sub = {} }

-- chapter state (sorted list, kept in sync via chapter-list observer)
M.chapter_list = {}

-- layout canvas state (formerly osc_param, mutated by osc_init)
M.osc_param = {
    playresy = 0,
    playresx = 0,
    display_aspect = 1,
    unscaled_y = 0,
    areas = {},
}

-- screen size change detection
M.mp_screen_sizeX = nil
M.mp_screen_sizeY = nil

-- forced title override (chapter hover)
M.forced_title = nil
M.slider_element = nil

-- timecode toggles (seeded from user_opts in main.lua)
M.rightTC_trem = false
M.fulltime = false
M.lastvisibility = 'auto'
M.highlight_element = 'cy_audio'

-- application state: what media is loaded and which UI mode is active.
-- media.* is refreshed from core/media.lua on file load; ui.mode is
-- driven by ui/manager.lua ('video' | 'image').
M.media = { path = nil, type = 'unknown', index = nil, count = 0 }
M.ui = { mode = 'video' }

-- elements registry (rebuilt on every osc_init)
M.elements = {}

-- the OSD overlay (created at load time)
M.osd = mp.create_osd_overlay('ass-events')

return M
