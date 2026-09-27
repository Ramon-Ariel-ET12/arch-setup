-- modernx/types/mp.lua
-- LuaLS annotations for the mpv scripting API surface used by modernx.
-- Loaded by the Lua language server only; not used at runtime.

---@meta mp

mp = {}

---@class mp.ass
local ass = {}

function ass:append(s) end
function ass:merge(other) end
function ass:pos(x, y) end
function ass:an(n) end
function ass:new_event() end
function ass:draw_start() end
function ass:draw_stop() end
function ass:rect_cw(x0, y0, x1, y1) end
function ass:rect_ccw(x0, y0, x1, y1) end
function ass:round_rect_cw(x0, y0, x1, y1, r1, r2) end
function ass:round_rect_ccw(x0, y0, x1, y1, r1, r2) end
function ass:hexagon_cw(x0, y0, x1, y1, r1, r2) end
function ass:hexagon_ccw(x0, y0, x1, y1, r1, r2) end
function ass:move_to(x, y) end
function ass:line_to(x, y) end

---@class mp.assdraw_factory
local assdraw = {}

---@return mp.ass
function assdraw.ass_new() end

mp.assdraw = assdraw

mp.ass = ass

---@class mp.timer
local timer = {}
function timer:kill() end
function timer:resume() end
function timer:is_enabled() end

---@class mp.msg_module
local msg_mod = {}
function msg_mod.debug(...) end
function msg_mod.trace(...) end
function msg_mod.info(...) end
function msg_mod.warn(...) end
function msg_mod.error(...) end
function msg_mod.verbose(...) end
function msg_mod.log(...) end
mp.msg = msg_mod

---@class mp.options_module
local opt_mod = {}
---@param opts table user option default table (mutated)
---@param config_prefix string prefix in mpv.conf
---@param on_change fun(list: table) called when options reload
function opt_mod.read_options(opts, config_prefix, on_change) end
mp.options = opt_mod

---@class mp.utils_module
local utils_mod = {}
---@param path string
---@return string dirname, string filename
function utils_mod.split_path(path) end
---@param json string
---@return table|nil
function utils_mod.parse_json(json) end
mp.utils = utils_mod

---@class mp.osd_overlay
local osd_overlay = {}
function osd_overlay:update() end
function osd_overlay:remove() end
mp.create_osd_overlay = function(format) return osd_overlay end

function mp.get_time() return 0.0 end
function mp.get_osd_size() return 0, 0, 0.0 end
function mp.get_mouse_pos() return 0, 0 end
function mp.set_mouse_area(x0, y0, x1, y1, name) end
function mp.get_property(name) return nil end
function mp.get_property_bool(name) return false end
function mp.get_property_number(name, default) return 0 end
function mp.get_property_native(name, default) return nil end
function mp.get_property_osd(name) return '' end
function mp.set_property(name, value) end
function mp.set_property_native(name, value) end
function mp.command(cmd) end
function mp.commandv(...) end
function mp.command_native(cmd) end
function mp.osd_message(text) end
function mp.format_time(seconds) return '' end
function mp.add_timeout(timeout, fn) return timer end
function mp.register_event(name, fn) end
function mp.observe_property(name, fmt, fn) end
function mp.unobserve_property(fn) end
function mp.register_script_message(name, fn) end
function mp.set_key_bindings(bindings, context, flags) end
function mp.add_key_binding(key, name, fn, flags) end
function mp.add_forced_key_binding(key, name, fn, flags) end
function mp.remove_key_binding(name) end
function mp.enable_key_bindings(context, flags) end
function mp.disable_key_bindings(context) end
