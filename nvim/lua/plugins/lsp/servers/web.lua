-- Settings for the vscode-extracted servers, per their service sources:
-- html `settings.html.format` (+ css/javascript facets, since the html
-- server co-hosts embedded languages) from
-- https://github.com/microsoft/vscode/blob/main/extensions/html-language-features/server/src/htmlServer.ts
-- with HTMLFormatConfiguration keys from
-- https://github.com/microsoft/vscode-html-languageservice/blob/main/src/htmlLanguageTypes.ts
-- (`wrapAttributes` accepts 'force-aligned', which lines every attribute
-- up under the first one).
-- json `settings.json` from
-- https://github.com/microsoft/vscode/blob/main/extensions/json-language-features/server/src/jsonServer.ts
-- with severity knobs from
-- https://github.com/microsoft/vscode-json-languageservice/blob/main/src/jsonLanguageTypes.ts
-- (`comments`/`trailingCommas` severity; jsonls defaults jsonc to ignore).
-- css/scss/less `settings.<lang>` LanguageSettings from
-- https://github.com/microsoft/vscode/blob/main/extensions/css-language-features/server/src/cssServer.ts
-- (`validate`, `lint`, `completion`, `hover`).
-- Formatting stays with prettierd via conform, so the server formatters
-- are off everywhere.
return {
	"neovim/nvim-lspconfig",
	opts = {
		servers = {
			html = {
				settings = {
					html = {
						format = {
							enable = false,
							wrapAttributes = "force-aligned",
							wrapLineLength = 120,
							preserveNewLines = true,
							maxPreserveNewLines = 2,
							endWithNewline = true,
						},
						hover = { documentation = true, references = true },
						completion = { hideEndTagSuggestions = false },
					},
					css = { validate = true },
					javascript = { validate = true },
				},
			},
			jsonls = {
				settings = {
					json = {
						format = { enable = false },
						validate = {
							enable = true,
							-- jsonc tolerates // comments; uncomment to flag
							-- them instead (levels: 'error' | 'warning' | 'ignore')
							-- comments = "error",
						},
						schemas = {},
					},
				},
			},
			cssls = {
				settings = {
					css = {
						validate = true,
						lint = { unknownAtRules = "ignore" },
						completion = {
							triggerPropertyValueCompletion = true,
							completePropertyWithSemicolon = true,
						},
						hover = { documentation = true, references = true },
					},
					scss = {
						validate = true,
						lint = { unknownAtRules = "ignore" },
						completion = {
							triggerPropertyValueCompletion = true,
							completePropertyWithSemicolon = true,
						},
						hover = { documentation = true, references = true },
					},
					less = { validate = true },
				},
			},
		},
	},
}
