-- modernx/image/metadata.lua
-- Real file/image metadata for the Info panel. Pulls only from mpv
-- properties and mp.utils.file_info; never fabricates values.
-- Missing data is returned as nil so the UI can render a clean fallback.

local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'

local M = {}

-- short human size, e.g. 1.2 MiB. Nil-safe.
function M.format_size(bytes)
    if type(bytes) ~= 'number' then return nil end
    local units = { 'B', 'KiB', 'MiB', 'GiB', 'TiB' }
    local v, u = bytes * 1.0, 1
    while v >= 1024 and u < #units do v, u = v / 1024, u + 1 end
    if u == 1 then return string.format('%d %s', bytes, units[u]) end
    return string.format('%.1f %s', v, units[u])
end

-- aspect as a reduced "W:H" label plus decimal, e.g. "16:9 (1.78)".
function M.format_aspect(w, h)
    if type(w) ~= 'number' or type(h) ~= 'number' or w <= 0 or h <= 0 then
        return nil
    end
    local function gcd(a, b)
        while b ~= 0 do a, b = b, a % b end
        return a
    end
    local d = gcd(w, h)
    return string.format('%d:%d (%.2f)', w / d, h / d, w / h)
end

local MIME_BY_EXT = {
    jpg = 'image/jpeg', jpeg = 'image/jpeg', png = 'image/png',
    gif = 'image/gif', webp = 'image/webp', avif = 'image/avif',
    jxl = 'image/jxl', bmp = 'image/bmp', svg = 'image/svg+xml',
    tif = 'image/tiff', tiff = 'image/tiff', heic = 'image/heic',
    heif = 'image/heif', j2k = 'image/jp2', jp2 = 'image/jp2',
    qoi = 'image/qoi', tga = 'image/x-tga',
}

function M.mime_for(filename)
    if type(filename) ~= 'string' then return nil end
    local ext = filename:match('%.([^%.%/\\]+)$')
    if not ext then return nil end
    return MIME_BY_EXT[ext:lower()]
end

-- gather metadata for the current file. All fields optional except
-- filename/path; callers must tolerate nils.
function M.collect()
    local path = mp.get_property('path', nil)
    local data = { filename = mp.get_property('filename', nil), path = path }
    if path == nil then return data end

    data.ext = path:match('%.([^%.%/\\]+)$')
    if data.ext then data.ext = data.ext:lower() end
    data.mime = M.mime_for(data.filename or path)

    local ok, info = pcall(utils.file_info, path)
    if ok and type(info) == 'table' then
        data.size = info.size
        data.mtime = info.mtime
        if type(info.mtime) == 'number' then
            data.mtime_text = os.date('%Y-%m-%d %H:%M', info.mtime)
        end
    else
        msg.verbose('image metadata: file_info failed for ' .. tostring(path))
    end

    local vp_ok, vp = pcall(mp.get_property_native, 'video-params', nil)
    if vp_ok and type(vp) == 'table' then
        data.width = vp.w
        data.height = vp.h
        data.aspect = M.format_aspect(vp.w, vp.h)
        if vp.pixelformat then data.depth = tostring(vp.pixelformat) end
        if vp.colormatrix and vp.colormatrix ~= '' then
            data.colorspace = tostring(vp.colormatrix)
        end
    end

    return data
end

return M
