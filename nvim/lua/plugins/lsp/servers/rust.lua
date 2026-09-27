-- rust-analyzer settings per
-- https://rust-analyzer.github.io/book/configuration: clippy on save,
-- all-targets check, inlay hints (enabled globally via <leader>ci),
-- proc macros on. Formatting stays off — rustfmt via conform owns it.
return {
	"neovim/nvim-lspconfig",
	opts = {
		servers = {
			rust_analyzer = {
				settings = {
					["rust-analyzer"] = {
						check = {
							command = "clippy",
							allTargets = true,
						},
						cargo = { allTargets = true },
						procMacro = { enable = true },
						inlayHints = {
							bindingModeHints = { enable = true },
							chainingHints = { enable = true },
							closingBraceHints = { enable = true, minLines = 25 },
							closureReturnTypeHints = { enable = "with_block" },
							lifetimeElisionHints = { enable = "skip_trivial" },
							maxLength = 25,
							typeHints = {
								enable = true,
								hideClosureInitialization = false,
								hideNamedConstructor = false,
							},
						},
						lens = { enable = true },
					},
				},
			},
		},
	},
}
