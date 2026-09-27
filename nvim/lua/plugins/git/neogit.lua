return {
  "NeogitOrg/neogit",
  cmd = "Neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  keys = {
    { "<leader>gg", "<cmd>Neogit<CR>", desc = "Neogit status" },
    { "<leader>gG", "<cmd>Neogit<CR>", desc = "Neogit status" }, -- dedupe
  },
  opts = {
    disable_signs = false,
    disable_context_highlighting = false,
    disable_commit_confirmation = false,
    auto_refresh = true,
    graph_style = "unicode", -- options: bar, unicode, ascii, ascii_ascii
  },
}