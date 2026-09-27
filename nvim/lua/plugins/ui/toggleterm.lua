local constants = require("constants")

local MAX_TERMINALS = 5

return {
	"akinsho/toggleterm.nvim",

	version = "*",

	keys = {
		-- ──────────────────────────────────────────────────────────
		-- Toggle terminal
		-- ──────────────────────────────────────────────────────────

		{
			"<C-\\>",
			"<cmd>ToggleTerm<cr>",
			desc = "Toggle Terminal",
			mode = { "n", "i" },
		},

		{
			"<leader>tt",
			"<cmd>ToggleTerm<cr>",
			desc = "Toggle Terminal",
		},

		-- ──────────────────────────────────────────────────────────
		-- Create / select terminals
		-- ──────────────────────────────────────────────────────────

		{
			"<leader>tn",
			function()
				local Terminal = require("toggleterm.terminal")
				local terminals = Terminal.get_all()

				if #terminals >= MAX_TERMINALS then
					vim.notify(("Maximum of %d terminals reached"):format(MAX_TERMINALS), vim.log.levels.WARN)
					return
				end

				vim.cmd("TermNew")
			end,
			desc = "New Terminal",
		},

		{
			"<leader>ts",
			"<cmd>TermSelect<cr>",
			desc = "Select Terminal",
		},

		-- ──────────────────────────────────────────────────────────
		-- Direct terminal access
		-- ──────────────────────────────────────────────────────────

		{
			"<leader>t1",
			"<cmd>1ToggleTerm<cr>",
			desc = "Toggle Terminal 1",
		},

		{
			"<leader>t2",
			"<cmd>2ToggleTerm<cr>",
			desc = "Toggle Terminal 2",
		},

		{
			"<leader>t3",
			"<cmd>3ToggleTerm<cr>",
			desc = "Toggle Terminal 3",
		},

		{
			"<leader>t4",
			"<cmd>4ToggleTerm<cr>",
			desc = "Toggle Terminal 4",
		},

		{
			"<leader>t5",
			"<cmd>5ToggleTerm<cr>",
			desc = "Toggle Terminal 5",
		},
	},

	opts = {
		size = 20,

		direction = "float",

		start_in_insert = true,
		close_on_exit = true,

		persist_size = true,
		persist_mode = true,

		-- IMPORTANT:
		-- The current official implementation unconditionally calls
		-- scroll_bottom() when output arrives if this is true.
		--
		-- Disable it so scrolling up while a process is producing
		-- output does not throw you back to the bottom.
		auto_scroll = false,

		shell = vim.o.shell,
		clear_env = false,

		shade_terminals = true,
		shading_factor = 2,

		float_opts = {
			border = constants.BORDER,

			winblend = 0,

			title_pos = "center",

			highlights = {
				border = "FloatBorder",
				background = "NormalFloat",
			},
		},
	},

	config = function(_, opts)
		local toggleterm = require("toggleterm")
		local Terminal = require("toggleterm.terminal")

		toggleterm.setup(opts)

		-- ──────────────────────────────────────────────────────────
		-- Terminal title
		--
		-- Automatically identifies the terminal without requiring:
		--
		--   :ToggleTermSetName
		--
		-- Example:
		--
		--   Terminal 1 · backend
		--   Terminal 2 · frontend
		--   Terminal 3 · nvim
		--
		-- The ID makes identical directories distinguishable.
		-- ──────────────────────────────────────────────────────────

		local function update_float_title(term)
			if not term then
				return
			end

			if not term.window or not vim.api.nvim_win_is_valid(term.window) then
				return
			end

			if not term:is_float() then
				return
			end

			local dir = term.dir or vim.fn.getcwd()
			local project = vim.fn.fnamemodify(dir, ":t")

			if project == "" then
				project = dir
			end

			-- Only generate a name when the user has not explicitly
			-- assigned one with :ToggleTermSetName.
			if not term.display_name or term.display_name == "" then
				term.display_name = ("Terminal %d · %s"):format(term.id, project)
			end

			-- toggleterm's winbar is deliberately disabled for floats,
			-- so update the native floating-window title instead.
			vim.api.nvim_win_set_config(term.window, {
				title = term.display_name,
				title_pos = "center",
			})
		end

		-- Run after toggleterm has associated the terminal buffer
		-- with its Terminal object.
		vim.api.nvim_create_autocmd("TermOpen", {
			pattern = "term://*",

			callback = function(args)
				local _, term = Terminal.identify(vim.api.nvim_buf_get_name(args.buf))

				if not term then
					return
				end

				vim.schedule(function()
					update_float_title(term)
				end)
			end,
		})

		-- ──────────────────────────────────────────────────────────
		-- Toggle the terminal currently being used
		--
		-- Particularly useful from terminal mode:
		--
		--   <C-\>
		--
		-- closes the terminal you're actually inside.
		-- ──────────────────────────────────────────────────────────

		vim.keymap.set("t", "<C-\\>", function()
			local id = Terminal.get_focused_id()

			if id then
				toggleterm.toggle(id)
			else
				toggleterm.toggle()
			end
		end, {
			desc = "Toggle Current Terminal",
		})

		-- ──────────────────────────────────────────────────────────
		-- Terminal window navigation
		-- ──────────────────────────────────────────────────────────

		local navigation = {
			["<A-h>"] = "h",
			["<A-j>"] = "j",
			["<A-k>"] = "k",
			["<A-l>"] = "l",
		}

		for key, direction in pairs(navigation) do
			vim.keymap.set("t", key, "<Cmd>wincmd " .. direction .. "<CR>", {
				desc = "Terminal → " .. direction,
			})
		end

		-- ──────────────────────────────────────────────────────────
		-- Switch between existing terminals
		-- ──────────────────────────────────────────────────────────

		local function cycle_terminal(step)
			local terminals = Terminal.get_all()

			if #terminals == 0 then
				-- No terminal exists yet: create the first one.
				vim.cmd("TermNew")
				return
			end

			if #terminals == 1 then
				terminals[1]:open()
				return
			end

			-- Prefer the terminal we're physically inside.
			local current_id = Terminal.get_focused_id()

			-- If we're in another Neovim window, use the last terminal
			-- that had focus as the reference point.
			if not current_id then
				local last = Terminal.get_last_focused()

				if last then
					current_id = last.id
				end
			end

			local current_index

			for index, term in ipairs(terminals) do
				if term.id == current_id then
					current_index = index
					break
				end
			end

			-- No previously focused terminal.
			if not current_index then
				local target_index

				if step > 0 then
					target_index = 1
				else
					target_index = #terminals
				end

				terminals[target_index]:open()
				return
			end

			local next_index = ((current_index - 1 + step) % #terminals) + 1

			local current = terminals[current_index]
			local next = terminals[next_index]

			-- Floats should not overlap each other.
			if current:is_open() then
				current:close()
			end

			next:open()
		end

		-- Works both from terminal mode and normal mode.
		for _, mode in ipairs({ "n", "t" }) do
			vim.keymap.set(mode, "<A-.>", function()
				cycle_terminal(1)
			end, {
				desc = "Next Terminal",
			})

			vim.keymap.set(mode, "<A-,>", function()
				cycle_terminal(-1)
			end, {
				desc = "Previous Terminal",
			})
		end
	end,
}
