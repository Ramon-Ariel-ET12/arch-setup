return {
	"kndndrj/nvim-dbee",
	build = function()
		require("dbee").install()
	end,
	dependencies = {
		"MunifTanjim/nui.nvim",
	},
	cmd = { "Dbee", "DbeeReload", "DbeeSchema" },
	keys = { { "<leader>do", "<cmd>Dbee<CR>", desc = "Toggle DB explorer" } },
	-- Drivers (from dbee's adapters registry): postgres, mysql (covers
	-- mariadb), sqlite, sqlserver. Connections come from the env/file
	-- sources below; use {{ env `VAR` }} templates for secrets.
	-- setup() runs in `config` (not `opts`) because dbee.sources is only
	-- requireable once the plugin is on the rtp.
	config = function()
		require("dbee").setup({
			sources = {
				require("dbee.sources").EnvSource:new("DBEE_CONNECTIONS"),
				require("dbee.sources").FileSource:new(vim.fn.stdpath("state") .. "/dbee/persistence.json"),
			},
		})
	end,
}