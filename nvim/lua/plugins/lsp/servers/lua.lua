-- lua_ls settings per the LuaLS wiki:
-- https://luals.github.io/wiki/settings/ and the Neovim client example at
-- https://luals.github.io/wiki/configuration/#neovim
return {
	"neovim/nvim-lspconfig",
	opts = {
		servers = {
			lua_ls = {
				settings = {
					Lua = {
						runtime = { version = "LuaJIT" },
						diagnostics = { globals = { "vim" } },
						workspace = {
							checkThirdParty = "Disable",
							library = vim.api.nvim_get_runtime_file("", true),
						},
						hint = { enable = true },
						-- stylua via conform owns formatting
						format = { enable = false },
						completion = { callSnippet = "Replace" },
					},
				},
			},
		},
	},
}
