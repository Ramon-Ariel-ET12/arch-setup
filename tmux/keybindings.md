# tmux Keybindings Reference

> **Prefix:** `C-a` (`C-b` kept as alias). Reload config: `prefix + r`.
> Source of truth: [`tmux.conf`](./tmux.conf).

## Sessions & Windows

| Key | Action | Description |
|-----|--------|-------------|
| `prefix + s` | `command-prompt` → `new-session -A -s` | Attach or create a session |
| `prefix + C` | `command-prompt` → `new-session -A -s -c` | Same, in the current directory |
| `prefix + d` | `detach-client` | Detach |
| `prefix + X` | `kill-server` | Kill every session |
| `prefix + c` | `new-window -c "#{pane_current_path}"` | New window in current directory |
| `prefix + n` | `next-window` | Next window |
| `prefix + p` | `previous-window` | Previous window |
| `prefix + 1..9` | `select-window -t :=N` | Jump to window by index (bound individually) |
| `prefix + 0` | `select-window -t :=10` | Window 10 |
| `prefix + w` | `choose-tree -Zs` | Session/window/pane tree |
| `prefix + W` | `switch-client -l` | Previous client |
| `prefix + {` | `swap-window -t -1` | Swap window with previous |
| `prefix + }` | `swap-window -t +1` | Swap window with next |
| `prefix + ,` | `command-prompt -I "#W"` | Rename window (prompt seeded with current name) |
| `prefix + R` | `command-prompt -I "#S"` | Rename session |
| `prefix + &` | `command-prompt -I "#S"` | Rename session (same as `R`) |

## Panes

| Key | Action | Description |
|-----|--------|-------------|
| `prefix + \|` | `split-window -h` | Split side by side |
| `prefix + -` | `split-window -v` | Split stacked |
| `prefix + h/j/k/l` | `select-pane -L/-D/-U/-R` | vim-style movement |
| `prefix + H/J/K/L` | `resize-pane -L/-D/-U/-R 5` | Resize (repeatable) |
| `prefix + C-Arrow` | `resize-pane` | Fine resize (2 cells) |
| `prefix + z` | `resize-pane -Z` | Toggle zoom on the active pane |
| `prefix + Tab` | `last-pane` | Back to previous pane |
| `prefix + q` | `display-panes -d 1200` | Show big pane numbers briefly |
| `prefix + x` | `kill-pane` | Close pane |
| `prefix + Q` | `kill-pane -t :.` | Close pane with confirmation |

## Layouts

| Key | Layout |
|-----|--------|
| `prefix + Space` | Next layout |
| `prefix + b` | `even-horizontal` |
| `prefix + v` | `even-vertical` |
| `prefix + m` | `main-horizontal` |
| `prefix + M` | `main-vertical` |
| `prefix + i` | `main-horizontal-mirrored` |
| `prefix + o` | `main-vertical-mirrored` |
| `prefix + t` | `tiled` |

## Copy Mode (vi keys)

Enter with `prefix + [`.

| Key | Action | Description |
|-----|--------|-------------|
| `v` | `begin-selection` | Start selection |
| `V` | `rectangle-toggle` | Rectangle selection |
| `y` | `copy-pipe-and-cancel "wl-copy"` | Copy to Wayland clipboard and exit |
| `Y` | `copy-pipe "wl-copy"` | Copy, stay in copy mode |
| `C-e` | `copy-selection-and-cancel` | Copy with tmux's own buffer |
| `Escape` / `q` | `cancel` | Leave copy mode |
| `c` | `clear-selection` | Clear selection |
| `g` / `G` | `history-top` / `history-bottom` | Jump to ends |
| `H` / `M` | `goto-top` / `goto-bottom` | Screen top/bottom |
| `PPage` / `NPage` | `page-up` / `page-down` | Page scroll |
| `C-Up` / `C-Down` | `scroll-up 3` / `scroll-down 3` | Fast scroll |
| `^` | `send -X -N 1` | Scroll up one line |
| `/` | `begin-search` | Forward search |
| `?` | `search-backward` | Backward search |
| `n` / `N` | `search-next` / `search-previous` | Repeat search |

## Buffers & Popups

| Key | Action | Description |
|-----|--------|-------------|
| `prefix + ]` | `paste-buffer -d` | Paste newest buffer, then delete it |
| `prefix + P` | `display-popup` | Show `tmux list-buffers` in a rounded popup |
| `prefix + r` | `source-file` | Reload `tmux.conf` without restarting |

## Options Worth Knowing

| Option | Value | Why |
|--------|-------|-----|
| `base-index` / `pane-base-index` | `1` | Windows and panes start counting at 1 |
| `renumber-windows` | `on` | No gaps after closing a window |
| `mode-keys` / `status-keys` | `vi` | vim bindings in copy mode and the status prompt |
| `set-clipboard` | `external` | Copy over OSC 52 without apps clobbering tmux buffers |
| `pane-scrollbars` | `modal` | Scrollbar only in copy mode, no width stolen otherwise |
| `history-limit` | `100000` | Deep scrollback |
| `default-terminal` | `tmux-256color` | Truecolor inside tmux on kitty |
| `prefix2` | `C-b` | Second prefix, for the tmux default habit |
| `pane-border-lines` | `rounded` on tmux ≥ 3.8 | Version-gated in the config; falls back to `single` on 3.7 |

## tmux Version Notes

Rounded **pane** borders landed in tmux 3.8. On 3.7 `pane-border-lines` only
accepts `single`, `double`, `heavy`, `simple`, `number`, `spaces`, so
`tmux.conf` tests `#{version}` and picks `rounded` when available. Popups
(`popup-border-lines`) support `rounded` on both versions.

`resize-pane` has no `-z` flag, and `rename-window` / `rename-session` require a
name argument — hence the `command-prompt` wrappers and the single `z` zoom key.