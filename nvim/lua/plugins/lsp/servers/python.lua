-- pyright settings per https://microsoft.github.io/pyright (settings.md):
-- openFilesOnly analysis, venv auto-detection; ruff is the linter here so
-- organize-imports is disabled on pyright and left to ruff's
-- source.organizeImports action (see
-- https://docs.astral.sh/ruff/editors/settings/#organizeimports).
return {
	"neovim/nvim-lspconfig",
	opts = {
		servers = {
			pyright = {
				settings = {
					python = {
						analysis = {
							typeCheckingMode = "standard",
							autoSearchPaths = true,
							useLibraryCodeForTypes = true,
							diagnosticMode = "openFilesOnly",
						},
					},
				},
			},
			ruff = {
				init_options = {
					settings = {
						organizeImports = true,
						fixAll = true,
						configurationPreference = "filesystemFirst",
					},
				},
			},
		},
	},
}
