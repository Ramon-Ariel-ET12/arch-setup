local constants = require("constants")

return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	dependencies = { "echasnovski/mini.icons" }, -- or nvim-tree/nvim-web-devicons

	opts = {
		options = {
			theme = "auto", -- follows Catppuccin (and any :colorscheme)
			globalstatus = true, -- matches opt.laststatus = 3
			icons_enabled = true,

			component_separators = {
				left = "│",
				right = "│",
			},
			section_separators = {
				left = "",
				right = "",
			},

			disabled_filetypes = {
				statusline = {
					"alpha",
					"dashboard",
					"neo-tree",
					"NvimTree",
					"lazy",
					"mason",
					"fzf",
					"fzf-lua",
					"toggleterm",
				},
				winbar = {},
			},

			always_divide_middle = true,
			refresh = {
				statusline = 100,
				tabline = 100,
				winbar = 100,
			},
		},

		--------------------------------------------------------------
		-- Active sections
		--------------------------------------------------------------
		sections = {
			lualine_a = {
				{
					"mode",
					fmt = function(mode)
						return mode:sub(1, 1) -- N / I / V / C ...
					end,
				},
			},

			lualine_b = {
				{
					"branch",
					icon = "",
					max_length = 20,
				},
				{
					"diff",
					symbols = {
						added = "+",
						modified = "~",
						removed = "-",
					},
					source = function()
						local gitsigns = vim.b.gitsigns_status_dict
						if gitsigns then
							return {
								added = gitsigns.added,
								modified = gitsigns.changed,
								removed = gitsigns.removed,
							}
						end
					end,
				},
				{
					"diagnostics",
					sources = { "nvim_diagnostic" },
					symbols = vim.tbl_map(function(icon)
						return icon .. " "
					end, constants.DIAGNOSTIC_ICONS),
				},
			},

			lualine_c = {
				{
					"filename",
					path = 1, -- relative
					symbols = {
						modified = " ●",
						readonly = " ",
						unnamed = "[No Name]",
						newfile = " 󰎔",
					},
				},
			},

			lualine_x = {
				-- Inline git blame (only when available)
				{
					function()
						local blame = vim.b.gitsigns_blame_line_dict
						if not blame then
							return ""
						end
						local author = blame.author or ""
						local time = os.date("%d %b %H:%M", blame.author_time or 0)
						local msg = blame.summary or ""
						if #msg > 28 then
							msg = msg:sub(1, 25) .. "…"
						end
						return string.format("%s %s  %s", time, author, msg)
					end,
					icon = "󰊢",
					color = { fg = "Comment" },
					cond = function()
						return vim.b.gitsigns_blame_line_dict ~= nil
					end,
				},

				-- LSP clients for current buffer
				{
					function()
						local clients = vim.lsp.get_clients({ bufnr = 0 })
						if #clients == 0 then
							return ""
						end
						local names = {}
						for _, c in ipairs(clients) do
							table.insert(names, c.name)
						end
						return table.concat(names, ",")
					end,
					icon = "󰒋",
					color = { fg = "Comment" },
				},

				{
					"fileformat",
					symbols = constants.FILEFORMAT_ICONS,
				},
				{
					"encoding",
					fmt = string.upper,
					cond = function()
						return vim.bo.fileencoding ~= "" and vim.bo.fileencoding ~= "utf-8"
					end,
				},
				{
					"filetype",
					icon_only = true,
					colored = true,
				},
			},

			lualine_y = {
				{
					"progress",
					fmt = function()
						return "%P"
					end,
				},
			},

			lualine_z = {
				{
					"location",
					padding = { left = 0, right = 1 },
				},
			},
		},

		--------------------------------------------------------------
		-- Inactive (keeps it clean with transparent Catppuccin)
		--------------------------------------------------------------
		inactive_sections = {
			lualine_a = {},
			lualine_b = {},
			lualine_c = {
				{
					"filename",
					path = 1,
					symbols = {
						modified = " ●",
						readonly = " ",
					},
				},
			},
			lualine_x = { "location" },
			lualine_y = {},
			lualine_z = {},
		},

		extensions = {
			"lazy",
			"mason",
			"neo-tree",
			"quickfix",
			"toggleterm",
		},
	},
}
