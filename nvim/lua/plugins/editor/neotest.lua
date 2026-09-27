return {
  "nvim-neotest/neotest",
  event = "VeryLazy",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-neotest/nvim-nio",
    "nvim-treesitter/nvim-treesitter",
    "nsidorenco/neotest-vstest", -- dotnet (vstest) adapter
  },
  keys = {
    { "<leader>Tr", function() require("neotest").run.run() end, desc = "Run nearest" },
    { "<leader>Tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file" },
    { "<leader>To", function() require("neotest").output.open() end, desc = "Output" },
    { "<leader>Tx", function() require("neotest").run.stop() end, desc = "Stop" },
    { "<leader>Ts", function() require("neotest").summary.toggle() end, desc = "Summary" },
    { "<leader>Ta", function() require("neotest").run.attach() end, desc = "Attach" },
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-vstest"),
      },
      status = { enabled = true },
      diagnostic = { enabled = true },
    })
  end,
}