local opt = vim.opt
local g = vim.g
local o = vim.o
local constants = require("constants")

----------------------------------------------------------------------
-- Leaders (set these as early as possible, ideally in init.lua)
----------------------------------------------------------------------
-- g.mapleader = " "
-- g.maplocalleader = "\\"

----------------------------------------------------------------------
-- Core UI
----------------------------------------------------------------------
opt.termguicolors = true
opt.background = "dark"

opt.number = true
opt.relativenumber = false          -- change to true if you prefer relative numbers
opt.numberwidth = 4
opt.signcolumn = "yes"              -- always show → no text jumping
opt.cursorline = true
opt.cursorlineopt = "number,line"   -- or just "number" for a cleaner look

opt.laststatus = 3                  -- global statusline
opt.showtabline = 2
opt.showmode = false                -- statusline plugins usually handle this
opt.cmdheight = 1

opt.winblend = 0
opt.pumblend = 10
opt.pumheight = 12
opt.pummaxwidth = 80                -- 0.12: prevent overly wide completion menus

-- 0.11+/0.12 modern borders (very recommended)
opt.winborder = constants.BORDER    -- default border for all floating windows
opt.pumborder = constants.BORDER    -- 0.12: border for the popup menu (completion)

----------------------------------------------------------------------
-- Indentation & wrapping
----------------------------------------------------------------------
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true
opt.breakindent = true              -- keep indent on wrapped lines
opt.wrap = false
opt.textwidth = 0
opt.linebreak = true                -- only matters if you enable wrap

----------------------------------------------------------------------
-- Search
----------------------------------------------------------------------
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true
opt.inccommand = "split"            -- live preview of :s (excellent)

----------------------------------------------------------------------
-- Editing behaviour
----------------------------------------------------------------------
opt.splitright = true
opt.splitbelow = true
opt.splitkeep = "screen"            -- keep view stable when splitting

opt.clipboard = "unnamedplus"
opt.mouse = "a"
opt.mousemodel = "extend"

opt.updatetime = 250
opt.timeoutlen = 400
opt.ttimeoutlen = 10

opt.swapfile = false
opt.writebackup = false
opt.backup = false
opt.undofile = true
opt.undolevels = 10000

opt.completeopt = { "menu", "menuone", "noselect", "noinsert" }
-- Optional 0.12 native auto-completion (experimental, try it):
-- opt.autocomplete = true

opt.virtualedit = "block"
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.smoothscroll = true

----------------------------------------------------------------------
-- Folds (Treesitter – recommended)
----------------------------------------------------------------------
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldtext = ""
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldnestmax = 3
opt.foldcolumn = "0"                -- set to "1" if you want a fold indicator

----------------------------------------------------------------------
-- Appearance / whitespace
----------------------------------------------------------------------
opt.list = true
opt.listchars = {
  tab = "» ",
  trail = "·",
  nbsp = "␣",
  -- extends = "›",
  -- precedes = "‹",
  -- leadtab = "» ",               -- 0.12 new flag if you want it
}

opt.fillchars = {
  eob = " ",
  fold = " ",
  foldopen = "▾",
  foldclose = "▸",
  foldsep = " ",
  diff = "╱",
  -- foldinner = " ",              -- 0.12 new flag
}

opt.wildoptions = "pum"
opt.wildmode = "longest:full,full"
opt.whichwrap = "b,s,h,l,<,>,[,]"

----------------------------------------------------------------------
-- Diff (0.12 improved defaults)
----------------------------------------------------------------------
opt.diffopt = {
  "internal",
  "filler",
  "closeoff",
  "algorithm:histogram",
  "indent-heuristic",
  "linematch:60",
  "inline:char",                    -- 0.12 default improvement
}

----------------------------------------------------------------------
-- Spell / language
----------------------------------------------------------------------
opt.spelllang = { "en" }
opt.spell = false
opt.spelloptions = "camel"          -- nicer for code identifiers

----------------------------------------------------------------------
-- Files
----------------------------------------------------------------------
opt.fileformats = { "unix", "dos", "mac" }
opt.confirm = true                  -- ask to save instead of failing
opt.autoread = true

----------------------------------------------------------------------
-- Performance / misc
----------------------------------------------------------------------
opt.lazyredraw = false              -- keep false with modern UIs
opt.synmaxcol = 300                 -- don't highlight insanely long lines
opt.history = 1000

----------------------------------------------------------------------
-- Title
----------------------------------------------------------------------
o.title = true
-- o.titlestring = "%<%F%=%l/%L - nvim"

----------------------------------------------------------------------
-- Jump list behaviour (recommended)
----------------------------------------------------------------------
opt.jumpoptions = "stack"           -- jumplist behaves like a stack (very nice)

----------------------------------------------------------------------
-- Disable unused built-in plugins / providers
----------------------------------------------------------------------
g.loaded_netrw = 1
g.loaded_netrwPlugin = 1

g.loaded_python3_provider = 0
g.loaded_perl_provider = 0
g.loaded_ruby_provider = 0
-- g.loaded_node_provider = 0     -- keep if you still need the Node provider

----------------------------------------------------------------------
-- Snippets / other globals
----------------------------------------------------------------------
g.snips_author = "Ramon-Ariel-ET12"

----------------------------------------------------------------------
-- Optional modern extras
----------------------------------------------------------------------
-- opt.sessionoptions = "buffers,curdir,folds,help,tabpages,winsize,terminal"
