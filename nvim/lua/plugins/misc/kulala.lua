return {
  "mistweaverco/kulala.nvim",
  ft = { "http", "rest" },
  keys = {
    { "<leader>Rs", "<cmd>lua require('kulala').send()<CR>", ft = { "http", "rest" }, desc = "Send request" },
    { "<leader>Rf", "<cmd>lua require('kulala').send_file()<CR>", ft = { "http", "rest" }, desc = "Send file" },
    { "<leader>Ra", "<cmd>lua require('kulala').send_all()<CR>", ft = { "http", "rest" }, desc = "Send all requests" },
    { "<leader>Rr", "<cmd>lua require('kulala').replay()<CR>", ft = { "http", "rest" }, desc = "Replay last" },
  },
  opts = {
    winbar = { enabled = true },
  },
  config = function(_, opts)
    require("kulala").setup(opts)
  end,
}