# Path where the history file will be saved
HISTFILE="$ZDOTDIR/.zsh_history"

# Maximum number of events kept in the internal session
HISTSIZE=10000

# Maximum number of events saved to the text file
SAVEHIST=10000

# Advanced options to improve history behavior
# setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
