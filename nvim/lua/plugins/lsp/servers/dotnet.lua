local utils = require("utils")

-- Search from wherever nvim was opened. Captured once so `:cd` inside nvim
-- doesn't silently change what these helpers look at.
local start_dir = vim.fn.getcwd()

---First .sln/.slnx found from the launch directory (Roslyn's default target).
---@return string?
local function first_solution()
	return utils.find_first({ path = start_dir, exts = { "sln", "slnx" } })
end

local solution = first_solution()

---Read the <UserSecretsId> from a .csproj.
---@param csproj string
---@return string?
local function user_secrets_id(csproj)
	local ok, content = pcall(function()
		return table.concat(vim.fn.readfile(csproj), "\n")
	end)
	if not ok then
		return nil
	end
	local id = content:match("<UserSecretsId>%s*(.-)%s*</UserSecretsId>")
	return (id and id ~= "") and id or nil
end

---Absolute path to an AppUserSecretsId's secrets.json.
---@param id string UserSecretsId
---@return string
local function secrets_json(id)
	local base = vim.fn.has("win32") == 1 and vim.fs.joinpath(vim.env.APPDATA, "Microsoft", "UserSecrets")
		or vim.fs.joinpath(vim.env.HOME, ".microsoft", "usersecrets")

	return vim.fs.joinpath(base, id, "secrets.json")
end

---@class RoslynSecretsApp
---@field name string csproj basename without extension
---@field path string absolute path to the .csproj
---@field json string absolute path to secrets.json

---Find app .csproj files that carry a <UserSecretsId>. Classlibs simply don't
---set UserSecretsId, so filtering on it is enough.
---@return RoslynSecretsApp[]
local function apps()
	local apps = {}
	-- Plugins may need every project, so ask for unlimited results.
	for _, csproj in ipairs(utils.find_all({ path = start_dir, exts = { "csproj" } })) do
		local id = user_secrets_id(csproj)
		if id then
			apps[#apps + 1] = {
				name = vim.fn.fnamemodify(csproj, ":t:r"),
				path = csproj,
				json = secrets_json(id),
			}
		end
	end
	return apps
end

---Open <app>'s secrets.json, creating the buffer if it doesn't exist yet.
---@param app RoslynSecretsApp
local function open_app(app)
	if vim.fn.filereadable(app.json) == 0 then
		vim.notify("secrets.json does not exist yet, will be created at:\n" .. app.json, vim.log.levels.INFO, {
			title = "RoslynSecrets",
		})
	end
	vim.cmd.edit(app.json)
end

---Open the secrets.json for `name` (nil = pick). Used by :RoslynSecrets.
---@param name? string
local function open_secrets(name)
	local found = apps()
	if #found == 0 then
		vim.notify("No .NET app with <UserSecretsId> found from " .. start_dir, vim.log.levels.WARN, {
			title = "RoslynSecrets",
		})
		return
	end

	if name then
		local app = vim.tbl_filter(function(a)
			return a.name == name
		end, found)[1]
		if not app then
			vim.notify(("No app named %s"):format(name), vim.log.levels.ERROR, { title = "RoslynSecrets" })
			return
		end
		open_app(app)
	elseif #found == 1 then
		open_app(found[1])
	else
		vim.ui.select(
			vim.tbl_map(function(a)
				return a.name
			end, found),
			{
				prompt = "Select app: ",
			},
			function(chosen)
				if chosen then
					open_app(vim.tbl_filter(function(a)
						return a.name == chosen
					end, found)[1])
				end
			end
		)
	end
end

return {
	"seblyng/roslyn.nvim",
	ft = { "cs", "razor", "cshtml" },

	dependencies = {
		"neovim/nvim-lspconfig",
	},

	-- Runs before roslyn.nvim's plugin/ file calls vim.lsp.enable("roslyn"),
	-- so the very first root_dir evaluation already sees our target instead of
	-- racing ahead of `opts` and starting a second, workspace-less server.
	init = function()
		if solution then
			vim.g.roslyn_nvim_selected_solution = solution
		end

		vim.lsp.config("roslyn", {
			root_dir = function(bufnr, on_dir)
				local target = require("roslyn.target")
				local decision = target.resolve(bufnr)
				target.notify_if_needed(decision)
				target.remember(decision)

				-- Ambiguous/undiscovered targets used to reach on_dir(nil), which
				-- starts a roslyn client without a workspace (the duplicate-server
				-- lag culprit). Fall back to the pinned solution, else don't attach.
				local root = decision.root_dir or (solution and vim.fs.dirname(solution))
				if not root then
					return
				end
				on_dir(root)
			end,

			on_attach = function(client)
				-- Roslyn's semantic tokens crash near EOF and retry per keystroke
				-- (see lsp.log); treesitter already highlights cs/razor/cshtml.
				client.server_capabilities.semanticTokenProvider = nil

				-- Roslyn answers textDocument/diagnostic pulls with vim.NIL,
				-- which nvim 0.12's handler indexes and crashes on (the razor
				-- format-on-save freeze). Swallow the null before it gets there.
				local pull = vim.lsp.handlers[vim.lsp.protocol.Methods.textDocument_diagnostic]
				client.handlers[vim.lsp.protocol.Methods.textDocument_diagnostic] = function(err, result, ctx, config)
					if result == vim.NIL then
						return
					end
					if type(result) == "table" and type(result.items) == "table" then
						result.items = vim.tbl_filter(function(diagnostic)
							return type(diagnostic) == "table" and diagnostic.range ~= vim.NIL
						end, result.items)
					end
					return pull(err, result, ctx, config)
				end
			end,
		})
	end,

	opts = {
		-- Documented escape hatch ("can be used if you notice performance issues"):
		-- Roslyn's in-process watcher fallback caused solution reload loops.
		filewatching = "off",

		-- Avoid searching the entire filesystem for solutions.
		broad_search = false,

		-- Always attach to vim.g.roslyn_nvim_selected_solution (primed in init
		-- with the first solution from the launch directory).
		lock_target = true,
	},

	config = function(_, opts)
		-- Pin Roslyn's default target to the first solution found. The plugin's
		-- own discovery still runs; `choose_target` just settles the winner.
		opts.choose_target = function(targets)
			if solution then
				local want = vim.fs.normalize(solution):lower()
				for _, t in ipairs(targets) do
					if vim.fs.normalize(t):lower() == want then
						return t
					end
				end
			end
			return targets[1]
		end

		-- `:RoslynSecrets [app]` — open the matching app's secrets.json.
		vim.api.nvim_create_user_command("RoslynSecrets", function(args)
			open_secrets(args.args ~= "" and args.args or nil)
		end, {
			nargs = "?",
			desc = "Open secrets.json for a .NET app (from <UserSecretsId>)",
			complete = function()
				return vim.tbl_map(function(a)
					return a.name
				end, apps())
			end,
		})

		vim.lsp.config("roslyn", {
			settings = {
				["csharp|background_analysis"] = {
					-- fullSolution re-analyzes every file in the solution on edits
					-- and pushes diagnostics while typing; openFiles keeps it local.
					dotnet_compiler_diagnostics_scope = "openFiles",
					dotnet_analyzer_diagnostics_scope = "openFiles",
				},

				["csharp|completion"] = {
					dotnet_show_completion_items_from_unimported_namespaces = false,
					dotnet_show_name_completion_suggestions = false,
					dotnet_provide_regex_completions = false,
				},

				["csharp|inlay_hints"] = {
					csharp_enable_inlay_hints_for_implicit_object_creation = true,
					csharp_enable_inlay_hints_for_implicit_variable_types = true,
					csharp_enable_inlay_hints_for_lambda_parameter_types = true,
					csharp_enable_inlay_hints_for_types = true,

					dotnet_enable_inlay_hints_for_indexer_parameters = true,
					dotnet_enable_inlay_hints_for_literal_parameters = false,
					dotnet_enable_inlay_hints_for_object_creation_parameters = true,
					dotnet_enable_inlay_hints_for_other_parameters = false,
					dotnet_enable_inlay_hints_for_parameters = true,

					dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
					dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
					dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
				},

				["csharp|symbol_search"] = {
					dotnet_search_reference_assemblies = true,
				},

				["csharp|formatting"] = {
					dotnet_organize_imports_on_format = true,
				},

				["csharp|code_lens"] = {
					dotnet_enable_references_code_lens = false,
					dotnet_enable_tests_code_lens = false,
				},
			},
		})

		require("roslyn").setup(opts)
	end,
}
