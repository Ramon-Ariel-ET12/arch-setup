local constants = require("constants")

--- Build fd exclude flags from a list of directories.
---@param dirs string[]
---@return string
local function build_fd_opts(dirs)
	local excludes = table.concat(
		vim.tbl_map(function(d)
			return ("--exclude %s"):format(d)
		end, dirs),
		" "
	)
	return ("--color=never --type f --type l --hidden --follow %s"):format(excludes)
end

--- Build ripgrep options excluding the shared skip dirs (see constants).
---@return string
local function build_rg_opts()
	local globs = table.concat(
		vim.tbl_map(function(g)
			return ("-g %q"):format(g)
		end, constants.rg_exclude_globs()),
		" "
	)
	return ("--column --line-number --no-heading --color=always --smart-case --hidden --max-columns=4096 %s"):format(
		globs
	)
end

return {
	"ibhagwan/fzf-lua",
	cmd = "FzfLua",
	event = "VeryLazy",

	dependencies = {
		"echasnovski/mini.icons",
	},

	opts = function()
		local fd_opts = build_fd_opts(constants.DEFAULT_SKIP)
		local rg_opts = build_rg_opts()
		local actions = require("fzf-lua.actions")

		return {
			------------------------------------------------------------------
			-- Global
			------------------------------------------------------------------
			file_icons = "mini", -- use mini.icons
			git_icons = true, -- show git status icons where relevant
			color_icons = true,

			-- Optional: auto-generate fzf colors from your colorscheme
			-- fzf_colors = true,

			------------------------------------------------------------------
			-- Window
			------------------------------------------------------------------
			winopts = {
				height = 0.85,
				width = 0.90,
				row = 0.35,
				col = 0.50,
				border = constants.BORDER,
				backdrop = 60,
				title_pos = "center",

				preview = {
					default = "builtin", -- or "bat" / "bat_native" if you prefer
					border = constants.BORDER,
					wrap = false,
					hidden = false,
					vertical = "down:45%",
					horizontal = "right:55%",
					layout = "flex",
					flip_columns = 120, -- switch to vertical when narrow
					scrollbar = "float",
				},
			},

			------------------------------------------------------------------
			-- Keymaps (inside the fzf window)
			------------------------------------------------------------------
			keymap = {
				builtin = {
					["<C-j>"] = "down",
					["<C-k>"] = "up",
					["<C-d>"] = "preview-page-down",
					["<C-u>"] = "preview-page-up",
					["<C-f>"] = "preview-page-down",
					["<C-b>"] = "preview-page-up",
					["<F1>"] = "toggle-help",
					["<F2>"] = "toggle-fullscreen",
					["<F3>"] = "toggle-preview-wrap",
					["<F4>"] = "toggle-preview",
					["<F5>"] = "toggle-preview-cw",
				},
				fzf = {
					["ctrl-j"] = "down",
					["ctrl-k"] = "up",
					["ctrl-u"] = "half-page-up",
					["ctrl-d"] = "half-page-down",
					["ctrl-f"] = "preview-page-down",
					["ctrl-b"] = "preview-page-up",
					["ctrl-/"] = "toggle-preview",
					["ctrl-q"] = "select-all+accept", -- send all to quickfix
					["alt-a"] = "toggle-all",
				},
			},

			------------------------------------------------------------------
			-- Global fzf flags
			------------------------------------------------------------------
			fzf_opts = {
				["--layout"] = "reverse",
				["--info"] = "inline-right",
				["--highlight-line"] = true,
				["--cycle"] = true,
			},

			------------------------------------------------------------------
			-- Pickers
			------------------------------------------------------------------
			files = {
				prompt = "Files❯ ",
				hidden = true,
				follow = true,
				fd_opts = fd_opts,
				fzf_opts = {
					["--scheme"] = "path",
					["--multi"] = true,
				},
				formatter = "path.filename_first",
				-- cwd_header = true,
			},

			git_files = {
				prompt = "Git Files❯ ",
				hidden = true,
				cmd = "git ls-files --cached --others --exclude-standard",
				fzf_opts = {
					["--scheme"] = "path",
					["--multi"] = true,
				},
			},

			oldfiles = {
				prompt = "Recent❯ ",
				cwd_only = false,
				include_current_session = true,
			},

			live_grep = {
				prompt = "Live Grep❯ ",
				rg_opts = rg_opts,
				fzf_opts = {
					["--scheme"] = "path",
				},
				-- exec_empty_query = true, -- show all files when query is empty
			},

			grep = {
				prompt = "Grep❯ ",
				rg_opts = rg_opts,
			},

			buffers = {
				prompt = "Buffers❯ ",
				sort_lastused = true,
				ignore_current_buffer = false,
				show_unloaded = true,
				-- Buffer manager: tab to multi-select, alt-a to select all
				actions = {
					["enter"] = actions.file_edit_or_qf,
					["ctrl-s"] = { fn = actions.buf_split },
					["ctrl-v"] = { fn = actions.buf_vsplit },
					-- Delete the cursor buffer / all selected buffers, list reloads
					["ctrl-x"] = { fn = actions.buf_del, reload = true },
				},
			},

			-- LSP
			lsp_references = {
				prompt = "References❯ ",
				includeDeclaration = false,
				ignore_current_line = true,
			},
			lsp_definitions = { prompt = "Definitions❯ " },
			lsp_declarations = { prompt = "Declarations❯ " },
			lsp_implementations = { prompt = "Implementations❯ " },
			lsp_typedefs = { prompt = "Type Definitions❯ " },
			lsp_document_symbols = { prompt = "Document Symbols❯ " },
			lsp_workspace_symbols = { prompt = "Workspace Symbols❯ " },
			lsp_live_workspace_symbols = { prompt = "Live Workspace Symbols❯ " },
			lsp_code_actions = { prompt = "Code Actions❯ " },
			lsp_finder = { prompt = "LSP Finder❯ " },

			-- Diagnostics
			diagnostics = {
				prompt = "Diagnostics❯ ",
				multiline = true,
			},
			diagnostics_document = {
				prompt = "Document Diagnostics❯ ",
				multiline = true,
			},
			diagnostics_workspace = {
				prompt = "Workspace Diagnostics❯ ",
				multiline = true,
			},

			-- Git
			git_status = {
				prompt = "Git Status❯ ",
				preview_pager = "delta --width=$FZF_PREVIEW_COLUMNS", -- if you have delta
			},
			git_commits = { prompt = "Git Commits❯ " },
			git_bcommits = { prompt = "Buffer Commits❯ " },
			git_branches = { prompt = "Branches❯ " },
			git_tags = { prompt = "Tags❯ " },
			git_stash = { prompt = "Stash❯ " },

			-- Misc
			helptags = { prompt = "Help❯ " },
			keymaps = {
				prompt = "Keymaps❯ ",
				show_desc = true,
				show_details = true,
			},
			commands = { prompt = "Commands❯ " },
			marks = { prompt = "Marks❯ " },
			registers = { prompt = "Registers❯ " },
			colorschemes = {
				prompt = "Colorschemes❯ ",
				live_preview = true,
				winopts = { height = 0.55, width = 0.30 },
			},
		}
	end,

	config = function(_, opts)
		require("fzf-lua").setup(opts)
		require("fzf-lua").register_ui_select()
	end,

	keys = {
		-- Files
		{ "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find Files" },
		{ "<leader>fg", "<cmd>FzfLua git_files<cr>", desc = "Git Files" },
		{ "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "Recent Files" },
		{ "<leader>fF", "<cmd>FzfLua files cwd=~<cr>", desc = "Find Files (Home)" },

		-- Search
		{ "<leader>sg", "<cmd>FzfLua live_grep<cr>", desc = "Live Grep" },
		{ "<leader>sG", "<cmd>FzfLua live_grep_glob<cr>", desc = "Live Grep (Glob)" },
		{ "<leader>sw", "<cmd>FzfLua grep_cword<cr>", desc = "Grep Word" },
		{ "<leader>sW", "<cmd>FzfLua grep_cWORD<cr>", desc = "Grep WORD" },
		{ "<leader>ss", "<cmd>FzfLua grep_visual<cr>", desc = "Grep Selection", mode = "v" },
		{ "<leader>sb", "<cmd>FzfLua grep_curbuf<cr>", desc = "Grep Buffer" },
		{ "<leader>sp", "<cmd>FzfLua grep_project<cr>", desc = "Grep Project" },

		-- Buffers / Lines
		{ "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Buffers" },
		{ "<leader>fl", "<cmd>FzfLua blines<cr>", desc = "Buffer Lines" },
		{ "<leader>fL", "<cmd>FzfLua lines<cr>", desc = "All Lines" },

		-- LSP
		{ "<leader>cD", "<cmd>FzfLua lsp_definitions<cr>", desc = "Definitions" },
		{ "<leader>cR", "<cmd>FzfLua lsp_references<cr>", desc = "References" },
		{ "<leader>cI", "<cmd>FzfLua lsp_implementations<cr>", desc = "Implementations" },
		{ "<leader>cy", "<cmd>FzfLua lsp_typedefs<cr>", desc = "Type Definitions" },
		{ "<leader>cs", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Document Symbols" },
		{ "<leader>cS", "<cmd>FzfLua lsp_workspace_symbols<cr>", desc = "Workspace Symbols" },
		{ "<leader>ca", "<cmd>FzfLua lsp_code_actions<cr>", desc = "Code Actions" },
		{ "<leader>cl", "<cmd>FzfLua lsp_finder<cr>", desc = "LSP Finder (All)" },

		-- Diagnostics
		{ "<leader>cx", "<cmd>FzfLua diagnostics_document<cr>", desc = "Document Diagnostics" },
		{ "<leader>cX", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "Workspace Diagnostics" },

		-- Git
		{ "<leader>gs", "<cmd>FzfLua git_status<cr>", desc = "Git Status" },
		{ "<leader>gc", "<cmd>FzfLua git_commits<cr>", desc = "Git Commits" },
		{ "<leader>gC", "<cmd>FzfLua git_bcommits<cr>", desc = "Buffer Commits" },
		{ "<leader>gb", "<cmd>FzfLua git_branches<cr>", desc = "Git Branches" },
		{ "<leader>gt", "<cmd>FzfLua git_tags<cr>", desc = "Git Tags" },

		-- Misc
		{ "<leader>:", "<cmd>FzfLua commands<cr>", desc = "Commands" },
		{ "<leader>fh", "<cmd>FzfLua helptags<cr>", desc = "Help" },
		{ "<leader>fk", "<cmd>FzfLua keymaps<cr>", desc = "Keymaps" },
		{ "<leader>fm", "<cmd>FzfLua marks<cr>", desc = "Marks" },
		{ "<leader>fR", "<cmd>FzfLua registers<cr>", desc = "Registers" },
		{ "<leader>uC", "<cmd>FzfLua colorschemes<cr>", desc = "Colorschemes" },
		{ "<leader>fH", "<cmd>FzfLua highlights<cr>", desc = "Highlights" },

		-- Resume last picker
		{ "<leader><leader>", "<cmd>FzfLua resume<cr>", desc = "Resume" },
	},
}
