local constants = require("constants")

-- rg honors .gitignore only inside git repos by default (--no-config skips
-- the user's rg rc); force it everywhere and skip the same dirs as the pickers.
local rg_exclude_opts = { "--no-require-git" }
for _, glob in ipairs(constants.rg_exclude_globs()) do
	rg_exclude_opts[#rg_exclude_opts + 1] = "-g"
	rg_exclude_opts[#rg_exclude_opts + 1] = glob
end

return {
	"saghen/blink.cmp",

	lazy = false,
	priority = 990,

	dependencies = {
		"saghen/blink.lib",

		{
			"rafamadriz/friendly-snippets",
		},

		{
			"mikavilpas/blink-ripgrep.nvim",
			version = "*",
		},
	},

	build = function()
		require("blink.cmp").build():pwait()
	end,

	opts = {
		-- ------------------------------------------------------------------
		-- Appearance
		-- ------------------------------------------------------------------
		appearance = {
			use_nvim_cmp_as_default = true, --
			nerd_font_variant = "mono",
		},

		-- ------------------------------------------------------------------
		-- Keymap
		-- ------------------------------------------------------------------
		keymap = {
			preset = "super-tab",
			-- Optional
			-- ["<Tab>"] = {
			--   function(cmp)
			--     if cmp.snippet_active() then
			--       return cmp.accept()
			--     else
			--       return cmp.select_and_accept()
			--     end
			--   end,
			--   "snippet_forward",
			--   "fallback",
			-- },
		},

		-- ------------------------------------------------------------------
		-- Fuzzy (Rust) —
		-- ------------------------------------------------------------------
		fuzzy = {
			implementation = "rust", -- forces rust

			-- Typo resistance (only Rust)
			max_typos = function(keyword)
				return math.floor(#keyword / 4) --
				-- return 0                    --
			end,

			-- Advanced Scoring
			use_proximity = true,

			-- Orden de sorting
			sorts = {
				"exact",
				"score",
				"sort_text",
				-- "label",
			},
		},

		-- ------------------------------------------------------------------
		-- Completion
		-- ------------------------------------------------------------------
		completion = {
			-- Keyword matching
			keyword = {
				range = "full", --
			},

			list = {
				selection = {
					preselect = true,
					auto_insert = false, --
				},
			},

			menu = {
				auto_show = true,
				border = constants.BORDER,
				-- max_height = 12, --

				draw = {
					columns = {
						{ "kind_icon" },
						{ "label", "label_description", gap = 1 },
						{ "kind", gap = 1 },
					},
				},
			},

			documentation = {
				auto_show = true,
				auto_show_delay_ms = 200, --
				window = {
					border = constants.BORDER,
				},
			},

			ghost_text = {
				enabled = true,
			},

			-- Auto brackets
			accept = {
				auto_brackets = {
					enabled = true,
				},
			},
		},

		-- ------------------------------------------------------------------
		-- Signature help (experimental but very util)
		-- ------------------------------------------------------------------
		signature = {
			enabled = true,
			window = {
				border = constants.BORDER,
				-- show_documentation = false, --
			},
		},

		-- ------------------------------------------------------------------
		-- Sources
		-- ------------------------------------------------------------------
		sources = {
			default = {
				"lsp",
				"path",
				"snippets",
				"buffer",
				"ripgrep",
			},

			--
			-- per_filetype = {
			--   lua = { inherit_defaults = true, "lazydev" }, -- ejemplo
			-- },

			providers = {
				-- Path:
				path = {
					opts = {
						get_cwd = function(context)
							return vim.fn.expand("#" .. context.bufnr .. ":p:h")
						end,
					},
				},

				-- Buffer:
				buffer = {
					opts = {
						get_bufnrs = function()
							local bufs = {}
							for _, win in ipairs(vim.api.nvim_list_wins()) do
								local buf = vim.api.nvim_win_get_buf(win)
								if vim.bo[buf].buflisted and vim.bo[buf].buftype == "" then
									bufs[buf] = true
								end
							end
							return vim.tbl_keys(bufs)
						end,
					},
				},

				-- Ripgrep
				ripgrep = {
					module = "blink-ripgrep",
					name = "Ripgrep",
					score_offset = -3,
					opts = {
						prefix_min_len = 3,
						context_size = 5,
						max_filesize = "1M",
						project_root_marker = { ".git", ".root", "package.json", "Cargo.toml", "go.mod" },
						search_mode = "fuzzy",
						fallback_to_buffers_matching = true,
						additional_rg_options = rg_exclude_opts,
					},
				},

				-- LSP: transformation example  (optional)
				-- lsp = {
				--   transform_items = function(_, items)
				--     return vim.tbl_filter(function(item)
				--       return item.kind ~= require("blink.cmp.types").CompletionItemKind.Keyword
				--     end, items)
				--   end,
				-- },
			},
		},

		-- ------------------------------------------------------------------
		-- Snippets
		-- ------------------------------------------------------------------
		snippets = {
			preset = "default", -- vim.snippet + friendly-snippets
		},

		-- ------------------------------------------------------------------
		-- Cmdline
		-- ------------------------------------------------------------------
		cmdline = {
			enabled = true,
			keymap = {
				preset = "cmdline",
			},
			completion = {
				menu = { auto_show = true },
				ghost_text = { enabled = false },
			},
			sources = {
				default = function()
					local type = vim.fn.getcmdtype()
					if type == "/" or type == "?" then
						return { "buffer" }
					elseif type == ":" or type == "@" then
						return { "cmdline", "path" }
					end
					return {}
				end,
			},
		},

		-- ------------------------------------------------------------------
		-- Terminal (0.11+/0.12, still in experimental)
		-- ------------------------------------------------------------------
		-- term = {
		--   enabled = true,
		--   keymap = { preset = "inherit" },
		--   sources = {},
		-- },
	},

	opts_extend = { "sources.default" },
}
