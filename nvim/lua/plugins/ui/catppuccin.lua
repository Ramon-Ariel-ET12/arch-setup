local constants = require("constants")

return {
	"catppuccin/nvim",
	name = "catppuccin",
	lazy = false,
	priority = 1000,

	opts = {
		flavour = constants.FLAVOUR, -- dark mode
		transparent_background = true,
		float = {
			transparent = true, -- see-through floating windows (blink/noice/fzf/...)
		},
		term_colors = true, -- feed the terminal palette (kitty parity)

		integrations = {
			noice = true, -- default false
			which_key = true, -- default false
		},

		custom_highlights = function(colors)
			return {
				-- Keep Lazy / Mason floats opaque (solid contrast over the transparent bg)
				LazyNormal = { bg = colors.mantle, fg = colors.text },
				MasonNormal = { bg = colors.mantle, fg = colors.text },
				-- blink.cmp 'bordered' style paints opaque borders; keep them see-through
				BlinkCmpMenuBorder = { bg = "NONE" },
				BlinkCmpDocBorder = { bg = "NONE" },
				BlinkCmpSignatureHelpBorder = { bg = "NONE" },
				-- Treesitter context strip: float-styled body, subtle bottom underline
				TreesitterContext = { link = "NormalFloat" },
				TreesitterContextLineNumber = { link = "LineNr" },
				TreesitterContextBottom = { underline = true, sp = colors.overlay0 },
			}
		end,
	},

	config = function(_, opts)
		require("catppuccin").setup(opts)
		vim.cmd.colorscheme(constants.COLORSCHEME)
	end,
}
