-- modernx/ui/thumbfast.lua
-- External thumbfast thumbnailer state + handler.

local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'

local M = {}

-- thumbfast state
M.thumbfast = {
    width = 0,
    height = 0,
    disabled = true,
    available = false,
}

-- handler for the 'thumbfast-info' script message
function M.handle(json)
    local data = utils.parse_json(json)
    if type(data) ~= 'table' or not data.width or not data.height then
        msg.error("thumbfast-info: received json didn't produce a table with thumbnail information")
    else
        M.thumbfast = data
    end
end

return M
