# Kitty Keybindings Reference

> **Modifier:** `kitty_mod` = `ctrl+shift` (Linux), `cmd` (macOS)

## Clipboard

| Key | Action | Description |
|-----|--------|-------------|
| `ctrl+shift+c` | `copy_to clipboard` | Copy selection to clipboard |
| `ctrl+shift+v` | `paste_from_clipboard` | Paste from clipboard |
| `ctrl+shift+s` | `paste_from_selection` | Paste from primary selection |
| `shift+insert` | `paste_from_selection` | Paste from primary selection |
| `ctrl+shift+o` | `pass_selection_to_program` | Send selection to external program |

## Scrolling

| Key | Action | Description |
|-----|--------|-------------|
| `ctrl+shift+up` | `scroll_line_up smooth` | Scroll up one line |
| `ctrl+shift+k` | `scroll_line_up smooth` | Scroll up one line |
| `ctrl+shift+down` | `scroll_line_down smooth` | Scroll down one line |
| `ctrl+shift+j` | `scroll_line_down smooth` | Scroll down one line |
| `ctrl+shift+page_up` | `scroll_page_up` | Scroll up one page |
| `ctrl+shift+page_down` | `scroll_page_down` | Scroll down one page |
| `ctrl+shift+home` | `scroll_home` | Scroll to top |
| `ctrl+shift+end` | `scroll_end` | Scroll to bottom |
| `ctrl+shift+z` | `scroll_to_prompt -1` | Scroll to previous shell prompt |
| `ctrl+shift+x` | `scroll_to_prompt 1` | Scroll to next shell prompt |
| `ctrl+shift+h` | `show_scrollback` | Open scrollback in pager |
| `ctrl+shift+g` | `show_last_command_output` | Show last command output |
| `ctrl+shift+/` | `search_scrollback` | Search scrollback buffer |

## Window Management

| Key | Action | Description |
|-----|--------|-------------|
| `ctrl+shift+enter` | `new_window` | Create new window |
| `ctrl+shift+n` | `new_os_window` | Create new OS window |
| `ctrl+shift+w` | `close_window` | Close current window |
| `ctrl+shift+]` | `next_window` | Focus next window |
| `ctrl+shift+[` | `previous_window` | Focus previous window |
| `ctrl+shift+f` | `move_window_forward` | Move window forward in layout |
| `ctrl+shift+b` | `move_window_backward` | Move window backward in layout |
| `ctrl+shift+`` ` | `move_window_to_top` | Move window to top |
| `ctrl+shift+r` | `start_resizing_window` | Enter resize mode |
| `ctrl+shift+1` | `first_window` | Focus window 1 |
| `ctrl+shift+2` | `second_window` | Focus window 2 |
| `ctrl+shift+3` | `third_window` | Focus window 3 |
| `ctrl+shift+4` | `fourth_window` | Focus window 4 |
| `ctrl+shift+5` | `fifth_window` | Focus window 5 |
| `ctrl+shift+6` | `sixth_window` | Focus window 6 |
| `ctrl+shift+7` | `seventh_window` | Focus window 7 |
| `ctrl+shift+8` | `eighth_window` | Focus window 8 |
| `ctrl+shift+9` | `ninth_window` | Focus window 9 |
| `ctrl+shift+0` | `tenth_window` | Focus window 10 |
| `ctrl+shift+f7` | `focus_visible_window` | Focus visible window |
| `ctrl+shift+f8` | `swap_with_window` | Swap with another window |

## Tab Management

| Key | Action | Description |
|-----|--------|-------------|
| `ctrl+shift+right` | `next_tab` | Switch to next tab |
| `ctrl+tab` | `next_tab` | Switch to next tab |
| `ctrl+shift+left` | `previous_tab` | Switch to previous tab |
| `ctrl+shift+tab` | `previous_tab` | Switch to previous tab |
| `ctrl+shift+t` | `new_tab` | Create new tab |
| `ctrl+shift+q` | `close_tab` | Close current tab |
| `ctrl+shift+.` | `move_tab_forward` | Move tab forward |
| `ctrl+shift+,` | `move_tab_backward` | Move tab backward |
| `ctrl+shift+alt+t` | `set_tab_title` | Rename current tab |

## Layout Management

| Key | Action | Description |
|-----|--------|-------------|
| `ctrl+shift+l` | `next_layout` | Switch to next layout |

## Font Sizes

| Key | Action | Description |
|-----|--------|-------------|
| `ctrl+shift+equal` | `change_font_size all +2.0` | Increase font size |
| `ctrl+shift+plus` | `change_font_size all +2.0` | Increase font size |
| `ctrl+shift+minus` | `change_font_size all -2.0` | Decrease font size |
| `ctrl+shift+backspace` | `change_font_size all 0` | Reset font size |

## Hints (Select Visible Text)

| Key | Action | Description |
|-----|--------|-------------|
| `ctrl+shift+e` | `open_url_with_hints` | Open URL with hints |
| `ctrl+shift+p>f` | `kitten hints --type path` | Select path (insert) |
| `ctrl+shift+p>shift+f` | `kitten hints --type path` | Select path (open) |
| `ctrl+shift+p>c` | `kitten choose-files` | Choose file (insert) |
| `ctrl+shift+p>d` | `kitten choose-files --mode=dir` | Choose directory (insert) |
| `ctrl+shift+p>l` | `kitten hints --type line` | Select line (insert) |
| `ctrl+shift+p>w` | `kitten hints --type word` | Select word (insert) |
| `ctrl+shift+p>h` | `kitten hints --type hash` | Select hash (insert) |
| `ctrl+shift+p>n` | `kitten hints --type linenum` | Open file at line number |
| `ctrl+shift+p>y` | `kitten hints --type hyperlink` | Open hyperlink |

## Miscellaneous

| Key | Action | Description |
|-----|--------|-------------|
| `ctrl+shift+f1` | `show_kitty_doc overview` | Open kitty documentation |
| `ctrl+shift+f2` | `edit_config_file` | Edit kitty.conf |
| `ctrl+shift+f3` | `command_palette` | Open command palette |
| `ctrl+shift+f5` | `load_config_file` | Reload kitty configuration |
| `ctrl+shift+f6` | `debug_config` | Debug kitty configuration |
| `ctrl+shift+f10` | `toggle_maximized` | Toggle maximized state |
| `ctrl+shift+f11` | `toggle_fullscreen` | Toggle fullscreen |
| `ctrl+shift+u` | `kitten unicode_input` | Unicode input |
| `ctrl+shift+escape` | `kitty_shell window` | Open kitty shell |
| `ctrl+shift+delete` | `clear_terminal reset` | Reset terminal |
| `ctrl+shift+a>m` | `set_background_opacity +0.1` | Increase opacity |
| `ctrl+shift+a>l` | `set_background_opacity -0.1` | Decrease opacity |
| `ctrl+shift+a>1` | `set_background_opacity 1` | Set fully opaque |
| `ctrl+shift+a>d` | `set_background_opacity default` | Reset opacity |
