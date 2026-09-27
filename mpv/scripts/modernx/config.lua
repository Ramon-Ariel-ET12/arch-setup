-- modernx/config.lua
-- User options, localization, and rendering constants.

local opt = require 'mp.options'

local M = {}

-- default user option values (may change them in osc.conf)
M.user_opts = {
    showwindowed = true,            -- show OSC when windowed?
    showfullscreen = true,          -- show OSC when fullscreen?
    idlescreen = true,              -- draw logo and text when idle
    scalewindowed = 1.0,            -- scaling of the controller when windowed
    scalefullscreen = 1.0,          -- scaling of the controller when fullscreen
    scaleforcedwindow = 2.0,        -- scaling when rendered on a forced window
    vidscale = true,                -- scale the controller with the video?
    hidetimeout = 1500,             -- duration in ms until the OSC hides if no
                                    -- mouse movement. enforced non-negative for
                                    -- the user, but internally negative is 'always-on'.
    fadeduration = 250,             -- duration of fade out in ms, 0 = no fade
    minmousemove = 1,               -- minimum amount of pixels the mouse has to
                                    -- move between ticks to make the OSC show up
    iamaprogrammer = false,         -- use native mpv values and disable OSC
                                    -- internal track list management
    font = 'mpv-osd-symbols',       -- default osc font
    seekbarhandlesize = 1.0,        -- size ratio of the slider handle, range 0 ~ 1
    seekrange = true,               -- show seekrange overlay
    seekrangealpha = 64,            -- transparency of seekranges
    seekbarkeyframes = true,        -- use keyframes when dragging the seekbar
    showjump = true,                -- show "jump forward/backward 5 seconds" buttons
    jumpamount = 5,                 -- change the jump amount (in seconds by default)
    jumpiconnumber = true,          -- show different icon when jumpamount is 5, 10, or 30
    jumpmode = 'exact',             -- seek mode for jump buttons. e.g.
                                    -- 'exact', 'relative+keyframes', etc.
    title = '${media-title}',       -- string compatible with property-expansion
    showtitle = true,               -- show title in OSC
    showonpause = true,             -- whether to disable the hide timeout on pause
    timetotal = true,               -- display total time instead of remaining time?
    timems = false,                 -- Display time down to millliseconds by default
    visibility = 'auto',            -- only used at init to set visibility_mode(...)
    windowcontrols = 'auto',        -- whether to show window controls
    greenandgrumpy = false,         -- disable santa hat
    language = 'eng',               -- eng=English, chs=Chinese, pl=Polish
    volumecontrol = true,           -- whether to show mute button and volume slider
    keyboardnavigation = false,     -- enable directional keyboard navigation
    chapter_fmt = "Chapter: %s",    -- chapter print format for seekbar-hover. "no" to disable
    livemarkers = true,             -- re-init on duration change when chapters exist
}

-- localization tables
M.language = {
    ['eng'] = {
        welcome = '{\\fs24\\1c&H0&\\1c&HFFFFFF&}Drop files or URLs to play here.',
        off = 'OFF',
        na = 'n/a',
        none = 'none',
        video = 'Video',
        audio = 'Audio',
        subtitle = 'Subtitle',
        available = 'Available ',
        track = ' Tracks:',
        playlist = 'Playlist',
        nolist = 'Empty playlist.',
        chapter = 'Chapter',
        nochapter = 'No chapters.',
    },
    ['chs'] = {
        welcome = '{\\1c&H00\\bord0\\fs30\\fn微软雅黑 light\\fscx125}MPV{\\fscx100} 播放器',
        off = '关闭',
        na = 'n/a',
        none = '无',
        video = '视频',
        audio = '音频',
        subtitle = '字幕',
        available = '可选',
        track = '：',
        playlist = '播放列表',
        nolist = '无列表信息',
        chapter = '章节',
        nochapter = '无章节信息',
    },
    ['pl'] = {
        welcome = '{\\fs24\\1c&H0&\\1c&HFFFFFF&}Upuść plik lub łącze URL do odtworzenia.',
        off = 'WYŁ.',
        na = 'n/a',
        none = 'nic',
        video = 'Wideo',
        audio = 'Ścieżka audio',
        subtitle = 'Napisy',
        available = 'Dostępne ',
        track = ' Ścieżki:',
        playlist = 'Lista odtwarzania',
        nolist = 'Lista odtwarzania pusta.',
        chapter = 'Rozdział',
        nochapter = 'Brak rozdziałów.',
    },
}

-- text strings selected from user_opts.language
M.texts = M.language[M.user_opts.language] or M.language['eng']

-- icons (utf-8 bytes)
M.icons = {
    previous = '\239\142\181',
    next = '\239\142\180',
    play = '\239\142\170',
    pause = '\239\142\167',
    backward = '\239\142\160',
    forward = '\239\142\159',
    audio = '\239\142\183',
    volume = '\239\142\188',
    volume_mute = '\239\142\187',
    sub = '\239\143\147',
    minimize = '\239\133\172',
    fullscreen = '\239\133\173',
    info = '',
}

-- icons for jump button depending on jumpamount
M.jumpicons = {
    [5] = { '\239\142\177', '\239\142\163' },
    [10] = { '\239\142\175', '\239\142\161' },
    [30] = { '\239\142\176', '\239\142\162' },
    default = { '\239\142\178\t', '\239\142\178' },
}

-- ASS style fragments (built with the user-configured font name)
M.osc_styles = {
    TransBg = '{\\blur100\\bord150\\1c&H000000&\\3c&H000000&}',
    SeekbarBg = '{\\blur0\\bord0\\1c&HFFFFFF&}',
    SeekbarFg = '{\\blur1\\bord1\\1c&HE39C42&}',
    VolumebarBg = '{\\blur0\\bord0\\1c&H999999&}',
    VolumebarFg = '{\\blur1\\bord1\\1c&HFFFFFF&}',
    Ctrl1 = '{\\blur0\\bord0\\1c&HFFFFFF&\\3c&HFFFFFF&\\fs36\\fnmaterial-design-iconic-font}',
    Ctrl2 = '{\\blur0\\bord0\\1c&HFFFFFF&\\3c&HFFFFFF&\\fs24\\fnmaterial-design-iconic-font}',
    Ctrl2Flip = '{\\blur0\\bord0\\1c&HFFFFFF&\\3c&HFFFFFF&\\fs24\\fnmaterial-design-iconic-font\\fry180',
    Ctrl3 = '{\\blur0\\bord0\\1c&HFFFFFF&\\3c&HFFFFFF&\\fs24\\fnmaterial-design-iconic-font}',
    Time = '{\\blur0\\bord0\\1c&HFFFFFF&\\3c&H000000&\\fs17\\fn' .. M.user_opts.font .. '}',
    Tooltip = '{\\blur1\\bord0.5\\1c&HFFFFFF&\\3c&H000000&\\fs18\\fn' .. M.user_opts.font .. '}',
    Title = '{\\blur1\\bord0.5\\1c&HFFFFFF&\\3c&H0\\fs38\\q2\\fn' .. M.user_opts.font .. '}',
    WinCtrl = '{\\blur1\\bord0.5\\1c&HFFFFFF&\\3c&H0\\fs20\\fnmpv-osd-symbols}',
    elementDown = '{\\1c&H999999&}',
    elementHighlight = '{\\blur1\\bord1\\1c&HFFC033&}',
}

-- tick rate-limit delay (seconds)
M.tick_delay = 0.03

-- window control box width in ASS units
M.window_control_box_width = 138

-- December santa hat toggle
M.is_december = os.date('*t').month == 12

return M
