return {
  "pwntester/octo.nvim",
  cmd = "Octo",
  keys = {
    { "<leader>oi", "<cmd>Octo issue list<CR>", desc = "Gh: issues" },
    { "<leader>op", "<cmd>Octo pr list<CR>", desc = "Gh: PRs" },
    { "<leader>or", "<cmd>Octo repo<CR>", desc = "Gh: repos" },
    { "<leader>os", "<cmd>Octo search<CR>", desc = "Gh: search" },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "ibhagwan/fzf-lua",
  },
  opts = {
    default_remote = { "" },
    picker = "fzf-lua",
    use_local_fs = true,
    file_panel = {
      size = 15,
      keymaps = {
        ["g"] = "",
      },
    },
    enable_builtin = true, -- show buffer/obsecious warnings
    suppress_missing_scope = { projects_v2 = true },
    mapping = {},
  },
  config = function(_, opts)
    require("octo").setup(opts)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "octo" },
      callback = function()
        vim.opt_local.bufhidden = "wipe"
        vim.keymap.set("n", "q", "<cmd>bd<CR>", { buffer = true, silent = true, nowait = true })
      end,
    })
  end,
}