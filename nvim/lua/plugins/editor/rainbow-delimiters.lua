return {
  "HiPhish/rainbow-delimiters.nvim",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = { "nvim-treesitter/nvim-treesitter" },

  config = function()
    ---@type rainbow_delimiters.config
    vim.g.rainbow_delimiters = {
      -- ------------------------------------------------------------------
      -- Strategy (how highlighting is applied)
      -- ------------------------------------------------------------------
      strategy = {
        [""] = "rainbow-delimiters.strategy.global", -- default (whole buffer)
        -- Local strategy is lighter and updates on cursor move
        vim = "rainbow-delimiters.strategy.local",
        -- Optional: use local for HTML-like files if you prefer
        -- html = "rainbow-delimiters.strategy.local",
        -- tsx  = "rainbow-delimiters.strategy.local",
      },

      -- ------------------------------------------------------------------
      -- Queries (what gets highlighted)
      -- ------------------------------------------------------------------
      query = {
        [""] = "rainbow-delimiters",               -- default for most languages

        -- Lua: highlight whole blocks (function / if / end etc.)
        lua = "rainbow-blocks",

        -- JavaScript / React: JSX-aware (default for JS is already react-aware)
        javascript = "rainbow-delimiters-react",

        -- TypeScript / TSX
        typescript = "rainbow-delimiters",         -- or "rainbow-parens" if you want only brackets
        tsx = "rainbow-delimiters",               -- good default (inherits TS + JSX tags)

        -- HTML / Blazor-related
        html = "rainbow-delimiters",              -- tags + brackets
        -- If you prefer only tags: html = "rainbow-tags",
      },

      -- ------------------------------------------------------------------
      -- Highlight priority
      -- ------------------------------------------------------------------
      priority = {
        [""] = 110,
        lua = 210, -- higher so blocks stand out more in Lua
      },

      -- ------------------------------------------------------------------
      -- Colors (order is intentional for contrast)
      -- ------------------------------------------------------------------
      highlight = {
        "RainbowDelimiterRed",
        "RainbowDelimiterYellow",
        "RainbowDelimiterBlue",
        "RainbowDelimiterOrange",
        "RainbowDelimiterGreen",
        "RainbowDelimiterViolet",
        "RainbowDelimiterCyan",
      },

      -- ------------------------------------------------------------------
      -- Optional filters
      -- ------------------------------------------------------------------
      -- blacklist = { "json", "markdown" }, -- disable for noisy filetypes
      -- whitelist = { "lua", "rust", "typescript", "tsx", "javascript", "c_sharp", "html" },

      -- Disable on very large files (recommended)
      condition = function(bufnr)
        local max_lines = 10000
        return vim.api.nvim_buf_line_count(bufnr) <= max_lines
      end,
    }
  end,
}
