return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false, -- required: do not lazy-load
	build = ":TSUpdate",

	config = function()
		------------------------------------------------------------------
		-- Optional: change install location (default is fine for most)
		------------------------------------------------------------------
		require("nvim-treesitter").setup({
			-- install_dir = vim.fn.stdpath("data") .. "/site",
		})

		------------------------------------------------------------------
		-- Install the parsers you actually use
		------------------------------------------------------------------
		require("nvim-treesitter").install({
			-- Core / always useful
			"bash",
			"c",
			"comment", -- better comment highlighting
			"diff",
			"lua",
			"luadoc",
			"luap", -- Lua patterns
			"latex", -- markview.nvim
			"markdown",
			"markdown_inline",
			"query",
			"regex",
			"vim",
			"vimdoc",

			-- Web / frontend
			"css",
			"scss",
			"html",
			"javascript",
			"jsdoc",
			"json", -- also serves jsonc (nvim maps that filetype to this parser)
			"tsx",
			"typescript",
			"yaml",

			-- Systems / your stack
			"c_sharp",
			"razor",
			"rust",
			"toml",
			"python",
			"c",
			"cpp",

			-- Optional but nice
			"dockerfile",
			"git_config",
			"git_rebase",
			"gitattributes",
			"gitcommit",
			"gitignore",
			"sql",
		})

		------------------------------------------------------------------
		-- Enable Treesitter features on every supported buffer
		------------------------------------------------------------------
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("TreesitterSetup", { clear = true }),
			callback = function(args)
				local buf = args.buf

				-- 1. Syntax highlighting (the most important one)
				local ok = pcall(vim.treesitter.start, buf)
				if not ok then
					return
				end

				-- 2. Indentation (provided by nvim-treesitter)
				vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

				-- 3. Folding (native Neovim treesitter folds)
				-- Apply to every window that currently shows this buffer
				for _, win in ipairs(vim.fn.win_findbuf(buf)) do
					vim.wo[win].foldmethod = "expr"
					vim.wo[win].foldexpr = "v:lua.vim.treesitter.foldexpr()"
					-- Optional quality-of-life:
					-- vim.wo[win].foldlevel = 99
					-- vim.wo[win].foldenable = true
				end
			end,
		})

		-- Re-apply folds when a treesitter buffer enters a new window
		vim.api.nvim_create_autocmd("BufWinEnter", {
			group = vim.api.nvim_create_augroup("TreesitterFolds", { clear = true }),
			callback = function(args)
				if not pcall(vim.treesitter.get_parser, args.buf) then
					return
				end
				vim.wo[0].foldmethod = "expr"
				vim.wo[0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
			end,
		})
	end,
}
