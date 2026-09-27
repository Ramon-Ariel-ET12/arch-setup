local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

local group = augroup("user_cmds", { clear = true })

-- Highlight the yanked region
autocmd("TextYankPost", {
	group = group,
	callback = function()
		vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
	end,
})

-- Auto resize splits when the window is resized
autocmd("VimResized", {
	group = group,
	callback = function()
		vim.cmd("tabdo wincmd =")
	end,
})

-- Bad habit logger: restore cursor position when reopening a file
autocmd("BufReadPost", {
	group = group,
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local ok = mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0)
		if ok then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

-- Wrap and some comforts for prose / docs
autocmd("FileType", {
	group = group,
	pattern = {
		"markdown",
		"text",
		"gitcommit",
		"help",
		"conf",
		"http",
		"sql",
	},
	callback = function()
		vim.opt_local.wrap = true
		vim.opt_local.linebreak = true
	end,
})

-- Stop `aq`/`aQ` style delays in terminal buffers
autocmd("TermOpen", {
	group = group,
	callback = function()
		vim.opt_local.number = false
		vim.opt_local.relativenumber = false
	end,
})

-- Autoread: poke checktime so 'autoread' can actually reload.
-- On nightly/0.13+ autoread uses fs watchers (real-time); this remains safe fallback.
autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
	group = group,
	callback = function()
		if vim.fn.getcmdwintype() == "" then
			vim.cmd("checktime")
		end
	end,
	desc = "checktime on focus / terminal close",
})

autocmd({ "BufEnter", "CursorHold", "CursorHoldI" }, {
	group = group,
	callback = function()
		if vim.fn.getcmdwintype() == "" then
			vim.cmd("checktime")
		end
	end,
	desc = "checktime on bufenter / idle",
})

autocmd("FileChangedShellPost", {
	group = group,
	callback = function()
		vim.notify("File changed on disk — buffer reloaded", vim.log.levels.INFO)
	end,
	desc = "notify when autoread reloaded a file",
})

-- Razor / CSHTML support for roslyn
vim.filetype.add({
	extension = {
		razor = "razor",
		cshtml = "razor",
	},
})

-- LSP attach: buffer-local keymaps (Nvim 0.12 friendly)
autocmd("LspAttach", {
	group = group,
	callback = function(event)
		local buf = event.buf
		local client = vim.lsp.get_client_by_id(event.data.client_id)

		-- Duplicate guard: attaching a second client with the same name and
		-- root_dir means a race started two servers for one project (seen
		-- rarely with roslyn, occasionally with others). Keep the oldest
		-- (lowest id) and stop the newcomer — but only when the roots match,
		-- so other projects' servers are never touched.
		if client then
			local root = client.config and client.config.root_dir
			for _, other in ipairs(vim.lsp.get_clients({ name = client.name })) do
				if other.id < client.id and (other.config and other.config.root_dir) == root then
					vim.lsp.buf_detach_client(buf, client.id)
					client:stop()
					return
				end
			end
		end

		local map = function(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
		end

		-- Definition/References/Implementation are owned by fzf-lua pickers
		-- (<leader>cD / <leader>cR / <leader>cI) — see lua/plugins/ui/fzf-lua.lua.
		-- Only actions without a picker equivalent live here.
		map("n", "<leader>cG", vim.lsp.buf.declaration, "Goto declaration")
		map("n", "<leader>cT", vim.lsp.buf.type_definition, "Goto type definition")
		map("n", "<leader>cr", vim.lsp.buf.rename, "Rename")
		map("n", "grr", "<cmd>FzfLua lsp_references<cr>", "References (fzf)")
		map("n", "]d", function()
			vim.diagnostic.jump({ count = 1 })
		end, "Next diagnostic")
		map("n", "[d", function()
			vim.diagnostic.jump({ count = -1 })
		end, "Prev diagnostic")
		map("n", "]e", function()
			vim.diagnostic.jump({ count = 1, severity = { min = vim.diagnostic.severity.ERROR } })
		end, "Next error")
		map("n", "[e", function()
			vim.diagnostic.jump({ count = -1, severity = { min = vim.diagnostic.severity.ERROR } })
		end, "Prev error")
		map("n", "]w", function()
			vim.diagnostic.jump({ count = 1, severity = { min = vim.diagnostic.severity.WARNING } })
		end, "Next warning")
		map("n", "[w", function()
			vim.diagnostic.jump({ count = -1, severity = { min = vim.diagnostic.severity.WARNING } })
		end, "Prev warning")
		map("n", "<leader>cd", vim.diagnostic.open_float, "Show diagnostics")

		-- Formatting is owned by conform.nvim (<leader>cf / <leader>cF).

		map("n", "<leader>ci", function()
			vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }))
		end, "Toggle inlay hints")
	end,
})

-- Inlay hints enabled globally once servers support them
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = function()
		pcall(vim.lsp.inlay_hint.enable, true)
	end,
})
