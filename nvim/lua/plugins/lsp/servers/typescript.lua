-- tsc 7 ships its config as nvim-lspconfig's `tsc` server with a `js/ts`
-- settings block (inlayHints, referencesCodeLens, implementationsCodeLens).
-- eslint server settings per https://github.com/microsoft/vscode-eslint
-- (codeActionsOnSave drives fix-on-save) and emmet init_options per
-- https://github.com/olrtg/emmet-language-server (showSuggestionsAsSnippets
-- marks emmet items as snippets so blink sorts them with the rest).
return {
	"neovim/nvim-lspconfig",
	opts = {
		servers = {
			tsc = {
				settings = {
					["js/ts"] = {
						inlayHints = {
							parameterNames = {
								enabled = "literals",
								suppressWhenArgumentMatchesName = true,
							},
							parameterTypes = { enabled = true },
							variableTypes = { enabled = true },
							propertyDeclarationTypes = { enabled = true },
							functionLikeReturnTypes = { enabled = true },
							enumMemberValues = { enabled = true },
						},
						referencesCodeLens = {
							enabled = true,
							showOnAllFunctions = true,
						},
						implementationsCodeLens = {
							enabled = true,
							showOnInterfaceMethods = true,
							showOnAllClassMethods = true,
						},
					},
				},
			},
			eslint = {
				settings = {
					validate = "on",
					run = "onType",
					workingDirectory = { mode = "auto" },
					format = false, -- prettierd via conform owns formatting
					quiet = false,
					onIgnoredFiles = "off",
					codeAction = {
						showDocumentation = { enable = true },
					},
				},
			},
			emmet_language_server = {
				init_options = {
					showSuggestionsAsSnippets = true,
				},
			},
		},
	},
}
