local constants = require("constants")

return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = { "mason-org/mason.nvim" },
  -- Per-language settings live in servers/*.lua as opts.servers and are
  -- merged here by lazy. nvim 0.12 world: configure servers via
  -- vim.lsp.config(), enable via vim.lsp.enable().
  ---@module "lspconfig"
  ---@type lspconfig.Config
  opts = {
    servers = {},
  },
  config = function(_, opts)
    vim.diagnostic.config({
      virtual_text = { prefix = "● ", spacing = 1 },
      signs = true,
      underline = true,
      update_in_insert = false,
      float = { border = constants.BORDER, source = true },
      severity_sort = true,
    })

    -- blink.cmp capabilities for every server
    vim.lsp.config("*", {
      capabilities = require("blink.cmp").get_lsp_capabilities(),
    })

    -- Per-language settings merged by lazy from servers/*.lua.
    for name, server in pairs(opts.servers) do
      vim.lsp.config(name, server)
    end

    -- mason installs the binaries; constants.LSP_TOOLCHAIN pairs each enabled
    -- server with its package. roslyn (c# / razor / blazor) is enabled by
    -- roslyn.nvim instead.
    vim.lsp.enable(vim.tbl_map(function(lsp)
      return lsp.server
    end, constants.LSP_TOOLCHAIN))
  end,
}
