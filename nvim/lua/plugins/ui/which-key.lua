local constants = require("constants")

return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  dependencies = {
    "echasnovski/mini.icons",
  },

  opts = {
    preset = "modern",

    spec = {
      { "<leader><tab>", group = "Tabs" },
      { "<leader>b", group = "Buffer" },
      { "<leader>c", group = "Code" },
      { "<leader>d", group = "Database" },
      { "<leader>e", group = "Explorer" },
      { "<leader>f", group = "Find" },
      { "<leader>g", group = "Git" },
      { "<leader>h", group = "Hunks" },
      { "<leader>o", group = "Octo" },
      { "<leader>p", group = "Plugins" },
      { "<leader>R", group = "REST" },
      { "<leader>s", group = "Search" },
      { "<leader>t", group = "Terminal" },
      { "<leader>T", group = "Tests" },
      { "<leader>u", group = "UI Toggles" },
      { "<leader>w", group = "Window" },
    },

    icons = {
      breadcrumb = "»",
      separator = "󰖀 ",
      group = "+",
      ellipsis = "…",
    },

    show_help = true,
    show_keys = false,

    win = {
      border = constants.BORDER,
      padding = { 1, 2, 1, 2 },
      title = true,
      title_pos = "center",
      zindex = 1000,
    },

    layout = {
      width = {
        min = 20,
        max = 50,
      },
      spacing = 3,
      align = "left",
    },
  },
}
