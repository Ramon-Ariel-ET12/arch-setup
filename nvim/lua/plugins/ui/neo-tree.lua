local constants = require("constants")

---Delete the buffers of the given tree nodes.
---Unsaved buffers are skipped with a warning instead of erroring.
---@param nodes table[]
local function delete_buffer_nodes(nodes)
	local skipped = 0
	for _, node in ipairs(nodes) do
		local bufnr = node.extra and node.extra.bufnr
		if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
			local ok = pcall(vim.api.nvim_buf_delete, bufnr, { force = false, unload = false })
			if not ok then
				skipped = skipped + 1
			end
		end
	end
	if skipped > 0 then
		vim.notify(
			("%d buffer(s) skipped — unsaved changes (force with :bd!)"):format(skipped),
			vim.log.levels.WARN
		)
	end
	require("neo-tree.sources.manager").refresh("buffers")
end

return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",

	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"echasnovski/mini.icons", -- or nvim-tree/nvim-web-devicons
	},

	cmd = "Neotree",

	keys = {
		{ "<leader>e", "<cmd>Neotree toggle filesystem left<cr>", desc = "Explorer" },
		{ "<leader>E", "<cmd>Neotree reveal<cr>", desc = "Explorer reveal" },
		{ "<leader>ge", "<cmd>Neotree git_status float<cr>", desc = "Git status (tree)" },
		{ "<leader>be", "<cmd>Neotree buffers float<cr>", desc = "Buffer manager" },
	},

	opts = {
		close_if_last_window = true,
		popup_border_style = constants.BORDER, -- uses winborder on 0.11+ if set to ""
		enable_git_status = true,
		enable_diagnostics = true,
		enable_modified_markers = true,
		enable_opened_markers = true,
		enable_refresh_on_write = true,

		sources = {
			"filesystem",
			"buffers",
			"git_status",
			-- "document_symbols", -- optional
		},

		source_selector = {
			winbar = true, -- nice tabs to switch filesystem / buffers / git
			content_layout = "center",
			sources = {
				{ source = "filesystem", display_name = " 󰉓 Files " },
				{ source = "buffers", display_name = " 󰈙 Buffers " },
				{ source = "git_status", display_name = " 󰊢 Git " },
			},
		},

		default_component_configs = {
			indent = {
				indent_size = 2,
				padding = 1,
				with_markers = true,
				indent_marker = "│",
				last_indent_marker = "└",
				with_expanders = true,
				expander_collapsed = "",
				expander_expanded = "",
			},
			icon = {
				folder_closed = "",
				folder_open = "",
				folder_empty = "󰜌",
				default = "󰈔",
			},
			modified = {
				symbol = "●",
			},
			name = {
				trailing_slash = false,
				use_git_status_colors = true,
			},
			git_status = {
				symbols = {
					added = "✚",
					modified = "",
					deleted = "✖",
					renamed = "󰁕",
					untracked = "",
					ignored = "",
					unstaged = "󰄱",
					staged = "",
					conflict = "",
				},
			},
			diagnostics = {
				symbols = constants.DIAGNOSTIC_ICONS,
			},
		},

		--------------------------------------------------------------
		-- Filesystem
		--------------------------------------------------------------
		filesystem = {
			filtered_items = {
				visible = false,
				hide_dotfiles = true,
				hide_gitignored = true,
				hide_hidden = true,
				hide_by_name = constants.DEFAULT_SKIP, -- same skip set as the fzf-lua pickers
				never_show = {
					".DS_Store",
					"thumbs.db",
				},
			},

			follow_current_file = {
				enabled = true,
				leave_dirs_open = false,
			},

			group_empty_dirs = false,
			hijack_netrw_behavior = "open_default",
			use_libuv_file_watcher = true,

			window = {
				mappings = {
					["<space>"] = "none",
					["l"] = "open",
					["h"] = "close_node",
					["<cr>"] = "open",
					["o"] = "open",
					["S"] = "open_split",
					["s"] = "open_vsplit",
					["t"] = "open_tabnew",
					["C"] = "close_node",
					["z"] = "close_all_nodes",
					["Z"] = "expand_all_nodes",
					["a"] = {
						"add",
						config = {
							show_path = "relative", -- "none" | "relative" | "absolute"
						},
					},
					["A"] = "add_directory",
					["d"] = "delete",
					["r"] = "rename",
					["y"] = "copy_to_clipboard",
					["x"] = "cut_to_clipboard",
					["p"] = "paste_from_clipboard",
					["c"] = "copy",
					["m"] = "move",
					["q"] = "close_window",
					["R"] = "refresh",
					["?"] = "show_help",
					["."] = "toggle_hidden",
					["/"] = "fuzzy_finder",
					["<C-x>"] = "clear_filter",
					["[g"] = "prev_git_modified",
					["]g"] = "next_git_modified",
					["O"] = "system_open",
					["P"] = {
						"toggle_preview",
						config = { use_float = true },
					},
				},
			},

			commands = {
				system_open = function(state)
					local node = state.tree:get_node()
					if not node then
						return
					end
					vim.ui.open(node:get_id())
				end,
			},
		},

		--------------------------------------------------------------
		-- Window (global defaults)
		--------------------------------------------------------------
		window = {
			position = "left",
			width = 34,
			mapping_options = {
				noremap = true,
				nowait = true,
			},
		},

		--------------------------------------------------------------
		-- Buffers / Git / Diagnostics
		--------------------------------------------------------------
		buffers = {
			follow_current_file = {
				enabled = true,
				leave_dirs_open = false,
			},
			group_empty_dirs = true,
			show_unloaded = true,
			commands = {
				-- Close the buffer under the cursor, warn on unsaved instead of erroring.
				buffer_delete = function(state)
					local node = state.tree:get_node()
					if node and node.type ~= "message" then
						delete_buffer_nodes({ node })
					end
				end,
				-- Visual mode: V to select rows, then d closes every selected buffer.
				buffer_delete_visual = function(_, selected_nodes)
					delete_buffer_nodes(selected_nodes)
				end,
			},
			window = {
				mappings = {
					["l"] = "open",
					["h"] = "close_node",
				},
			},
		},

		git_status = {
			window = {
				position = "float",
				mappings = {
					["A"] = "git_add_all",
					["gu"] = "git_unstage_file",
					["ga"] = "git_add_file",
					["gr"] = "git_revert_file",
					["gc"] = "git_commit",
					["gp"] = "git_push",
					["gg"] = "git_commit_and_push",
				},
			},
		},

		--------------------------------------------------------------
		-- Events
		--------------------------------------------------------------
		event_handlers = {
			{
				event = "file_opened",
				handler = function()
					-- Close the tree after opening a file (your current behavior)
					require("neo-tree.command").execute({ action = "close" })
				end,
			},
			{
				event = "neo_tree_buffer_enter",
				handler = function()
					vim.opt_local.relativenumber = false
					vim.opt_local.number = false
					vim.opt_local.signcolumn = "no"
				end,
			},
		},
	},
}
