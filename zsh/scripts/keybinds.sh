# ============================================================
# ZSH KEYBINDINGS
# ============================================================
# Configuration based on ZLE (Zsh Line Editor).
#
# Official documentation:
# https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html
# ============================================================


# ------------------------------------------------------------
# 1. EDITING MODE
# ------------------------------------------------------------

# Use Emacs-style keybindings.
#
# This provides familiar shortcuts such as:
#   Ctrl+A  -> beginning of line
#   Ctrl+E  -> end of line
#   Ctrl+B  -> backward character
#   Ctrl+F  -> forward character
#   Ctrl+P  -> previous history entry
#   Ctrl+N  -> next history entry
#   Ctrl+R  -> reverse history search
bindkey -e


# ------------------------------------------------------------
# 2. TERMINAL / TERMINFO
# ------------------------------------------------------------

# Load terminal information.
#
# Using terminfo is preferable to hardcoding terminal escape
# sequences because different terminals may use different
# sequences for the same physical key.
zmodload -i zsh/terminfo


# ------------------------------------------------------------
# 3. BASIC CURSOR MOVEMENT
# ------------------------------------------------------------

# Beginning / end of line.
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line

# One character backward / forward.
bindkey '^B' backward-char
bindkey '^F' forward-char


# ------------------------------------------------------------
# 4. HOME / END
# ------------------------------------------------------------

# Use the sequences provided by terminfo when available.
[[ -n "${terminfo[khome]}" ]] &&
    bindkey -- "${terminfo[khome]}" beginning-of-line

[[ -n "${terminfo[kend]}" ]] &&
    bindkey -- "${terminfo[kend]}" end-of-line


# Common fallbacks for xterm/VT-compatible terminals.
bindkey '\e[H' beginning-of-line
bindkey '\e[F' end-of-line

bindkey '\eOH' beginning-of-line
bindkey '\eOF' end-of-line

bindkey '\e[1~' beginning-of-line
bindkey '\e[4~' end-of-line

bindkey '\e[7~' beginning-of-line
bindkey '\e[8~' end-of-line


# ------------------------------------------------------------
# 5. ARROW KEYS
# ------------------------------------------------------------

# Standard arrow keys.
bindkey '\e[A' up-line-or-history
bindkey '\e[B' down-line-or-history
bindkey '\e[C' forward-char
bindkey '\e[D' backward-char

# SS3 variants used by some terminals.
bindkey '\eOA' up-line-or-history
bindkey '\eOB' down-line-or-history
bindkey '\eOC' forward-char
bindkey '\eOD' backward-char


# ------------------------------------------------------------
# 6. SMART HISTORY SEARCH WITH UP / DOWN
# ------------------------------------------------------------
#
# Example:
#
#   git ch<Up>
#
# will search backward through commands starting with "git ch".
#
# This is more useful than plain up-line-or-history when working
# with a large shell history.

bindkey '\e[A' history-beginning-search-backward
bindkey '\e[B' history-beginning-search-forward

bindkey '\eOA' history-beginning-search-backward
bindkey '\eOB' history-beginning-search-forward

# Use terminfo arrow sequences when available.
[[ -n "${terminfo[kcuu1]}" ]] &&
    bindkey -- "${terminfo[kcuu1]}" history-beginning-search-backward

[[ -n "${terminfo[kcud1]}" ]] &&
    bindkey -- "${terminfo[kcud1]}" history-beginning-search-forward


# ------------------------------------------------------------
# 7. CTRL + LEFT / RIGHT
# ------------------------------------------------------------

# Ctrl + Left  -> previous word
# Ctrl + Right -> next word

bindkey '\e[1;5D' backward-word
bindkey '\e[1;5C' forward-word

# Alternative sequences used by some terminals.
bindkey '\e[5D' backward-word
bindkey '\e[5C' forward-word


# ------------------------------------------------------------
# 8. ALT + LEFT / RIGHT
# ------------------------------------------------------------

# Alt + Left  -> previous word
# Alt + Right -> next word

bindkey '\e[1;3D' backward-word
bindkey '\e[1;3C' forward-word

# Traditional Emacs shortcuts:
#
#   Alt+B -> previous word
#   Alt+F -> next word

bindkey '\eb' backward-word
bindkey '\ef' forward-word


# ------------------------------------------------------------
# 9. CHARACTER DELETION
# ------------------------------------------------------------

# Backspace.
#
# Different terminals may send Backspace as either ^H or ^?.
# Both are handled here.
bindkey '^H' backward-delete-char
bindkey '^?' backward-delete-char

# Delete key using terminfo when available.
if [[ -n "${terminfo[kdch1]}" ]]; then
    bindkey -- "${terminfo[kdch1]}" delete-char
fi

# Common Delete fallback.
bindkey '\e[3~' delete-char


# ------------------------------------------------------------
# 10. DELETE WORDS
# ------------------------------------------------------------

# Ctrl+W -> delete previous word.
bindkey '^W' backward-kill-word

# Alt+Backspace -> delete previous word.
bindkey '\e^?' backward-kill-word
bindkey '\e^H' backward-kill-word

# Alt+D -> delete next word.
bindkey '\ed' kill-word

# Ctrl+Backspace.
#
# There is no universal escape sequence for Ctrl+Backspace.
# These sequences are used by terminals supporting modified
# key reporting.
bindkey '\e[127;5u' backward-kill-word
bindkey '\e[8;5u' backward-kill-word

# Ctrl+Delete -> delete next word.
bindkey '\e[3;5~' kill-word


# ------------------------------------------------------------
# 11. DELETE TO BEGINNING / END OF LINE
# ------------------------------------------------------------

# Ctrl+U -> kill from cursor to beginning of line.
bindkey '^U' backward-kill-line

# Ctrl+K -> kill from cursor to end of line.
bindkey '^K' kill-line


# ------------------------------------------------------------
# 12. HISTORY
# ------------------------------------------------------------

# Traditional history navigation.
bindkey '^P' up-line-or-history
bindkey '^N' down-line-or-history

# Reverse incremental history search.
bindkey '^R' history-incremental-search-backward


# ------------------------------------------------------------
# 13. SCREEN / EDITING
# ------------------------------------------------------------

# Ctrl+L -> clear screen.
bindkey '^L' clear-screen

# Ctrl+Y -> paste the most recently killed text.
bindkey '^Y' yank

# Alt+Y -> cycle through the kill ring.
bindkey '\ey' yank-pop

# Ctrl+_ -> undo.
bindkey '^_' undo

# Ctrl+X Ctrl+U -> undo.
bindkey '^X^U' undo

# Ctrl+T -> transpose the two characters around the cursor.
bindkey '^T' transpose-chars


# ------------------------------------------------------------
# 14. COMPLETION
# ------------------------------------------------------------

# Tab -> expand or complete.
bindkey '^I' expand-or-complete

# Shift+Tab -> reverse completion.
bindkey '\e[Z' reverse-menu-complete


# ------------------------------------------------------------
# 15. EDIT COMMAND LINE IN $EDITOR
# ------------------------------------------------------------
#
# Ctrl+X Ctrl+E
#
# Opens the current command line in $VISUAL or $EDITOR.

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

