return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },          -- recommended lazy-loading
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = { "n", "v" },
      desc = "Format buffer / range",
    },
    {
      "<leader>cF",
      function()
        require("conform").format({ formatters = { "injected" }, async = true })
      end,
      mode = { "n", "v" },
      desc = "Format injected languages",
    },
  },

  ---@module "conform"
  ---@type conform.setupOpts
  opts = {
    -- ------------------------------------------------------------------
    -- Formatters by filetype
    -- ------------------------------------------------------------------
    formatters_by_ft = {
      -- Lua
      lua = { "stylua" },

      -- JavaScript / TypeScript / React
      javascript = { "prettierd", "prettier", stop_after_first = true },
      javascriptreact = { "prettierd", "prettier", stop_after_first = true },
      typescript = { "prettierd", "prettier", stop_after_first = true },
      typescriptreact = { "prettierd", "prettier", stop_after_first = true },

      -- Web
      json = { "prettierd", "prettier", stop_after_first = true },
      jsonc = { "prettierd", "prettier", stop_after_first = true },
      yaml = { "prettierd", "prettier", stop_after_first = true },
      html = { "prettierd", "prettier", stop_after_first = true },
      css = { "prettierd", "prettier", stop_after_first = true },
      scss = { "prettierd", "prettier", stop_after_first = true },
      markdown = { "prettierd", "prettier", stop_after_first = true },

      -- Shell
      sh = { "shfmt" },
      bash = { "shfmt" },
      zsh = { "shfmt" },

      -- Rust
      rust = { "rustfmt", lsp_format = "fallback" },

      -- C# / .NET (prefer csharpier if available, otherwise LSP)
      cs = { "csharpier", lsp_format = "fallback" },

      -- Python (uv-managed; ruff ships the formatter in the same package)
      python = { "ruff_format" },

      -- C / C++
      c = { "clang_format" },
      cpp = { "clang_format" },

      -- SQL (dialect from .sqlfluff in the project root)
      sql = { "sqlfluff" },
    },

    -- ------------------------------------------------------------------
    -- Default options for every format call
    -- ------------------------------------------------------------------
    default_format_opts = {
      lsp_format = "fallback",   -- use LSP only when no external formatter is available
      timeout_ms = 1000,
      async = true,              -- non-blocking by default for manual calls
    },

    -- ------------------------------------------------------------------
    -- Format on save
    -- ------------------------------------------------------------------
    format_on_save = {
      timeout_ms = 1500,
      lsp_format = "fallback",
    },

    -- ------------------------------------------------------------------
    -- Custom formatter tweaks
    -- ------------------------------------------------------------------
    formatters = {
      shfmt = {
        append_args = { "-i", "2", "-ci" }, -- 2-space indent + case indent
      },
      -- Optional: make prettierd prefer project config
      -- prettierd = {
      --   require_cwd = true,
      -- },
      -- Optional: csharpier
      -- csharpier = {
      --   command = "csharpier",
      --   args = { "format", "--write-stdout" },
      -- },
    },

    -- ------------------------------------------------------------------
    -- Notifications
    -- ------------------------------------------------------------------
    notify_on_error = true,
    notify_no_formatters = true,
  },

  init = function()
    -- Make `gq` use conform
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,
}
