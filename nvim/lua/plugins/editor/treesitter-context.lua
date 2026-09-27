return {
	"nvim-treesitter/nvim-treesitter-context",
	event = { "BufReadPost", "BufNewFile" },
	dependencies = { "nvim-treesitter/nvim-treesitter" },

	opts = {
		enable = true,
		multiwindow = false, -- set true if you want context in all windows
		max_lines = 3, -- how many context lines to show (0 = unlimited)
		min_window_height = 0, -- minimum window height to enable
		line_numbers = true,
		multiline_threshold = 20, -- max lines for a single context node
		trim_scope = "outer", -- "inner" | "outer"
		mode = "cursor", -- "cursor" | "topline"
		separator = nil, -- e.g. "─" for a visual separator
		zindex = 20,

		-- Optional: disable on certain buffers
		on_attach = function(buf)
			local max_filesize = 100 * 1024 -- 100 KB
			local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
			if ok and stats and stats.size > max_filesize then
				return false
			end
		end,
	},

	config = function(_, opts)
		require("treesitter-context").setup(opts)

		-- `[c`/`]c` belong to gitsigns' buffer-local hunk nav, so context jumps
		-- live on `[C` instead of fighting for the same key in git buffers.
		vim.keymap.set("n", "[C", function()
			require("treesitter-context").go_to_context(vim.v.count1)
		end, { silent = true, desc = "Go to context" })
	end,

	keys = {
		{
			"<leader>ut",
			"<cmd>TSContext toggle<cr>",
			desc = "Toggle Treesitter Context",
		},
	},
}
