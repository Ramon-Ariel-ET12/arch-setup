local constants = require("constants")

return {

	-- ╭──────────────────────────────────────────────────────────╮
	-- │ Noice                                                       │
	-- ╰──────────────────────────────────────────────────────────╯

	{
		"folke/noice.nvim",
		event = "VeryLazy",

		dependencies = {
			"MunifTanjim/nui.nvim",
			"echasnovski/mini.icons",
			"rcarriga/nvim-notify",
		},

		opts = {
			-- ────────────────────────────────────────────────────────
			-- Presets
			-- ────────────────────────────────────────────────────────

			presets = {
				bottom_search = false,

				command_palette = true,

				long_message_to_split = true,

				inc_rename = false,

				lsp_doc_border = true,
			},

			-- ────────────────────────────────────────────────────────
			-- Command line
			-- ────────────────────────────────────────────────────────

			cmdline = {
				enabled = true,

				view = "cmdline_popup",

				format = {
					cmdline = {
						icon = ":",
						lang = "vim",
					},

					search_down = {
						icon = " ↓",
					},

					search_up = {
						icon = " ↑",
					},

					filter = {
						icon = "$",
					},

					lua = {
						icon = "",
					},

					help = {
						icon = "?",
					},

					input = {
						icon = "➤",
					},
				},
			},

			-- ────────────────────────────────────────────────────────
			-- Messages
			-- ────────────────────────────────────────────────────────

			messages = {
				enabled = true,

				view = "notify",

				view_error = "notify",
				view_warn = "notify",
				view_history = "messages",
				view_search = "virtualtext",
			},

			-- ────────────────────────────────────────────────────────
			-- Popup menu
			-- ────────────────────────────────────────────────────────

			popupmenu = {
				enabled = true,

				backend = "nui",

				kind_icons = {
					Text = "󰉿",
					Method = "󰆧",
					Function = "󰊕",
					Constructor = "",
					Field = "󰜢",
					Variable = "󰀫",
					Class = "󰠱",
					Interface = "",
					Module = "",
					Property = "󰜢",
					Unit = "󰑭",
					Value = "󰎠",
					Enum = "",
					Keyword = "󰌋",
					Snippet = "",
					Color = "󰏘",
					File = "󰈙",
					Reference = "󰈇",
					Folder = "󰉋",
					EnumMember = "",
					Constant = "󰏿",
					Struct = "󰙅",
					Event = "",
					Operator = "󰆕",
					TypeParameter = "󰊄",
				},
			},

			-- ────────────────────────────────────────────────────────
			-- Notifications
			-- ────────────────────────────────────────────────────────

			notify = {
				enabled = true,

				view = "notify",

				merge = false,
				replace = false,
			},

			-- ────────────────────────────────────────────────────────
			-- LSP
			-- ────────────────────────────────────────────────────────

			lsp = {
				progress = {
					enabled = true,

					view = "mini",

					opts = {
						border = {
							style = constants.BORDER,
						},

						position = {
							row = 1,
							col = "100%",
						},
					},
				},

				hover = {
					enabled = true,
					silent = true,
				},

				signature = {
					enabled = true,

					auto_open = {
						enabled = true,
						trigger = true,
						luasnip = true,
						throttle = 50,
					},

					opts = {
						size = {
							max_width = 80,
							max_height = 20,
						},
					},
				},

				message = {
					enabled = true,
				},

				documentation = {
					view = "hover",

					opts = {
						border = {
							style = constants.BORDER,
						},
					},
				},

				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
					["cmp.entry.get_documentation"] = true,
				},
			},

			-- ────────────────────────────────────────────────────────
			-- Views
			-- ────────────────────────────────────────────────────────

			views = {
				-- Notifications pinned to the top-right corner.
				notify = {
					position = {
						row = 1,
						col = "100%",
					},

					size = {
						max_width = 60,
						max_height = 12,
					},
				},

				cmdline_popup = {
					position = {
						row = 1,
						col = "50%",
					},

					size = {
						width = 60,
						height = "auto",
					},

					border = {
						style = constants.BORDER,
						padding = { 0, 1 },
					},

					win_options = {
						winblend = 0,
					},
				},

				popup = {
					border = {
						style = constants.BORDER,
					},

					win_options = {
						winblend = 0,
					},
				},

				hover = {
					border = {
						style = constants.BORDER,
					},

					position = {
						row = 2,
						col = 2,
					},

					size = {
						max_width = 80,
						max_height = 20,
					},

					win_options = {
						winblend = 0,
					},
				},

				mini = {
					position = {
						row = 1,
						col = "100%",
					},

					size = {
						width = "auto",
						height = "auto",
					},

					border = {
						style = constants.BORDER,
					},
				},
			},

			-- ────────────────────────────────────────────────────────
			-- Routes
			-- ────────────────────────────────────────────────────────

			routes = {
				-- Hide "written" messages.
				{
					filter = {
						event = "msg_show",
						kind = "",
						find = "written",
					},

					opts = {
						skip = true,
					},
				},

				-- Hide search boundary messages.
				{
					filter = {
						event = "msg_show",
						find = "search hit BOTTOM",
					},

					opts = {
						skip = true,
					},
				},

				{
					filter = {
						event = "msg_show",
						find = "search hit TOP",
					},

					opts = {
						skip = true,
					},
				},
			},

			throttle = 1000 / 60,
		},

		config = function(_, opts)
			require("noice").setup(opts)
		end,
	},
}
