return {
  "esmuellert/codediff.nvim",
  cmd = "CodeDiff",
  keys = {
    { "<leader>gd", "<cmd>CodeDiff<CR>", desc = "Open diff" },
    { "<leader>gh", "<cmd>CodeDiff history<CR>", desc = "File history" },
    { "<leader>gH", "<cmd>CodeDiff history %<CR>", desc = "Current file history" },
  },
  opts = {},
}