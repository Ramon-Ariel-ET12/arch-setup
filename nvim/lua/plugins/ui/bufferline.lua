local constants = require("constants")

return {
  "akinsho/bufferline.nvim",
  event = "VeryLazy",
  dependencies = { "echasnovski/mini.icons" },
  keys = {
    { "<S-h>", "<cmd>BufferLineCyclePrev<CR>", desc = "Prev buffer" },
    { "<S-l>", "<cmd>BufferLineCycleNext<CR>", desc = "Next buffer" },
    { "<leader>bp", "<cmd>BufferLinePick<CR>", desc = "Pick buffer" },
    { "<leader>bs", "<cmd>BufferLinePickClose<CR>", desc = "Pick to close" },
    { "<leader>bt", "<cmd>BufferLineTogglePin<CR>", desc = "Toggle pin buffer" },
  },
  opts = {
    options = {
      mode = "buffers",
      numbers = "ordinal",
      show_close_icon = false,
      show_buffer_close_icons = true,
      separator_style = "thin",
      diagnostics = "nvim_lsp",
      diagnostics_indicator = function(count, level, _, _)
        local icon = level == "error" and constants.DIAGNOSTIC_ICONS.error
          or constants.DIAGNOSTIC_ICONS.warn
        return " " .. icon .. count
      end,
      color_icons = true,
      offsets = {
        {
          filetype = "neo-tree",
          separator = true,
        },
      },
      auto_toggle_bufferline = true,
    },
  },
  config = function(_, opts)
    -- Catppuccin theme, resolved at setup time (bufferline must load after the colorscheme)
    opts.options.highlights = require("catppuccin.special.bufferline").get_theme()
    require("bufferline").setup(opts)
  end,
}