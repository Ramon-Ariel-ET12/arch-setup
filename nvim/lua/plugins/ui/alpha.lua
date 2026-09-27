return {
  "goolord/alpha-nvim",
  -- Must load eagerly: alpha has no self-starting plugin/ script, and a
  -- lazy-loaded config that runs *during* VimEnter cannot register another
  -- VimEnter autocmd for that same (already-dispatched) event.
  lazy = false,

  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    dashboard.section.header.val = {
      "███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
      "████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
      "██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
      "██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
      "██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
      "╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
      "                                                  ",
    }

    local function button(key, label, command)
      return dashboard.button(
        key,
        "  " .. key .. "  " .. label,
        command
      )
    end

    dashboard.section.buttons.val = {
      button("f", "Find file", "<cmd>FzfLua files<CR>"),
      button("r", "Recent files", "<cmd>FzfLua oldfiles<CR>"),
      button("g", "Find text", "<cmd>FzfLua live_grep<CR>"),
      button("b", "Buffers", "<cmd>FzfLua buffers<CR>"),
      button("t", "Terminal", "<cmd>ToggleTerm<CR>"),
      button("l", "Lazy plugins", "<cmd>Lazy<CR>"),
      button("e", "Explorer", "<cmd>Neotree toggle<CR>"),
      button("q", "Quit", "<cmd>qa<CR>"),
    }

    dashboard.section.footer.val = {
      "",
      " Code. Build. Repeat  ·  nvim 0.12 ",
    }

    dashboard.config.layout = {
      { type = "padding", val = 2 },
      dashboard.section.header,
      { type = "padding", val = 2 },
      dashboard.section.buttons,
      { type = "padding", val = 2 },
      dashboard.section.footer,
    }

    alpha.setup(dashboard.config)


    -- Hide statusline/tabline while the dashboard is open.
    local group = vim.api.nvim_create_augroup("alpha_chrome", { clear = true })
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "AlphaReady",
      callback = function()
        vim.g.alpha_statusline = vim.o.laststatus
        vim.g.alpha_tabline = vim.o.showtabline
        vim.o.laststatus = 0
        vim.o.showtabline = 0
        vim.b.minianimate_disable = true

        vim.keymap.set("n", "q", "<cmd>qa<cr>", { buffer = 0, silent = true, nowait = true })
      end,
    })
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "AlphaClosed",
      callback = function()
        vim.o.laststatus = vim.g.alpha_statusline or vim.o.laststatus
        vim.o.showtabline = vim.g.alpha_tabline or vim.o.showtabline
        vim.keymap.del("n", "q", { buffer = 0 })
      end,
    })

    -- No manual start needed: alpha.setup() registers its own VimEnter
    -- autostart (opts.autostart = true), which skips file args, stdin,
    -- non-empty buffers and scripting sessions via should_skip_alpha().
    -- This works because the plugin loads eagerly, BEFORE VimEnter.

    -- Detecting [No Name]: per :h bufname() it returns the :ls name but
    -- "not using special names such as [No Name]" -- so an empty bufname()
    -- IS the documented [No Name] test. There is no option or API holding
    -- the literal string; :h :ls defines it as "no file name specified".
    -- Each guard below excludes a real class: alpha (recursion), unlisted
    -- (alpha's own scratch buffer is still unnamed while nvim_win_set_buf
    -- dispatches BufEnter), non-empty buftype (help/terminal/prompt),
    -- filetyped scratch buffers, modified (undo history), non-empty.
    local function is_reclaimable(buf)
      if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
        return false
      end
      if vim.bo[buf].filetype == "alpha" or not vim.bo[buf].buflisted then
        return false
      end
      if vim.bo[buf].buftype ~= "" or vim.bo[buf].filetype ~= "" then
        return false
      end
      if vim.fn.bufname(buf) ~= "" or vim.bo[buf].modified then
        return false
      end
      -- Single read, mirroring alpha's own should_skip_alpha(): an empty
      -- buffer is exactly one empty line.
      local lines = vim.api.nvim_buf_get_lines(buf, 0, 2, false)
      return #lines <= 1 and (lines[1] == "" or lines[1] == nil)
    end

    local function reclaim(buf)
      buf = buf or vim.api.nvim_get_current_buf()
      if not is_reclaimable(buf) then
        return false
      end
      -- Skip floating windows (pickers, hovers).
      local win = vim.api.nvim_get_current_win()
      local cfg = vim.api.nvim_win_get_config(win)
      if cfg.relative ~= "" then
        return false
      end
      require("alpha").start(false)
      if vim.api.nvim_buf_is_valid(buf) and buf ~= vim.api.nvim_get_current_buf() then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
      return true
    end

    -- Bare launch (also covers the case alpha's own autostart missed):
    -- autostart uses start(true) which reuses the buffer; ours uses
    -- start(false) + wipe, so guard with is_reclaimable to stay idempotent.
    vim.api.nvim_create_autocmd("VimEnter", {
      group = group,
      callback = function()
        if vim.fn.argc() ~= 0 then
          return
        end
        reclaim(vim.api.nvim_get_current_buf())
      end,
    })

    -- :enew / <leader>bd fallback / last-buffer delete lands on an empty
    -- [No Name] buffer. Schedule to avoid re-entering while
    -- nvim_win_set_buf inside alpha.start is still dispatching BufEnter
    -- for the fresh (still-unnamed) scratch buffer.
    vim.api.nvim_create_autocmd("BufEnter", {
      group = group,
      callback = function(ev)
        if is_reclaimable(ev.buf) then
          local buf = ev.buf
          vim.schedule(function()
            reclaim(buf)
          end)
        end
      end,
    })

    -- Manual :Alpha from an empty buffer should replace it, not leak it.
    pcall(vim.api.nvim_del_user_command, "Alpha")
    vim.api.nvim_create_user_command("Alpha", function()
      if not reclaim(vim.api.nvim_get_current_buf()) then
        require("alpha").start(false)
      end
    end, { bang = true, desc = "Alpha (replaces empty buffer)", nargs = 0, bar = true })

    -- Must run AFTER the AlphaReady autocmds above are registered.
    -- `nvim .` (or any single directory argument): treat like a bare launch.
    -- Netrw is disabled, so a dir arg otherwise just leaves an empty,
    -- pointlessly-named buffer. Drop the arglist, unname the buffer, chdir
    -- into the target, then start normally (pickers/explorer land there).
    if vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
      local dir = vim.fn.fnameescape(vim.fn.fnamemodify(vim.fn.argv(0), ":p"))
      vim.cmd("%argdel")
      vim.cmd("0file")
      vim.cmd("cd " .. dir)
      require("alpha").start(true)
    end
  end,
}
