-- clangd has no LSP settings surface of its own: it is tuned via CLI
-- flags and .clangd YAML files (see https://clangd.llvm.org/config).
-- Keep the server config minimal: background index for the project,
-- clang-tidy for linting, header insertion, and full placeholders.
-- clang-format via conform owns formatting.
return {
	"neovim/nvim-lspconfig",
	opts = {
		servers = {
			clangd = {
				cmd = {
					"clangd",
					"--background-index",
					"--clang-tidy",
					"--header-insertion=iwyu",
					"--completion-style=detailed",
					"--function-arg-placeholders=1",
				},
			},
		},
	},
}
