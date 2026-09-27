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
    font = 'JetBrainsMono Nerd Font Mono',       -- default osc font
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

-- icons (utf-8 byte escapes for Nerd Fonts codepoints).
-- NB: these must stay inside JetBrainsMono Nerd Font Mono coverage
-- (verify: fc-list "JetBrainsMono Nerd Font Mono:charset=<CP>" family).
-- The old ZMDI codepoints (U+F39x..U+F3Dx) were dropped in Nerd Fonts v3,
-- so transport icons use Font Awesome: step-backward/forward (F048/F051),
-- play/pause (F04B/F04C), rotate-left/right (F0E2/F01E), etc.
M.icons = {
    previous = '\239\129\136',
    next = '\239\129\145',
    play = '\239\129\139',
    pause = '\239\129\140',
    backward = '\239\129\138',
    forward = '\239\129\142',
    audio = '\239\128\129',
    volume = '\239\128\168',
    volume_mute = '\239\128\166',
    sub = '\239\136\138',
    minimize = '\239\139\144',
    fullscreen = '\239\139\146',
    -- image mode (Nerd Font; see note above)
    info = '\239\132\169',       -- nf-fa-info_circle
    picture = '\239\128\190',    -- nf-fa-picture_o
    close = '\239\128\141',      -- nf-fa-close
    folder = '\239\129\187',     -- nf-fa-folder_open
    file = '\239\128\150',       -- nf-fa-file (unknown playlist type)
}

-- icons for jump button depending on jumpamount
M.jumpicons = {
    [5] = { '\239\131\162', '\239\128\158' },
    [10] = { '\239\131\162', '\239\128\158' },
    [30] = { '\239\131\162', '\239\128\158' },
    default = { '\239\131\162\t', '\239\128\158' },
}

-- ASS style fragments (built with the user-configured font name)
-- NB: control styles must use the same Nerd Font as `font` above,
-- otherwise the nf-* icons render as tofu.
M.osc_styles = {
    TransBg = '{\\blur100\\bord150\\1c&H000000&\\3c&H000000&}',
    SeekbarBg = '{\\blur0\\bord0\\1c&HFFFFFF&}',
    SeekbarFg = '{\\blur1\\bord1\\1c&HE39C42&}',
    VolumebarBg = '{\\blur0\\bord0\\1c&H999999&}',
    VolumebarFg = '{\\blur1\\bord1\\1c&HFFFFFF&}',
    Ctrl1 = '{\\blur0\\bord0\\1c&HFFFFFF&\\3c&HFFFFFF&\\fs36\\fnJetBrainsMono Nerd Font Mono}',
    Ctrl2 = '{\\blur0\\bord0\\1c&HFFFFFF&\\3c&HFFFFFF&\\fs24\\fnJetBrainsMono Nerd Font Mono}',
    Ctrl2Flip = '{\\blur0\\bord0\\1c&HFFFFFF&\\3c&HFFFFFF&\\fs24\\fnJetBrainsMono Nerd Font Mono\\fry180',
    Ctrl3 = '{\\blur0\\bord0\\1c&HFFFFFF&\\3c&HFFFFFF&\\fs24\\fnJetBrainsMono Nerd Font Mono}',
    Time = '{\\blur0\\bord0\\1c&HFFFFFF&\\3c&H000000&\\fs17\\fn' .. M.user_opts.font .. '}',
    Tooltip = '{\\blur1\\bord0.5\\1c&HFFFFFF&\\3c&H000000&\\fs18\\fn' .. M.user_opts.font .. '}',
    Title = '{\\blur1\\bord0.5\\1c&HFFFFFF&\\3c&H0\\fs38\\q2\\fn' .. M.user_opts.font .. '}',
    WinCtrl = '{\\blur1\\bord0.5\\1c&HFFFFFF&\\3c&H0\\fs20\\fn' .. M.user_opts.font .. '}',
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
