return {
  "echasnovski/mini.icons",
  event = "VeryLazy",
  opts = {
    filetype = {
      razor = { glyph = "@", hl = "MiniIconsAzure" },
    },
    extension = {
      razor = { glyph = "@", hl = "MiniIconsAzure" },
      cshtml = { glyph = "@", hl = "MiniIconsAzure" },
    },
  },
  init = function()
    -- Make plugins that expect nvim-web-devicons work through mini.icons
    package.preload["nvim-web-devicons"] = function()
      require("mini.icons").mock_nvim_web_devicons()
      return package.loaded["nvim-web-devicons"]
    end
  end,
}