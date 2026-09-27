---@mod "constants" Shared constant values for this Neovim config.

---@class ms.constants

local M = {}

---Directories that are almost never the desired search targets. These are
---pruned by default when walking the tree; pass `skip = false` to disable.
---Also used by neo-tree's `hide_by_name` and fzf-lua's fd/rg excludes.
---@type string[]
M.DEFAULT_SKIP = {
  "bin",
  "obj",
  "node_modules",
  "dist",
  "build",
  "out",
  "target",
  "aidlc",
  ".git",
  ".vs",
  ".idea",
  ".vscode",
  ".svn",
  ".hg",
}

---Border style shared by every floating window (options.winborder, mason,
---blink, noice, fzf-lua, toggleterm, which-key, neo-tree, gitsigns, lazy).
---@type string
M.BORDER = "rounded"

---Catppuccin flavour; `COLORSCHEME` is the full colorscheme name derived from
---it (used by the catppuccin plugin and lazy.nvim's bootstrap colorscheme).
---@type string
M.FLAVOUR = "macchiato"
M.COLORSCHEME = "catppuccin-" .. M.FLAVOUR

---Diagnostic severity icons, shared by statusline and tree UIs.
---@type table<string, string>
M.DIAGNOSTIC_ICONS = {
  error = "󰅚",
  warn = "󰀪",
  info = "󰋽",
  hint = "󰌶",
}

---Fileformat icons, shared by the statusline and the fileformat picker.
---@type table<string, string>
M.FILEFORMAT_ICONS = {
  unix = "",
  dos = "",
  mac = "",
}

---The LSP toolchain: one entry per language server. `server` is the config
---name for `vim.lsp.enable()` (nvim-lspconfig); `mason` is the mason package
---that provides it, or nil when it isn't installed via mason:
---   - rust_analyzer ships with the rustup toolchain (rustfmt too, so
---     conform calls it directly)
---   - ruff ships both the linter LSP and the formatter in one package
---   - roslyn (c# / razor / blazor) is installed via mason but enabled by
---     roslyn.nvim, which owns its target/root_dir logic — enabling it here
---     would race that and spawn a second server
---@class ms.constants.lsp
---@field server string
---@field mason? string
---@type ms.constants.lsp[]
M.LSP_TOOLCHAIN = {
  -- lua
  { server = "lua_ls", mason = "lua-language-server" },
  -- ts / js / react (tsc 7 native LSP)
  { server = "tsc", mason = "tsc" },
  { server = "eslint", mason = "eslint-lsp" },
  { server = "emmet_language_server", mason = "emmet-language-server" },
  -- python
  { server = "pyright", mason = "pyright" },
  { server = "ruff", mason = "ruff" },
  -- rust
  { server = "rust_analyzer" },
  -- c / c++
  { server = "clangd", mason = "clangd" },
  -- markup
  { server = "jsonls", mason = "json-lsp" },
  { server = "html", mason = "html-lsp" },
  { server = "cssls", mason = "css-lsp" },
  { server = "lemminx", mason = "lemminx" }, -- xml
  { server = "marksman", mason = "marksman" }, -- markdown
}

---Mason packages that are not LSP servers: formatters and the roslyn
---language server (enabled by roslyn.nvim, see LSP_TOOLCHAIN above).
---@type string[]
M.MASON_TOOLS = {
  "prettierd",
  "stylua",
  "shfmt",
  "clang-format", -- conform's `c` / `cpp` entries
  "sqlfluff", -- conform's `sql` entry (lint + format, dialect via .sqlfluff)
  "csharpier", -- conform's `cs` entry
  "roslyn", -- Crashdummyy registry build (vscode version, co-hosts razor)
}

---Ripgrep exclusion globs for DEFAULT_SKIP. Shared by fzf-lua's rg options
---and blink-ripgrep's additional_rg_options.
---@return string[]
function M.rg_exclude_globs()
  local globs = {}
  for _, dir in ipairs(M.DEFAULT_SKIP) do
    globs[#globs + 1] = ("!**/%s/**"):format(dir)
  end
  return globs
end

return M
