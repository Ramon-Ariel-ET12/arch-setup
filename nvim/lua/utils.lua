---@mod "utils" Reusable helpers for this Neovim config.

---@class ms.utils

local constants = require("constants")

local M = {}

---@class ms.utils.search.Opts
---@field path? string Start directory. Defaults to the directory Neovim was
---   opened in (`vim.uv.cwd()`).
---@field quantity? number How many results to collect. Defaults to **1**
---   (return the first match only). Use `math.huge` for unlimited results,
---   or any positive integer for a capped batch.
---@field exts? string[] Return files whose extension is in this list. Dot is
---   optional: `"sln"` and `".sln"` are both accepted.
---@field names? string[] Return entries whose basename is in this list (exact
---   match, e.g. `"secrets.json"`).
---@field parts? string[] Return entries whose basename contains any of these
---   substrings (case-insensitive).
---@field type? "file"|"directory" Restrict matches to one kind. Defaults to
---   files only.
---@field skip? boolean|string[]|fun(path:string):boolean Control pruning:
---   `false` disables skipping; a list of directory names adds to the default
---   set; a function receives the full path and returns true to prune.
---@field skip_default? boolean When `skip` is a list of names, keep the
---   default skip set (default true). Set false to use only your list.

---Compile the per-entry prune predicate.
---@param opts ms.utils.search.Opts
---@return fun(path: string): boolean|nil
local function make_skip(opts)
  if opts.skip == false then
    return nil
  end

  if type(opts.skip) == "function" then
    return opts.skip
  end

  local user = {}
  if type(opts.skip) == "table" then
    for _, n in ipairs(opts.skip) do
      user[n:lower()] = true
    end
  end

  local use_default = not (type(opts.skip) == "table" and opts.skip_default == false)

  return function(path)
    local base = vim.fs.basename(path):lower()
    if user[base] then
      return true
    end
    if use_default then
      for _, d in ipairs(constants.DEFAULT_SKIP) do
        if d == base then
          return true
        end
      end
    end
    return false
  end
end

---Does a file name match the `exts`/`names`/`parts` filters?
---@param name string basename of the candidate
---@param opts ms.utils.search.Opts
---@return boolean
local function matches(name, opts)
  local base = vim.fs.basename(name)

  if opts.exts then
    local ext = vim.fs.ext(base):lower()
    local ok = false
    for _, e in ipairs(opts.exts) do
      local normalized = e:gsub("^%.", ""):lower()
      if normalized == ext then
        ok = true
        break
      end
    end
    if not ok then
      return false
    end
  end

  if opts.names then
    if not vim.tbl_contains(opts.names, base, true) then
      return false
    end
  end

  if opts.parts then
    local lowered = base:lower()
    local ok = false
    for _, p in ipairs(opts.parts) do
      if lowered:find(p:lower(), 1, true) then
        ok = true
        break
      end
    end
    if not ok then
      return false
    end
  end

  return true
end

---Recursively walk `dir` collecting matches, stopping early once `quota`
---results are gathered. Returns true when the quota has been reached.
---
---Traversal is breadth-first at each level: every entry (file or directory)
---directly inside `dir` is examined before descending into any subdirectory,
---so shallower matches are always preferred over deeper ones.
---@param dir string
---@param opts ms.utils.search.Opts
---@param ret string[]
---@param quota number
---@return boolean
local function walk(dir, opts, ret, quota)
  -- Synchronous, deterministic listing via libuv. This also makes the
  -- `skip` behaviour fully under our control.
  local handle = vim.uv.fs_scandir(dir)
  if not handle then
    return false
  end

  -- Collect subdirectories instead of descending into them immediately.
  -- Every entry at this level is examined first — a clean pass — before
  -- we recurse into any child directory (each child gets the same treatment).
  local subdirs = {}

  while true do
    local name, raw_type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end

    local full = vim.fs.joinpath(dir, name)

    if raw_type == "directory" then
      if opts.type == "directory" and matches(name, opts) then
        ret[#ret + 1] = vim.fs.normalize(full)
        if #ret >= quota then
          return true
        end
      end
      if not (opts._skip and opts._skip(full)) then
        subdirs[#subdirs + 1] = full
      end
    else
      -- files, symlinks, etc.
      if opts.type ~= "directory" and matches(name, opts) then
        ret[#ret + 1] = vim.fs.normalize(full)
        if #ret >= quota then
          return true
        end
      end
    end
  end

  -- Only after every entry at this level has been examined do we descend
  -- into the subdirectories — one at a time, applying the same logic.
  for _, subdir in ipairs(subdirs) do
    if walk(subdir, opts, ret, quota) then
      return true
    end
  end

  return false
end

---Search the filesystem, starting from `opts.path` (default: the directory
---Neovim was launched from). Returns absolute, normalized paths.
---
---```lua
---local u = require("utils")
---u.search({ exts = { "sln", "slnx" } })                        -- first solution
---u.search({ exts = { "csproj" }, quantity = math.huge })       -- every project
---u.search({ names = { "package.json" }, skip = false })       -- exact match, no pruning
---```
---@param opts? ms.utils.search.Opts
---@return string[]
function M.search(opts)
  opts = opts or {}
  local root = vim.fs.normalize(opts.path or vim.uv.cwd())
  local quantity = opts.quantity
  if quantity == nil or quantity <= 0 then
    quantity = 1
  end

  opts._skip = make_skip(opts)
  local ret = {}
  walk(root, opts, ret, quantity)
  opts._skip = nil -- don't leak the predicate onto the caller's table

  return ret
end

---Convenience: every match.
---@param opts? ms.utils.search.Opts
---@return string[]
function M.find_all(opts)
  opts = opts or {}
  opts.quantity = math.huge
  return M.search(opts)
end

---Convenience: the first match (same as the default `quantity = 1`).
---@param opts? ms.utils.search.Opts
---@return string?
function M.find_first(opts)
  return M.search(opts)[1]
end
return M
