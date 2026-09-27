local constants = require("constants")

-- mason.nvim v2 has no builtin ensure_installed option; everything listed in
-- constants (LSP packages + MASON_TOOLS) gets installed on startup.
local ensure_installed = vim.iter(constants.LSP_TOOLCHAIN)
	:filter(function(lsp)
		return lsp.mason
	end)
	:map(function(lsp)
		return lsp.mason
	end)
	:totable()
vim.list_extend(ensure_installed, constants.MASON_TOOLS)

return {
	"mason-org/mason.nvim",
	-- Mason must be set up at startup: setup() prepends bin/ to PATH so every
	-- server in constants.LSP_TOOLCHAIN resolves. Lazy-loading it is not
	-- recommended (see :h mason-quickstart).
	lazy = false,
	priority = 950, -- load before first LSP attach
	keys = {
		{ "<leader>pm", "<cmd>Mason<CR>", desc = "Mason (packages)" },
	},
	opts = {
		registries = {
			"github:mason-org/mason-registry",
			-- Recommended by roslyn.nvim: tracks the roslyn build shipped in
			-- vscode and provides the `roslyn` package (see M.MASON_TOOLS).
			"github:Crashdummyy/mason-registry",
		},
		ui = {
			border = constants.BORDER,
			icons = {
				package_installed = "✓",
				package_pending = "➜",
				package_uninstalled = "✗",
			},
		},
	},
	config = function(_, opts)
		require("mason").setup(opts)

		-- Install the toolchain declared in constants in the background via
		-- the Lua API (see :h mason-registry).
		local ok, registry = pcall(require, "mason-registry")
		if not ok then
			return
		end
		registry.refresh(function()
			for _, name in ipairs(ensure_installed) do
				if registry.has_package(name) then
					local pkg = registry.get_package(name)
					if pkg and not pkg:is_installed() then
						pkg:install()
					end
				else
					vim.notify(("mason: unknown package %q"):format(name), vim.log.levels.WARN)
				end
			end
		end)
	end,
}
