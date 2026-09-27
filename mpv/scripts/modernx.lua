-- modernx.lua
-- mpv script entry point: `scripts/` only loads top-level *.lua files,
-- so this stub puts its own directory on the search path and forwards
-- to the real application in modernx/main.lua. Feature modules under
-- modernx/ keep their existing `require './...'` style, which mpv's
-- loader resolves relative to the requiring file.

local script_dir = debug.getinfo(1, 'S').source:match('^@(.*/)') or './'
package.path = script_dir .. 'modernx/?.lua;'
    .. script_dir .. 'modernx/?/init.lua;'
    .. script_dir .. '?.lua;'
    .. package.path

require('modernx.main')
