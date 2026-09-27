local constants = require("constants")

return {
  "lewis6991/gitsigns.nvim",

  event = "VeryLazy",

  opts = {
    -- ╭──────────────────────────────────────────────────────────╮
    -- │ Signs                                                       │
    -- ╰──────────────────────────────────────────────────────────╯

    signs = {
      add = {
        text = "│",
      },

      change = {
        text = "│",
      },

      delete = {
        text = "_",
      },

      topdelete = {
        text = "‾",
      },

      changedelete = {
        text = "~",
      },

      untracked = {
        text = "┆",
      },
    },

    -- Show separate signs for staged changes.
    signs_staged_enable = true,

    signs_staged = {
      add = {
        text = "│",
      },

      change = {
        text = "│",
      },

      delete = {
        text = "_",
      },

      topdelete = {
        text = "‾",
      },

      changedelete = {
        text = "~",
      },

      untracked = {
        text = "┆",
      },
    },

    signcolumn = true,

    -- Keep line/number highlighting off.
    numhl = false,
    linehl = false,

    -- I prefer this off by default.
    -- Toggle it when needed with <leader>tw.
    word_diff = false,

    -- ╭──────────────────────────────────────────────────────────╮
    -- │ Git directory                                               │
    -- ╰──────────────────────────────────────────────────────────╯

    watch_gitdir = {
      follow_files = true,
    },

    auto_attach = true,

    -- Don't attach to untracked files until they're tracked.
    attach_to_untracked = false,

    -- ╭──────────────────────────────────────────────────────────╮
    -- │ Blame                                                       │
    -- ╰──────────────────────────────────────────────────────────╯

    current_line_blame = true,

    current_line_blame_opts = {
      virt_text = false,

      virt_text_pos = "eol",

      delay = 500,

      ignore_whitespace = false,

      virt_text_priority = 100,

      use_focus = true,
    },

    current_line_blame_formatter =
      " 󰊢 <author> • <author_time:%R> • <summary>",

    -- ╭──────────────────────────────────────────────────────────╮
    -- │ Updates                                                     │
    -- ╰──────────────────────────────────────────────────────────╯

    update_debounce = 100,

    -- Don't process enormous generated files.
    max_file_length = 40000,

    -- ╭──────────────────────────────────────────────────────────╮
    -- │ Signs priority                                               │
    -- ╰──────────────────────────────────────────────────────────╯

    sign_priority = 6,

    -- ╭──────────────────────────────────────────────────────────╮
    -- │ Preview                                                      │
    -- ╰──────────────────────────────────────────────────────────╯

    preview_config = {
      style = "minimal",

      relative = "cursor",

      row = 0,
      col = 1,

      border = constants.BORDER,
    },

    -- ╭──────────────────────────────────────────────────────────╮
    -- │ Keymaps                                                      │
    -- ╰──────────────────────────────────────────────────────────╯

    on_attach = function(bufnr)
      local gs = require("gitsigns")

      local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, {
          buffer = bufnr,
          desc = desc,
          silent = true,
        })
      end

      -- ─────────────────────────────────────────────────────────
      -- Navigation
      -- ─────────────────────────────────────────────────────────

      map("n", "]c", function()
        if vim.wo.diff then
          vim.cmd.normal({ "]c", bang = true })
        else
          gs.nav_hunk("next")
        end
      end, "Next Git Hunk")

      map("n", "[c", function()
        if vim.wo.diff then
          vim.cmd.normal({ "[c", bang = true })
        else
          gs.nav_hunk("prev")
        end
      end, "Previous Git Hunk")

      -- ─────────────────────────────────────────────────────────
      -- Hunk actions
      -- ─────────────────────────────────────────────────────────

      map("n", "<leader>hs", gs.stage_hunk, "Stage Hunk")

      map("n", "<leader>hr", gs.reset_hunk, "Reset Hunk")

      map("v", "<leader>hs", function()
        gs.stage_hunk({
          vim.fn.line("."),
          vim.fn.line("v"),
        })
      end, "Stage Selected Hunk")

      map("v", "<leader>hr", function()
        gs.reset_hunk({
          vim.fn.line("."),
          vim.fn.line("v"),
        })
      end, "Reset Selected Hunk")

      map("n", "<leader>hS", gs.stage_buffer, "Stage Buffer")

      map("n", "<leader>hR", gs.reset_buffer, "Reset Buffer")

      -- ─────────────────────────────────────────────────────────
      -- Preview / diff
      -- ─────────────────────────────────────────────────────────

      map("n", "<leader>hp", gs.preview_hunk, "Preview Hunk")

      map("n", "<leader>hi", gs.preview_hunk_inline, "Preview Hunk Inline")

      map("n", "<leader>hd", gs.diffthis, "Diff Buffer")

      map("n", "<leader>hD", function()
        gs.diffthis("~")
      end, "Diff Against HEAD~")

      -- ─────────────────────────────────────────────────────────
      -- Blame
      -- ─────────────────────────────────────────────────────────

      map("n", "<leader>hb", function()
        gs.blame_line({
          full = true,
        })
      end, "Blame Line")

      map("n", "<leader>hB", gs.blame, "Blame Buffer")

      -- ─────────────────────────────────────────────────────────
      -- Toggles (under the UI Toggles group)
      -- ─────────────────────────────────────────────────────────

      map(
        "n",
        "<leader>ub",
        gs.toggle_current_line_blame,
        "Toggle Git Blame"
      )

      map(
        "n",
        "<leader>uw",
        gs.toggle_word_diff,
        "Toggle Word Diff"
      )

      map(
        "n",
        "<leader>us",
        gs.toggle_signs,
        "Toggle Git Signs"
      )

      -- ─────────────────────────────────────────────────────────
      -- Quickfix / location list
      -- ─────────────────────────────────────────────────────────

      map("n", "<leader>hq", gs.setqflist, "Hunks → Quickfix")

      map("n", "<leader>hQ", function()
        gs.setqflist("all")
      end, "All Hunks → Quickfix")

      map("n", "<leader>hl", gs.setloclist, "Hunks → Location List")

      map("n", "<leader>hL", function()
        gs.setloclist("all")
      end, "All Hunks → Location List")

      -- ─────────────────────────────────────────────────────────
      -- Hunk text object
      -- ─────────────────────────────────────────────────────────

      vim.keymap.set(
        { "o", "x" },
        "ih",
        gs.select_hunk,
        {
          buffer = bufnr,
          desc = "Git Hunk",
          silent = true,
        }
      )
    end,
  },
}
