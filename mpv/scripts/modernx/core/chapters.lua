-- modernx/core/chapters.lua
-- Chapter lookup by time.

local state = require './state'

local M = {}

-- returns nil or a chapter record from state.chapter_list
-- (sorted, get latest before possec, if any)
function M.get_chapter(possec)
    local cl = state.chapter_list
    for n = #cl, 1, -1 do
        if possec >= cl[n].time then
            return cl[n]
        end
    end
end

return M
