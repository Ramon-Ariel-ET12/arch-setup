# ============================================================
# ALIASES
# ============================================================
# Optimized for:
#   - Neovim
#   - Git
#   - Terminal workflows
#   - File/content search
#   - Modern CLI tools
# ============================================================


# ------------------------------------------------------------
# EZA
# ------------------------------------------------------------

# List files with icons and directories first.
alias ls='eza --icons --group-directories-first'

# Long listing with Git status.
alias ll='eza -lh --icons --group-directories-first --git'

# Long listing including hidden files.
alias la='eza -lah --icons --group-directories-first --git'

# Directory tree.
alias lt='eza --tree --level=2 --icons'

# Deeper directory tree.
alias ltt='eza --tree --level=3 --icons'


# ------------------------------------------------------------
# BAT
# ------------------------------------------------------------

# Use bat instead of cat.
alias cat='bat --paging=never'

# Bat with paging enabled.
alias batp='bat'


# ------------------------------------------------------------
# SEARCH
# ------------------------------------------------------------

# Ripgrep.
#
# Search recursively while respecting .gitignore.
alias grep='rg'

# Search including hidden files.
alias grepa='rg --hidden'

# Search including hidden files but excluding .git.
alias grepah='rg --hidden --glob "!.git"'

# Find files by name using ripgrep's file listing.
alias ff='rg --files | rg'

# Search all files, including hidden files.
alias ffa='rg --files --hidden --glob "!.git" | rg'

# Find directories.
alias fd='find . -type d -iname'

# Search the current directory for a string.
alias search='rg'

# Search the entire project, including hidden files.
alias searcha='rg --hidden --glob "!.git"'


# ------------------------------------------------------------
# FUZZY FINDER
# ------------------------------------------------------------

# Open a file selected with fzf in Neovim.
alias vf='nvim "$(fzf)"'

# Search file contents and open the selected file.
alias vs='nvim "$(rg --files | fzf)"'

# Find files including hidden files and open in Neovim.
alias vfa='nvim "$(rg --files --hidden --glob "!.git" | fzf)"'


# ------------------------------------------------------------
# NEOVIM
# ------------------------------------------------------------

# Neovim.
alias v='nvim'

# Neovim with a clean configuration.
alias nvclean='nvim -u NONE'

# Edit Neovim configuration.
alias nvimrc='nvim ~/.config/nvim'



# ------------------------------------------------------------
# GIT — BASIC
# ------------------------------------------------------------

# Git status.
alias gs='git status --short --branch'

# Full Git status.
alias gst='git status'

# Git add.
alias ga='git add'

# Git add all.
alias gaa='git add --all'

# Git commit.
alias gc='git commit'

# Git commit with message.
alias gcm='git commit -m'

# Amend the last commit.
alias gca='git commit --amend'

# Amend without changing the commit message.
alias gcan='git commit --amend --no-edit'


# ------------------------------------------------------------
# GIT — DIFF
# ------------------------------------------------------------

# Working tree diff.
alias gd='git diff'

# Staged diff.
alias gds='git diff --staged'

# Diff against the last commit.
alias gdl='git diff HEAD'

# Show only changed filenames.
alias gdn='git diff --name-only'


# ------------------------------------------------------------
# GIT — LOG
# ------------------------------------------------------------

# Compact log.
alias gl='git log --oneline --decorate --graph'

# Full repository graph.
alias gla='git log --oneline --decorate --graph --all'

# Recent commits.
alias gl5='git log --oneline --decorate -5'

# Recent commits with graph.
alias gl10='git log --oneline --decorate --graph -10'


# ------------------------------------------------------------
# GIT — BRANCHES
# ------------------------------------------------------------

# List branches.
alias gb='git branch'

# List all branches.
alias gba='git branch --all'

# Create a branch.
alias gcb='git checkout -b'

# Switch branches.
alias gsw='git switch'

# Create and switch to a new branch.
alias gswc='git switch -c'

# Delete a local branch.
alias gbd='git branch -d'


# ------------------------------------------------------------
# GIT — REMOTES
# ------------------------------------------------------------

# Fetch all remotes and prune deleted branches.
alias gf='git fetch --all --prune'

# Pull.
alias gp='git pull'

# Push.
alias gps='git push'

# Push current branch and set upstream.
alias gpsu='git push -u origin HEAD'

# Show remote URLs.
alias grv='git remote -v'


# ------------------------------------------------------------
# GIT — STASH
# ------------------------------------------------------------

# Stash changes.
alias gsta='git stash push'

# List stashes.
alias gstl='git stash list'

# Apply latest stash.
alias gstp='git stash pop'

# Drop latest stash.
alias gstd='git stash drop'


# ------------------------------------------------------------
# GIT — FILE OPERATIONS
# ------------------------------------------------------------

# Restore working tree files.
alias gr='git restore'

# Unstage files.
alias grs='git restore --staged'

# Remove untracked files interactively.
alias gclean='git clean -di'


# ------------------------------------------------------------
# GIT — QUICK INSPECTION
# ------------------------------------------------------------

# Show the current branch.
alias gbranch='git branch --show-current'

# Show the repository root.
alias groot='git rev-parse --show-toplevel'

# Show the latest commit.
alias glast='git log -1 --oneline'

# Show tracked files.
alias gfiles='git ls-files'

# Show ignored files.
alias gignored='git status --ignored --short'


# ------------------------------------------------------------
# GIT + FUZZY FINDER
# ------------------------------------------------------------

# Select a Git branch with fzf and switch to it.
alias gco='git branch --all | fzf | xargs git switch'

# Select a commit with fzf and show it.
alias glog='git log --oneline --decorate --graph --all | fzf'

# Select a stash with fzf and apply it.
alias gstash='git stash list | fzf | cut -d: -f1 | xargs git stash apply'


# ------------------------------------------------------------
# GIT ALIASES FOR NEOVIM
# ------------------------------------------------------------

# Open changed files in Neovim.
alias gedit='nvim $(git diff --name-only)'

# Open staged files in Neovim.
alias gedits='nvim $(git diff --cached --name-only)'

# Open all tracked files in Neovim.
alias geditall='nvim $(git ls-files)'


# ------------------------------------------------------------
# DIRECTORY CREATION
# ------------------------------------------------------------

# Create directories recursively and print created paths.
alias mkdir='mkdir -pv'


# ------------------------------------------------------------
# FILE OPERATIONS
# ------------------------------------------------------------

# Ask before overwriting files.
alias cp='cp -iv'
alias mv='mv -iv'

# Ask before removing multiple files.
alias rm='rm -Iv'


# ------------------------------------------------------------
# DISK USAGE
# ------------------------------------------------------------

# Human-readable disk usage.
alias du='du -h'

# Show total size of the current directory.
alias dus='du -sh'

# Human-readable filesystem usage.
alias df='df -h'


# ------------------------------------------------------------
# PROCESSES
# ------------------------------------------------------------

# Search running processes.
alias psg='ps aux | grep -v grep | grep -i'

# Top CPU-consuming processes.
alias pscpu='ps aux | sort -nrk 3 | head'

# Top memory-consuming processes.
alias psmem='ps aux | sort -nrk 4 | head'


# ------------------------------------------------------------
# NETWORK
# ------------------------------------------------------------

# Show public IP address.
alias myip='curl -s https://api.ipify.org && echo'

# Show listening ports.
alias ports='ss -tulpn'

# DNS lookup.
alias dns='dig'


# ------------------------------------------------------------
# ZSH
# ------------------------------------------------------------

# Reload Zsh configuration.
alias reload='source "$ZDOTDIR/.zshrc"'

# Open Zsh configuration.
alias zshrc='nvim "$ZDOTDIR"'

# Start Zsh without loading user configuration.
alias zsh-clean='zsh -f'


# ------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------

# Print PATH one entry per line.
alias path='print -l ${(s.:.)PATH}'

# Show environment variables sorted.
alias envs='env | sort'

# Show aliases.
alias aliases='alias | sort'


# ------------------------------------------------------------
# HISTORY
# ------------------------------------------------------------

# Show recent history.
alias h='fc -l -20'

# Show the last 50 commands.
alias h50='fc -l -50'


# ------------------------------------------------------------
# GENERAL
# ------------------------------------------------------------

# Clear terminal.
alias c='clear'

# Exit shell.
alias q='exit'

# Show current date/time.
alias now='date'

