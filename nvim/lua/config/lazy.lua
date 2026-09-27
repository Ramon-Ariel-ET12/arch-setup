local constants = require("constants")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch",
    "main",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  -- Pin lazy.nvim to the locked commit for reproducibility
  vim.fn.system({ "git", "-C", lazypath, "checkout", "306a05526ada86a7b30af95c5cc81ffba93fef97" })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- lazy recurses into subfolders only via init.lua, so import each group
    { import = "plugins.ui" },
    { import = "plugins.lsp" },
    { import = "plugins.lsp.servers" },
    { import = "plugins.editor" },
    { import = "plugins.git" },
    { import = "plugins.misc" },
  },

  defaults = {
    lazy = true,
    version = false,
  },

  -- No plugin in this config requires luarocks; disables hererocks/python checks
  rocks = {
    enabled = false,
  },

  install = {
    -- Placeholder colorscheme used by the lazy UI before plugins load
    colorscheme = { constants.COLORSCHEME },
  },

  checker = {
    enabled = true,
    notify = false,
  },

  change_detection = {
    notify = false,
  },

  performance = {
    cache = {
      enabled = true,
    },
    rtp = {
      disabled_plugins = {
        "2html_plugin",
        "tohtml",
        "gzip",
        "tarPlugin",
        "zipPlugin",
        "netrwPlugin",
        "matchit",
        "matchparen",
        "rrhelper",
        "spellfile_plugin",
        "tutor",
        "vimball",
        "logiPat",
        "ftplugin",
      },
    },
  },

  ui = {
    border = constants.BORDER,
    title = " Lazy.nvim ",
  },

  keys = {
    { "<leader>pp", "<cmd>Lazy<CR>", desc = "Lazy (plugins)" },
    { "<leader>pg", "<cmd>Lazy log<CR>", desc = "Lazy log" },
    { "<leader>pc", "<cmd>Lazy check<CR>", desc = "Lazy check updates" },
    { "<leader>ps", "<cmd>Lazy sync<CR>", desc = "Lazy sync" },
    { "<leader>pu", "<cmd>Lazy update<CR>", desc = "Lazy update" },
    { "<leader>pi", "<cmd>Lazy install<CR>", desc = "Lazy install" },
  },
})