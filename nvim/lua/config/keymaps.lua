local constants = require("constants")
local map = vim.keymap.set

-- Better default behaviour
map("n", "x", '"_x', { desc = "Delete char without yanking" })
map("n", "X", '"_X', { desc = "Delete char before without yanking" })
map("x", "p", '"_dP', { desc = "Paste without overwriting register" })
map("x", "x", '"_x', { desc = "Delete selection without yanking" })

-- Keep selection when indenting
map("v", "<", "<gv", { desc = "Indent left, keep selection" })
map("v", ">", ">gv", { desc = "Indent right, keep selection" })

-- Move lines
map("n", "<A-j>", "<cmd>m .+1<CR>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<CR>==", { desc = "Move line up" })
map("i", "<A-j>", "<esc><cmd>m .+1<CR>==gi", { desc = "Move line down" })
map("i", "<A-k>", "<esc><cmd>m .-2<CR>==gi", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Duplicate lines
map("n", "<A-J>", "<cmd>copy .<CR>", { desc = "Duplicate line down" })
map("n", "<A-K>", "<cmd>copy -1<CR>", { desc = "Duplicate line up" })
map("i", "<A-J>", "<cmd>copy .<CR>", { desc = "Duplicate line down" })
map("i", "<A-K>", "<cmd>copy -1<CR>", { desc = "Duplicate line up" })
map("v", "<A-J>", ":<C-u>'<,'>copy '><CR>gv", { desc = "Duplicate selection down" })
map("v", "<A-K>", ":<C-u>'<,'>copy '<-1<CR>gv", { desc = "Duplicate selection up" })

-- No-op on Q, but keep Ex
map("n", "Q", "<nop>", { desc = "Disable Ex mode" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Window resize
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase width" })

-- Maximize / balance
map("n", "_", "<cmd>resize<CR>", { desc = "Maximize height" })
map("n", "|", "<cmd>vertical resize<CR>", { desc = "Maximize width" })
map("n", "=", "<cmd>wincmd =<CR>", { desc = "Balance windows" })

-- Splits
map("n", "<leader>ws", "<cmd>split<CR>", { desc = "Split horizontal" })
map("n", "<leader>wv", "<cmd>vsplit<CR>", { desc = "Split vertical" })
map("n", "<leader>wd", "<cmd>close<CR>", { desc = "Close window" })

-- Buffers (<S-h>/<S-l>, pick and pin live in the bufferline spec)

--- Delete a buffer without closing its window.
---@param force boolean discard unsaved changes
local function buffer_delete(force)
  local cur = vim.api.nvim_get_current_buf()
  local alt = vim.fn.bufnr("#")
  if alt == -1 or alt == cur then
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].buflisted and buf ~= cur then
        alt = buf
        break
      end
    end
  end

  if alt ~= -1 and alt ~= cur then
    vim.cmd.buffer(alt)
  else
    vim.cmd.enew()
  end

  local ok, err = pcall(vim.api.nvim_buf_delete, cur, { force = force })
  if not ok then
    vim.notify(err, vim.log.levels.WARN)
  end
end

--- Close every other listed buffer, keeping the focused one.
local function buffer_delete_others()
  local cur = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= cur and vim.bo[buf].buflisted and vim.bo[buf].buftype == "" then
      pcall(vim.api.nvim_buf_delete, buf, {})
    end
  end
end

map("n", "[b", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "]b", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bb", "<cmd>e #<CR>", { desc = "Switch to other buffer" })
map("n", "<leader>bd", function() buffer_delete(false) end, { desc = "Delete buffer" })
map("n", "<leader>bD", function() buffer_delete(true) end, { desc = "Delete buffer (force)" })
map("n", "<leader>bo", buffer_delete_others, { desc = "Delete other buffers" })

-- Discard every change in the focused buffer and reload from disk
map("n", "<S-U>", "<cmd>e!<CR>", { desc = "Reload file from disk" })

-- Fileformat picker
map("n", "<leader>bf", function()
  local formats = { "unix", "dos", "mac" }
  local current = vim.bo.fileformat
  local items = vim.tbl_map(function(f)
    return string.format("%s  %s (%s)", constants.FILEFORMAT_ICONS[f], f:upper(), f == current and "current" or "")
  end, formats)

  vim.ui.select(items, {
    prompt = "Fileformat: ",
    format_item = function(item) return item end,
  }, function(choice, idx)
    if idx then
      vim.bo.fileformat = formats[idx]
      vim.notify(string.format("Fileformat: %s %s", constants.FILEFORMAT_ICONS[formats[idx]], formats[idx]:upper()))
    end
  end)
end, { desc = "Change fileformat" })

-- Quickfix
map("n", "<leader>q", "<cmd>copen<CR>", { desc = "Open quickfix" })
map("n", "<leader>Q", "<cmd>cclose<CR>", { desc = "Close quickfix" })

-- Re-center search results
map("n", "n", "nzzzv", { desc = "Next match, centered" })
map("n", "N", "Nzzzv", { desc = "Prev match, centered" })
map("n", "*", "*zz", { desc = "Search word, centered" })

-- Keep cursor in place when joining
map("n", "J", "mzJ`z", { desc = "Join lines, stay" })

-- Tabs (frees <leader>t for Terminal)
map("n", "<leader><tab>o", "<cmd>tabnew<CR>", { desc = "New tab" })
map("n", "<leader><tab>n", "<cmd>tabnext<CR>", { desc = "Next tab" })
map("n", "<leader><tab>p", "<cmd>tabprev<CR>", { desc = "Prev tab" })
map("n", "<leader><tab>d", "<cmd>tabclose<CR>", { desc = "Close tab" })

-- Better :grep via fzf-lua lives in its own spec

-- Copy whole line (keeps something useful)
map({ "n", "x" }, "gy", '"+y', { desc = "Yank to system clipboard" })
map({ "n", "x" }, "gp", '"+p', { desc = "Paste from system clipboard" })

-- Toggle relative numbers quickly
map("n", "<leader>ur", function()
  vim.opt.relativenumber = not vim.opt.relativenumber:get()
end, { desc = "Toggle relative numbers" })

-- Highlight yank handled in autocmds

-- Navigation in insert/command via cursor keys alternative
map("i", "<C-b>", "<Left>", { desc = "Left in insert" })
map("i", "<C-f>", "<Right>", { desc = "Right in insert" })