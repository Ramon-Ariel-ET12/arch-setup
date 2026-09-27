-- modernx/core/media.lua
-- Media classification: is the current mpv file an image, a video, or unknown?
-- UI-free: answers questions, never renders.

local mp = require 'mp'
local msg = require 'mp.msg'

local M = {}

M.TYPE_IMAGE = 'image'
M.TYPE_VIDEO = 'video'
M.TYPE_UNKNOWN = 'unknown'

-- extension fallback when mpv exposes no usable media signal.
-- Kept in sync with `mpv --list-options | grep image-exts` defaults.
local IMAGE_EXTS = {
    avif = true, bmp = true, gif = true, heic = true, heif = true,
    j2k = true, jp2 = true, jpeg = true, jpg = true, jxl = true,
    png = true, qoi = true, svg = true, tga = true, tif = true,
    tiff = true, webp = true,
}

-- is the current track-list a single video track mpv flagged as image?
local function tracklist_is_image()
    local tracks = mp.get_property_native('track-list', nil)
    if type(tracks) ~= 'table' or #tracks == 0 then
        return nil -- no signal (idle / audio-only / unknown)
    end
    local video_count, image_count = 0, 0
    for _, t in ipairs(tracks) do
        if t.type == 'video' then
            video_count = video_count + 1
            if t.image then image_count = image_count + 1 end
        end
    end
    if video_count == 0 then return nil end
    return video_count == 1 and image_count == 1
end

-- extension lookup on the current path; only used when track-list
-- says nothing (e.g. before tracks resolve).
local function ext_is_image(path)
    if type(path) ~= 'string' then return nil end
    local ext = path:match('%.([^%.%/\\%?]+)$')
    if not ext then return nil end
    return IMAGE_EXTS[ext:lower()] == true
end

-- classify the current file. Returns 'image' | 'video' | 'unknown'.
function M.current_type()
    local from_tracks = tracklist_is_image()
    if from_tracks == true then return M.TYPE_IMAGE end

    local path = mp.get_property('path', nil)
    if path == nil then return M.TYPE_UNKNOWN end
    if from_tracks == nil and ext_is_image(path) then return M.TYPE_IMAGE end

    -- mpv reports images as the jpeg_pipe family; treat anything else
    -- with a real track-list as video.
    if from_tracks == false then return M.TYPE_VIDEO end

    -- from_tracks == false here only when tracks exist and are not an
    -- image: fall through to video; unreachable, kept for clarity.
    return M.TYPE_VIDEO
end

function M.is_image()
    return M.current_type() == M.TYPE_IMAGE
end

function M.is_video()
    return M.current_type() == M.TYPE_VIDEO
end

-- image playlist built by mpv itself (autocreate-playlist=same):
-- all sibling images in load order. Empty table when unavailable.
function M.playlist_entries()
    local pl = mp.get_property_native('playlist', nil)
    if type(pl) ~= 'table' then
        msg.verbose('media: playlist property unavailable')
        return {}
    end
    return pl
end

-- 1-based index of the current entry, or nil.
function M.playlist_index(entries)
    entries = entries or M.playlist_entries()
    local pos = mp.get_property_number('playlist-pos', nil)
    if pos == nil or #entries == 0 then return nil end
    return pos + 1
end

-- best-known filesystem path of the current file, or nil.
function M.current_path()
    return mp.get_property('path', nil)
end

return M
