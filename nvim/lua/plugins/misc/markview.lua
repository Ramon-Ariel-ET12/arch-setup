return {
  "OXY2DEV/markview.nvim",
  lazy = false,
  dependencies = {
    "echasnovski/mini.icons",
  },
  opts = {
    preview = {
      icon_provider = "mini",
    },
  },
  config = function(_, opts)
    require("markview").setup(opts)
  end,
}
