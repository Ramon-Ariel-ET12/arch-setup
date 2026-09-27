return {
	"Skardyy/neo-img",
	lazy = false,
	build = ":NeoImg Install",
	opts = {
		backend = "auto",
		size = "80%",
		center = true,
		auto_open = true,
		oil_preview = false,
		resizeMode = "Fit",
		offset = "2x3",
		ttyimg = "local",
	},

	config = function(_, opts)
		require("neo-img").setup(opts)
		-- neo-img resolves the target window, then draws late inside
		-- vim.schedule: the window can be gone by then (e.g. preview
		-- floats, closed splits) -> "invalid window id: -1".
		local utils = require("neo-img.utils")
		local display_image = utils.display_image
		utils.display_image = function(filepath, win)
			if type(win) ~= "number" or win < 0 or not vim.api.nvim_win_is_valid(win) then
				return
			end
			return display_image(filepath, win)
		end
	end,
}
