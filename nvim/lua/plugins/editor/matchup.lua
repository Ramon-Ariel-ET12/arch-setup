return {
  "andymass/vim-matchup",
  -- Author recommendation: do NOT lazy-load with event = ...
  lazy = false,

  ---@type matchup.Config
  opts = {
    -- ------------------------------------------------------------------
    -- Treesitter integration (Neovim – preferred engine)
    -- ------------------------------------------------------------------
    treesitter = {
      enabled = true,                 -- default on modern Neovim
      stopline = 500,                 -- stop searching after N lines (perf)
      include_match_words = true,     -- also use classic match_words + treesitter
      enable_quotes = true,           -- match quotes (useful in TS/JS/Lua/Rust/C#)
      -- disable = { "some_lang" },  -- only if needed
    },

    -- ------------------------------------------------------------------
    -- Match highlighting (the main feature)
    -- ------------------------------------------------------------------
    matchparen = {
      enabled = true,
      deferred = true,                -- smoother (recommended)
      deferred_show_delay = 50,
      deferred_hide_delay = 700,
      timeout = 300,
      timeout_insert = 60,
      insert_timeout = 60,
      hi_surround_always = true,      -- always highlight surrounding matches
      -- singleton = false,           -- don't highlight unmatched delimiters
      offscreen = {
        method = "popup",             -- "popup" | "status" | "status_manual"
        -- fullwidth = false,
        -- highlight = "MatchParenOffscreen",
      },
    },

    -- ------------------------------------------------------------------
    -- Motions & text objects
    -- ------------------------------------------------------------------
    motion = {
      enabled = true,
      override_Npercent = 6,          -- allow 1%..6% as match-up motions
      cursor_end = true,
    },

    text_obj = {
      enabled = true,
      linewise_operators = { "d", "y" }, -- operators that work line-wise with i%/a%
    },

    -- ------------------------------------------------------------------
    -- Surround (ds%, cs%, etc.)
    -- ------------------------------------------------------------------
    surround = {
      enabled = true,                 -- recommended
    },

    -- ------------------------------------------------------------------
    -- Misc quality-of-life / performance
    -- ------------------------------------------------------------------
    enabled = true,
    mappings_enabled = true,
    mouse_enabled = false,            -- set true if you want mouse support
    delim_stopline = 1500,            -- max lines to search for a match
    delim_noskips = 2,                -- 0 = disabled, 1 = symbols only, 2 = all
  },

  config = function(_, opts)
    require("match-up").setup(opts)

    -- Slightly stronger / more visible highlights (works well with most colorschemes)
    vim.api.nvim_set_hl(0, "MatchParen", {
      bold = true,
      underline = true,
      -- fg / bg left to colorscheme (or set explicitly if desired)
    })
    vim.api.nvim_set_hl(0, "MatchWord", {
      underline = true,
    })
    -- Optional: make the off-screen popup stand out a bit more
    -- vim.api.nvim_set_hl(0, "MatchParenOffscreen", { link = "MatchParen" })
  end,
}
