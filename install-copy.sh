#!/usr/bin/env bash
# arch-setup/install-copy.sh — copy-based installer for agent-config, nvim, zsh
#
# Alternative to install.sh: instead of symlinks, this COPIES the config into
# the target home so each user gets an independent, editable copy. Nothing in
# this script ever links back to the repo, and the repo is never written to.
#
# Git-ignored / runtime-tracking files (.luarc.json, node_modules, generated/,
# .zsh_history, ...) are skipped so each user keeps their own local state.
#
# Supports any user via --user <name> or --home <path>.
#
# Usage:
#   ./install-copy.sh                        interactive (pick user + modules)
#   ./install-copy.sh --user <name>          interactive for that user (dry-run if no perms)
#   ./install-copy.sh --home /tmp/test       install to arbitrary home directory
#   ./install-copy.sh --only nvim,zsh        non-interactive module selection
#   ./install-copy.sh --check                dry-run: show what would be done
#   ./install-copy.sh --force                overwrite without prompting
#   ./install-copy.sh --help                 show help
#
# Modules: agent-config, nvim, zsh, hypr, ags, matugen, kitty, mpv, fastfetch, atuin  (alias: agents, neovim)
# Target resolution: --home > --user > $HOME

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FORCE=0
CHECK=0
BACKUP=1
IGNORE_DEPS=0
RESTORE=""
TARGET_USER=""
TARGET_HOME=""
ONLY=""
BACKUP_ROOT=".config/arch-setup-backups"
RUN_TIMESTAMP=""

# Colors
if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; DIM='\033[0;2m'; RESET='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; CYAN=''; DIM=''; RESET=''
fi

usage() {
  cat <<EOF
${CYAN}arch-setup copy installer${RESET} — ${DIM}$REPO_ROOT${RESET}

Copies config into the target home (no symlinks). Runtime/local files that
are git-ignored (.luarc.json, node_modules/, generated/, .zsh_history, ...)
are skipped so each user keeps their own local state.

Usage: ./install-copy.sh [options]

Options:
  --user <name>      install for system user <name> (resolves home via getent passwd)
  --home <path>      install to explicit home directory <path>
  --only <list>      comma-separated modules: agent-config,nvim,zsh,hypr,ags,matugen,kitty,mpv,fastfetch,atuin  (or agents,neovim)
                     if omitted, interactive selection is shown
  --force            overwrite existing files/dirs without asking
  --check            dry-run: show what would be done, change nothing
  --ignore-deps      skip package/binary dependency validation
  --backup           back up replaced files to \$HOME/.config/arch-setup-backups/<ts> (default)
  --no-backup        override existing files without backing them up
  --restore <ts|dir> restore a previous backup (list with: ls ~/.config/arch-setup-backups)
  --help             show this help

Examples:
  ./install-copy.sh
  ./install-copy.sh --user <name> --check
  ./install-copy.sh --home /tmp/test-home --only nvim,zsh,hypr,ags,matugen --force
  ./install-copy.sh --only agent-config --force
  HOME=/tmp/fake ./install-copy.sh --check

Modules:
  agent-config  -> copies AGENTS.md + skills to Claude/OpenCode/CommandCode dirs
  nvim          -> copies nvim/   -> \$HOME/.config/nvim
  zsh           -> copies zsh/    -> \$HOME/.config/zsh + creates \$HOME/.zshenv
  hypr          -> copies hypr/   -> \$HOME/.config/hypr (skips matugen 'generated/')
  ags           -> copies ags/    -> \$HOME/.config/ags (skips node_modules etc.)
  matugen       -> copies matugen/ -> \$HOME/.config/matugen
  kitty         -> copies kitty/  -> \$HOME/.config/kitty
  mpv           -> copies mpv/    -> \$HOME/.config/mpv
  fastfetch     -> copies fastfetch/ -> \$HOME/.config/fastfetch
  atuin         -> copies atuin/  -> \$HOME/.config/atuin
EOF
  exit 0
}

# --- arg parsing ---
while (($#)); do
  case "$1" in
    --force) FORCE=1 ;;
    --check) CHECK=1 ;;
    --ignore-deps) IGNORE_DEPS=1 ;;
    --user)
      [[ $# -ge 2 ]] || { echo "Missing value for --user" >&2; exit 1; }
      TARGET_USER="$2"; shift
      ;;
    --home)
      [[ $# -ge 2 ]] || { echo "Missing value for --home" >&2; exit 1; }
      TARGET_HOME="$2"; shift
      ;;
    --only)
      [[ $# -ge 2 ]] || { echo "Missing value for --only" >&2; exit 1; }
      ONLY="$2"; shift
      ;;
    --backup) BACKUP=1 ;;
    --no-backup) BACKUP=0 ;;
    --restore)
      [[ $# -ge 2 ]] || { echo "Missing value for --restore" >&2; exit 1; }
      RESTORE="$2"; shift
      ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
  shift
done

# --- resolve target home ---
resolve_target_home() {
  if [ -n "$TARGET_HOME" ]; then
    if [ -n "$TARGET_USER" ]; then
      local expected
      expected="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || true)"
      if [ -n "$expected" ] && [ "$expected" != "$TARGET_HOME" ]; then
        echo -e "${YELLOW}Warning:${RESET} --user $TARGET_USER resolves to $expected but --home is $TARGET_HOME (using --home)" >&2
      fi
    fi
    echo "$TARGET_HOME"
    return
  fi
  if [ -n "$TARGET_USER" ]; then
    local home
    home="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || true)"
    if [ -z "$home" ]; then
      echo -e "${RED}Error:${RESET} user '$TARGET_USER' not found (getent passwd)" >&2
      exit 1
    fi
    echo "$home"
    return
  fi
  echo "$HOME"
}

TARGET_HOME="$(resolve_target_home)"
TARGET_HOME="${TARGET_HOME%/}"

if [ -z "$TARGET_USER" ]; then
  TARGET_USER="$(getent passwd | awk -F: -v h="$TARGET_HOME" '$6==h {print $1; exit}')"
  TARGET_USER="${TARGET_USER:-${USER:-$(id -un 2>/dev/null || echo unknown)}}"
fi

if [ ! -d "$TARGET_HOME" ]; then
  if [ "$CHECK" = 1 ]; then
    echo -e "${YELLOW}Note:${RESET} target home $TARGET_HOME does not exist (dry-run continues)" >&2
  else
    echo -e "${RED}Error:${RESET} target home does not exist: $TARGET_HOME" >&2
    exit 1
  fi
fi

if [ "$CHECK" != 1 ] && [ -d "$TARGET_HOME" ] && [ ! -w "$TARGET_HOME" ]; then
  echo -e "${RED}Error:${RESET} no write permission to $TARGET_HOME (owner: $(stat -c %U "$TARGET_HOME" 2>/dev/null || echo unknown))" >&2
  echo "  Try: sudo -u $TARGET_USER $REPO_ROOT/install-copy.sh ${ONLY:+--only $ONLY} ${FORCE:+--force}" >&2
  echo "  Or:  ./install-copy.sh --user $TARGET_USER --check   (dry-run)" >&2
  exit 1
fi

CURRENT_USER="$(whoami 2>/dev/null || id -un 2>/dev/null || echo "${USER:-unknown}")"
IS_OTHER_USER=0
if [ "$TARGET_HOME" != "$HOME" ] || [ "$TARGET_USER" != "$CURRENT_USER" ]; then
  IS_OTHER_USER=1
fi

confirm() {
  local ans
  read -r -p "$1 [y/N] " ans
  [[ "${ans,,}" == y* ]]
}

backup_dir_for() {
  if [ -z "$RUN_TIMESTAMP" ]; then
    RUN_TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
  fi
  echo "$TARGET_HOME/$BACKUP_ROOT/$RUN_TIMESTAMP"
}

# Move an existing dest into the central backup dir, preserving its path
# relative to TARGET_HOME. Returns 0 on success, 1 if skipped (no backup).
backup_existing() {
  local dest="$1"
  if [ "$BACKUP" != 1 ]; then
    echo -e "  ${DIM}·${RESET} override $dest (--no-backup)"
    rm -rf -- "$dest"
    return 0
  fi
  local bdir rel bpath
  bdir="$(backup_dir_for)"
  rel="${dest#"$TARGET_HOME"/}"
  bpath="$bdir/$rel"
  mkdir -p "$(dirname "$bpath")"
  mv "$dest" "$bpath"
  echo -e "  ${YELLOW}·${RESET} backed up $dest -> ${DIM}$bpath${RESET}"
  return 0
}

# Restore a previous backup run. --restore <ts|dir> moves all backed-up
# files/dirs back to their original locations under TARGET_HOME.
do_restore() {
  local want="$1"
  local bdir
  if [ -d "$want" ]; then
    bdir="$want"
  else
    bdir="$TARGET_HOME/$BACKUP_ROOT/$want"
  fi
  if [ ! -d "$bdir" ]; then
    echo -e "${RED}Error:${RESET} backup not found: $bdir" >&2
    echo -e "  Available backups: ${DIM}"
    ls -1 "$TARGET_HOME/$BACKUP_ROOT" 2>/dev/null | sed 's/^/    /'
    echo -e "${RESET}"
    exit 1
  fi
  echo -e "${CYAN}== restoring backup${RESET} ${DIM}$bdir${RESET}"
  local path rel dest parent

  # Restore deepest-first so nested paths land before parents are rebuilt.
  while IFS= read -r path; do
    [ -e "$path" ] || continue
    rel="${path#"$bdir"/}"
    dest="$TARGET_HOME/$rel"
    parent="$(dirname "$dest")"
    if [ -L "$parent" ] || [ -f "$parent" ]; then
      rm -rf -- "$parent"
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      rm -rf -- "$dest"
    fi
    mkdir -p "$(dirname "$dest")"
    mv "$path" "$dest"
    echo -e "  ${GREEN}✓${RESET} restored $dest"
  done < <(find "$bdir" \( -type f -o -type l -o -type d \) | sort -r)

  echo -e "${GREEN}Done.${RESET} Restored backup $bdir"
  rmdir "$bdir" 2>/dev/null || true
  exit 0
}

# Copy one file/symlink/entry into dest. Excludes are handled by the caller
# (per-module) via strip of git-ignored paths; copy_one just does the work.
copy_one() {
  local src="$1" dest="$2"

  if [ "$CHECK" = 1 ]; then
    if [ -e "$dest" ]; then
      echo -e "  ${YELLOW}→${RESET} would replace $dest <- $src"
    else
      echo -e "  ${GREEN}→${RESET} would copy $dest <- $src"
    fi
    return
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$FORCE" != 1 ] && ! confirm "  $dest exists. Backup and replace with copy?"; then
      echo -e "  · skipped $dest"
      return
    fi
    backup_existing "$dest" || { echo -e "  · skipped $dest"; return; }
  fi

  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
  echo -e "  ${GREEN}✓${RESET} copied $dest <- $src"
}

# Copy a whole config dir, stripping git-ignored / runtime/local entries so
# each user keeps their own local state. Uses `git check-ignore` when the repo
# has a .gitignore that covers the entry (respects root .gitignore), plus a
# small built-in deny-list for things git-ignore may not track (e.g. logs).
copy_tree() {
  local src="$1" dest="$2"

  if [ ! -e "$src" ]; then
    echo -e "  ${RED}✗${RESET} source not found: $src" >&2
    return 1
  fi

  # The repo's canonical ignore baseline (root .gitignore). Paths matched
  # here are runtime/local state we want each user to regenerate themselves.
  local deny_re='(^|/)(\.git|\.gitignore)(/|$)'
  # Entries that are local-only regardless of git status.
  local builtin_re='(^|/)(node_modules|@girs|dist|\.deps|\.commandcode|\.luarc\.json|logs\.log|generated|data|hyprlock\.conf|_matugen\.scss|lazy-lock\.json|opencode\.json)(/|$)'

  if [ "$CHECK" = 1 ]; then
    echo -e "  ${GREEN}→${RESET} would copy $src -> $dest (excluding runtime/local entries)"
    return
  fi

  # Backup & clear existing target if present.
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$FORCE" != 1 ] && ! confirm "  $dest exists. Backup and replace with copy?"; then
      echo -e "  · skipped $dest"
      return
    fi
    backup_existing "$dest" || return
  fi
  mkdir -p "$dest"

  local ok=0
  while IFS= read -r -d '' f; do
    # Relative path from src (no leading slash) for matching.
    local rel="${f#"$src"/}"
    # Skip explicit deny entries.
    if [[ "/$rel/" =~ $deny_re ]] || [[ "/$rel/" =~ $builtin_re ]]; then
      echo -e "  ${DIM}· skip $rel (runtime/local)${RESET}"
      continue
    fi
    # Skip anything covered by the repo .gitignore (e.g. ags/node_modules).
    if [ -d "$REPO_ROOT/.git" ] && git -C "$REPO_ROOT" check-ignore -q "$rel" 2>/dev/null; then
      echo -e "  ${DIM}· skip $rel (git-ignored)${RESET}"
      continue
    fi

    local target="$dest/$rel"
    mkdir -p "$(dirname "$target")"
    cp -a "$f" "$target"
    ok=1
    if [ -d "$f" ]; then
      echo -e "  ${GREEN}✓${RESET} copied dir  $target <- $f"
    else
      echo -e "  ${GREEN}✓${RESET} copied file $target <- $f"
    fi
  done < <(find "$src" -mindepth 1 \( -type f -o -type l -o -type d \) -print0 | sort -z)

  if [ "$ok" = 0 ]; then
    echo -e "  ${YELLOW}·${RESET} nothing copied (all entries excluded) from $src"
    rm -rf -- "$dest" 2>/dev/null || true
    return
  fi

  if [ "$IS_OTHER_USER" = 1 ] && [ "$(id -u)" = 0 ]; then
    chown -R "$TARGET_USER" "$dest" 2>/dev/null || true
  fi
}

ensure_zshenv() {
  local zshenv="$TARGET_HOME/.zshenv"
  local content='export ZDOTDIR="$HOME/.config/zsh"'
  if [ "$CHECK" = 1 ]; then
    if [ -f "$zshenv" ] && grep -qF 'ZDOTDIR' "$zshenv"; then
      echo -e "  ${GREEN}✓${RESET} would keep $zshenv (already sets ZDOTDIR)"
    else
      echo -e "  ${GREEN}→${RESET} would create $zshenv with ZDOTDIR"
    fi
    return
  fi

  if [ -f "$zshenv" ]; then
    if grep -qF 'ZDOTDIR' "$zshenv"; then
      echo -e "  ${GREEN}✓${RESET} $zshenv already sets ZDOTDIR"
      return
    fi
    if [ "$FORCE" = 1 ] || confirm "  $zshenv exists but lacks ZDOTDIR. Append?"; then
      local backup="${zshenv}.backup-$(date +%s)"
      cp "$zshenv" "$backup"
      echo "" >> "$zshenv"
      echo "$content" >> "$zshenv"
      echo -e "  ${GREEN}✓${RESET} appended ZDOTDIR to $zshenv (backup $backup)"
    else
      echo -e "  · skipped $zshenv"
    fi
  else
    echo "$content" > "$zshenv"
    echo -e "  ${GREEN}✓${RESET} created $zshenv"
    if [ "$IS_OTHER_USER" = 1 ] && [ "$(id -u)" = 0 ]; then
      chown "$TARGET_USER" "$zshenv" 2>/dev/null || true
    fi
  fi
}

install_nvim() {
  echo
  echo -e "${CYAN}== nvim ==${RESET}  ${DIM}$REPO_ROOT/nvim -> $TARGET_HOME/.config/nvim${RESET}"
  copy_tree "$REPO_ROOT/nvim" "$TARGET_HOME/.config/nvim"
}

install_zsh() {
  echo
  echo -e "${CYAN}== zsh ==${RESET}  ${DIM}$REPO_ROOT/zsh -> $TARGET_HOME/.config/zsh${RESET}"
  copy_tree "$REPO_ROOT/zsh" "$TARGET_HOME/.config/zsh"

  # Each user gets their own empty history file (the repo's is git-ignored
  # and intentionally not copied).
  local hist="$TARGET_HOME/.config/zsh/.zsh_history"
  if [ "$CHECK" = 1 ]; then
    if [ -e "$hist" ]; then
      echo -e "  ${GREEN}✓${RESET} would keep existing $hist"
    else
      echo -e "  ${GREEN}→${RESET} would create empty $hist"
    fi
  elif [ ! -e "$hist" ]; then
    touch "$hist"
    echo -e "  ${GREEN}✓${RESET} created empty $hist (per-user history)"
    if [ "$(id -u)" = 0 ]; then
      chown "$TARGET_USER" "$hist" 2>/dev/null || true
    fi
  fi

  ensure_zshenv
}

install_agents() {
  echo
  echo -e "${CYAN}== agent-config ==${RESET}  ${DIM}$REPO_ROOT/agent-config${RESET}"

  # Here we copy AGENTS.md + each skill dir into the target's agent dirs
  # ourselves (no symlinks, no sub-installer invocation).
  local memsrc="$REPO_ROOT/agent-config/AGENTS.md"
  if [ ! -f "$memsrc" ]; then
    echo -e "  ${RED}✗${RESET} AGENTS.md not found: $memsrc" >&2
    return 1
  fi

  # Build the list of agent destinations.
  local -a agents
  agents=(
    "claude-code:$TARGET_HOME/.claude:CLAUDE.md:skills"
    "opencode:$TARGET_HOME/.config/opencode:AGENTS.md:skills"
    "command-code:$TARGET_HOME/.commandcode:AGENTS.md:skills"
  )

  local skills=()
  for d in "$REPO_ROOT/agent-config/skills"/*/SKILL.md; do
    [ -e "$d" ] && skills+=("${d%/SKILL.md}")
  done

  for entry in "${agents[@]}"; do
    local label memdir memname skillsdir
    IFS=':' read -r label memdir memname skillsdir <<<"$entry"
    echo
    echo -e "  ${CYAN}→ $label${RESET}  ${DIM}$memdir${RESET}"

    # Memory file: backup/replace then copy.
    if [ "$CHECK" = 1 ]; then
      [ -e "$memdir/$memname" ] \
        && echo -e "  ${YELLOW}→${RESET} would replace $memdir/$memname <- $memsrc" \
        || echo -e "  ${GREEN}→${RESET} would copy $memdir/$memname <- $memsrc"
    else
      if [ -e "$memdir/$memname" ]; then
        if [ "$FORCE" != 1 ] && ! confirm "  $memdir/$memname exists. Backup and replace?"; then
          echo -e "  · skipped memory file"
          return 0
        fi
        backup_existing "$memdir/$memname" || return 0
      fi
      mkdir -p "$memdir"
      cp -a "$memsrc" "$memdir/$memname"
      echo -e "  ${GREEN}✓${RESET} copied $memdir/$memname"
    fi

    # Skills: individually copy each skill dir (backing up any existing).
    if ((${#skills[@]})); then
      for skill in "${skills[@]}"; do
        local sname sdest
        sname="$(basename "$skill")"
        sdest="$memdir/$skillsdir/$sname"
        if [ "$CHECK" = 1 ]; then
          [ -e "$sdest" ] \
            && echo -e "  ${YELLOW}→${RESET} would replace $sdest" \
            || echo -e "  ${GREEN}→${RESET} would copy $sdest"
        else
          if [ -e "$sdest" ]; then
            if [ "$FORCE" = 1 ] || confirm "  $sdest exists. Backup and replace?"; then
              backup_existing "$sdest" || continue
            else
              echo -e "  · skipped $sname"
              continue
            fi
          fi
          mkdir -p "$sdest"
          cp -a "$skill/." "$sdest/"
          echo -e "  ${GREEN}✓${RESET} copied skill $sdest"
        fi
      done
    fi
  done

  if [ "$CHECK" != 1 ]; then
    if [ "$IS_OTHER_USER" = 1 ] && [ "$(id -u)" = 0 ]; then
      chown -R "$TARGET_USER" "$TARGET_HOME/.config/opencode" 2>/dev/null || true
      chown -R "$TARGET_USER" "$TARGET_HOME/.claude" 2>/dev/null || true
      chown -R "$TARGET_USER" "$TARGET_HOME/.commandcode" 2>/dev/null || true
    fi
  fi
}

install_hypr() {
  echo
  echo -e "${CYAN}== hypr ==${RESET}  ${DIM}$REPO_ROOT/hypr -> $TARGET_HOME/.config/hypr${RESET}"
  copy_tree "$REPO_ROOT/hypr" "$TARGET_HOME/.config/hypr"
}

install_ags() {
  echo
  echo -e "${CYAN}== ags ==${RESET}  ${DIM}$REPO_ROOT/ags -> $TARGET_HOME/.config/ags${RESET}"
  copy_tree "$REPO_ROOT/ags" "$TARGET_HOME/.config/ags"
}

install_matugen() {
  echo
  echo -e "${CYAN}== matugen ==${RESET}  ${DIM}$REPO_ROOT/matugen -> $TARGET_HOME/.config/matugen${RESET}"
  copy_tree "$REPO_ROOT/matugen" "$TARGET_HOME/.config/matugen"
}

install_kitty() {
  echo
  echo -e "${CYAN}== kitty ==${RESET}  ${DIM}$REPO_ROOT/kitty -> $TARGET_HOME/.config/kitty${RESET}"
  copy_tree "$REPO_ROOT/kitty" "$TARGET_HOME/.config/kitty"
}

install_mpv() {
  echo
  echo -e "${CYAN}== mpv ==${RESET}  ${DIM}$REPO_ROOT/mpv -> $TARGET_HOME/.config/mpv${RESET}"
  copy_tree "$REPO_ROOT/mpv" "$TARGET_HOME/.config/mpv"
}

install_fastfetch() {
  echo
  echo -e "${CYAN}== fastfetch ==${RESET}  ${DIM}$REPO_ROOT/fastfetch -> $TARGET_HOME/.config/fastfetch${RESET}"
  copy_tree "$REPO_ROOT/fastfetch" "$TARGET_HOME/.config/fastfetch"
}

install_atuin() {
  echo
  echo -e "${CYAN}== atuin ==${RESET}  ${DIM}$REPO_ROOT/atuin -> $TARGET_HOME/.config/atuin${RESET}"
  copy_tree "$REPO_ROOT/atuin" "$TARGET_HOME/.config/atuin"
}

# --- interactive selectors ---
select_target_interactive() {
  if [ -n "$TARGET_USER" ] || [ -n "$TARGET_HOME" ] || [ ! -t 0 ]; then
    return
  fi
  if [ -n "$ONLY" ]; then
    return
  fi
  echo
  echo -e "${CYAN}Target user/home${RESET}"
  echo -e "  current: ${GREEN}$CURRENT_USER${RESET} -> $HOME"
  local users
  users="$(awk -F: '$3>=1000 && $7!~/nologin|false/ {print $1}' /etc/passwd | tr '\n' ' ')"
  echo -e "  detected users: ${DIM}$users${RESET}"
  read -r -p "Install for user (name) or leave empty for $CURRENT_USER, or path to home: " input || true
  if [ -z "$input" ]; then
    return
  fi
  if [[ "$input" == /* ]]; then
    TARGET_HOME="$input"
    TARGET_USER="$(getent passwd | awk -F: -v h="$TARGET_HOME" '$6==h {print $1; exit}')"
    TARGET_USER="${TARGET_USER:-$CURRENT_USER}"
  else
    TARGET_USER="$input"
    local home
    home="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || true)"
    if [ -z "$home" ]; then
      echo -e "${RED}Error:${RESET} user $TARGET_USER not found" >&2
      exit 1
    fi
    TARGET_HOME="$home"
  fi
  echo -e "  → target: ${GREEN}$TARGET_USER${RESET} -> $TARGET_HOME"
  if [ "$TARGET_HOME" != "$HOME" ] || [ "$TARGET_USER" != "$CURRENT_USER" ]; then
    IS_OTHER_USER=1
  else
    IS_OTHER_USER=0
  fi
  if [ "$IS_OTHER_USER" = 1 ] && [ ! -w "$TARGET_HOME" ] && [ "$CHECK" != 1 ]; then
    echo -e "${YELLOW}Warning:${RESET} no write permission to $TARGET_HOME. Dry-run will be used or run with sudo." >&2
    if ! confirm "Continue with --check (dry-run) instead?"; then
      exit 1
    fi
    CHECK=1
  fi
}

# --- dependency validation guard ---
validate_dependencies() {
  [ "$IGNORE_DEPS" = 1 ] && { echo -e "  ${DIM}· dependency validation skipped (--ignore-deps)${RESET}"; return; }

  local mod
  local -a need=() opt=() missing=() soft=()
  local -A seen_need seen_opt

  local nvim_need=(nvim git rg fd fzf)
  local nvim_opt=(rustc cargo tree-sitter dotnet node bun npm)

  local zsh_need=(zsh git)
  local zsh_opt=(zoxide starship atuin fastfetch eza bat fd rg fzf)

  local hypr_need=(Hyprland hyprctl hypridle hyprlock hyprpm kitty ags matugen)
  local hypr_opt=(cclipd awww grim slurp satty gnome-keyring-daemon polkit-gnome-authentication-agent-1 brave-origin hyprsplit)

  local ags_need=(ags bun sass)
  local ags_opt=(node matugen)

  local matugen_need=(matugen)
  local kitty_need=(kitty)
  local mpv_need=(mpv)
  local fastfetch_need=(fastfetch)
  local atuin_need=(atuin)

  local -A reason=(
    [nvim]="neovim (editor)"
    [git]="git (lazy.nvim bootstrap + git tooling)"
    [rg]="ripgrep"
    [fd]="fd"
    [fzf]="fzf"
    [zsh]="zsh"
    [Hyprland]="hyprland"
    [hyprctl]="hyprland (hyprctl)"
    [hypridle]="hypridle"
    [hyprlock]="hyprlock"
    [hyprpm]="hyprpm"
    [kitty]="kitty"
    [ags]="ags (astal shell)"
    [matugen]="matugen (Material You theming)"
    [bun]="bun (ags build tool)"
    [sass]="sass (ags stylesheet compiler)"
    [mpv]="mpv"
    [fastfetch]="fastfetch"
    [atuin]="atuin"
  )

  add_need() { local b="$1"; if [[ -z "${seen_need[$b]:-}" ]]; then seen_need[$b]=1; need+=("$b"); fi; }
  add_opt() { local b="$1"; if [[ -z "${seen_opt[$b]:-}" ]]; then seen_opt[$b]=1; opt+=("$b"); fi; }

  for mod in "$@"; do
    case "$mod" in
      agent-config) ;;
      nvim)  for b in "${nvim_need[@]}"; do add_need "$b"; done
             for b in "${nvim_opt[@]}"; do add_opt "$b"; done ;;
      zsh)   for b in "${zsh_need[@]}"; do add_need "$b"; done
             for b in "${zsh_opt[@]}"; do add_opt "$b"; done ;;
      hypr)  for b in "${hypr_need[@]}"; do add_need "$b"; done
             for b in "${hypr_opt[@]}"; do add_opt "$b"; done ;;
      ags)   for b in "${ags_need[@]}"; do add_need "$b"; done
             for b in "${ags_opt[@]}"; do add_opt "$b"; done ;;
      matugen) add_need matugen ;;
      kitty) add_need kitty ;;
      mpv) add_need mpv ;;
      fastfetch) add_need fastfetch ;;
      atuin) add_need atuin ;;
    esac
  done

  local b
  for b in "${need[@]}"; do
    if ! command -v "$b" >/dev/null 2>&1; then missing+=("$b"); fi
  done
  for b in "${opt[@]}"; do
    if ! command -v "$b" >/dev/null 2>&1; then soft+=("$b"); fi
  done

  if ((${#missing[@]})); then
    echo
    echo -e "${RED}✗ Missing required packages/binaries:${RESET}"
    for b in "${missing[@]}"; do
      echo -e "  ${RED}•${RESET} ${YELLOW}$b${RESET} (${reason[$b]:-$b})"
    done
    if [ "$CHECK" = 1 ]; then
      echo -e "  ${DIM}(dry-run: reported only, not blocking)${RESET}"
    else
      echo -e "  ${DIM}Install them, e.g.:${RESET}"
      echo -e "    ${CYAN}sudo pacman -S $(echo "${missing[*]}" | tr ' ' ' ')${RESET}"
      if [[ " ${missing[*]} " == *" Hyprland "* ]]; then
        echo -e "  ${DIM}or: sudo pacman -S hyprland kitty hypridle hyprlock hyprpm ags matugen${RESET}"
      fi
      echo -e "  ${DIM}Re-run with --ignore-deps to force installation anyway.${RESET}"
      exit 1
    fi
  fi

  if ((${#soft[@]})); then
    echo
    echo -e "${YELLOW}⚠ Optional dependencies not found (install will still proceed):${RESET}"
    echo -e "  ${DIM}${soft[*]}${RESET}"
  fi

  if [[ " $* " == *" nvim "* ]]; then
    local init="$REPO_ROOT/nvim/init.lua" lazy="$REPO_ROOT/nvim/lua/config/lazy.lua"
    local ok=1
    [ -f "$init" ] || ok=0
    [ -f "$lazy" ] || ok=0
    if [ "$ok" = 1 ]; then
      echo -e "  ${GREEN}✓${RESET} nvim config chain resolves (init.lua → config.lazy)"
    else
      echo -e "  ${YELLOW}⚠${RESET} nvim config chain broken (missing init.lua or lua/config/lazy.lua)" >&2
      if [ "$CHECK" != 1 ]; then
        echo -e "  ${DIM}Re-run with --ignore-deps to force.${RESET}"
        exit 1
      fi
    fi
  fi
}

select_modules_interactive() {
  local all_modules=("agent-config" "nvim" "zsh" "hypr" "ags" "matugen" "kitty" "mpv" "fastfetch" "atuin")
  local selected=()

  if [ -n "$ONLY" ]; then
    IFS=',' read -ra tokens <<< "$ONLY"
    for t in "${tokens[@]}"; do
      t="$(echo "$t" | xargs | tr '[:upper:]' '[:lower:]')"
      case "$t" in
        agent-config|agents|agent) selected+=("agent-config") ;;
        nvim|neovim|vim) selected+=("nvim") ;;
        zsh|shell) selected+=("zsh") ;;
        hypr|hyprland|wayland) selected+=("hypr") ;;
        ags|astal|desktop) selected+=("ags") ;;
        matugen) selected+=("matugen") ;;
        kitty|terminal) selected+=("kitty") ;;
        mpv|video) selected+=("mpv") ;;
        fastfetch) selected+=("fastfetch") ;;
        atuin|history) selected+=("atuin") ;;
        all|*)
          if [[ "$t" == "all" ]]; then
            selected=("${all_modules[@]}")
            break
          else
            echo -e "${RED}Error:${RESET} unknown module: $t (valid: agent-config,nvim,zsh,hypr,ags,matugen,kitty,mpv,fastfetch,atuin,all)" >&2
            exit 1
          fi
          ;;
      esac
    done
    local -A seen=()
    local dedup=()
    for m in "${selected[@]}"; do
      if [[ -z "${seen[$m]:-}" ]]; then seen[$m]=1; dedup+=("$m"); fi
    done
    selected=("${dedup[@]}")
    SELECTED_MODULES=("${selected[@]}")
    return
  fi

  if [ ! -t 0 ]; then
    SELECTED_MODULES=("${all_modules[@]}")
    return
  fi

  while true; do
    echo
    echo -e "${CYAN}Select modules to install${RESET} for ${GREEN}$TARGET_USER${RESET} (${DIM}$TARGET_HOME${RESET})"
    echo "  1) agent-config  (AGENTS.md + skills)"
    echo "  2) nvim          (.config/nvim)"
    echo "  3) zsh           (.config/zsh + .zshenv)"
    echo "  4) hypr          (.config/hypr)"
    echo "  5) ags           (.config/ags)"
    echo "  6) matugen       (.config/matugen)"
    echo "  7) kitty         (.config/kitty)"
    echo "  8) mpv           (.config/mpv)"
    echo "  9) fastfetch     (.config/fastfetch)"
    echo "  10) atuin        (.config/atuin)"
    echo "  a) all"
    echo "  (e.g. '2 4' or 'a', empty = cancel)"
    read -r -p "> " input || { SELECTED_MODULES=(); return; }
    input="$(echo "$input" | tr '[:upper:]' '[:lower:]' | xargs)"
    if [[ "$input" == "a" || "$input" == "all" ]]; then
      SELECTED_MODULES=("${all_modules[@]}")
      return
    fi
    [ -z "$input" ] && { SELECTED_MODULES=(); return; }
    local ok=1
    local -a idxs=()
    for token in $input; do
      if [[ "$token" =~ ^([1-9]|10)$ ]]; then
        idxs+=("$((token-1))")
      else
        echo "  Invalid: $token"
        ok=0; break
      fi
    done
    if ((ok)); then
      local -A seen=()
      SELECTED_MODULES=()
      for i in "${idxs[@]}"; do
        local mod="${all_modules[$i]}"
        if [[ -z "${seen[$mod]:-}" ]]; then seen[$mod]=1; SELECTED_MODULES+=("$mod"); fi
      done
      return
    fi
  done
}

# --- main ---
echo -e "${CYAN}arch-setup${RESET} ${YELLOW}(copy mode)${RESET} ${DIM}$REPO_ROOT${RESET}"
echo -e "target: ${GREEN}$TARGET_USER${RESET} -> $TARGET_HOME ${IS_OTHER_USER:+${DIM}(other user)${RESET}}"
if [ "$CHECK" = 1 ]; then
  echo -e "${YELLOW}mode: dry-run (--check)${RESET}"
elif [ "$FORCE" = 1 ]; then
  echo -e "${YELLOW}mode: force (--force)${RESET}"
fi
if [ ! -w "$TARGET_HOME" ] && [ "$CHECK" != 1 ]; then
  echo -e "${YELLOW}Warning: target not writable; will prompt or fail per file${RESET}"
fi

if [ -n "$RESTORE" ]; then
  do_restore "$RESTORE"
fi

select_target_interactive
select_modules_interactive

if ((${#SELECTED_MODULES[@]} == 0)); then
  echo
  echo "Nothing selected — no changes made."
  exit 0
fi

validate_dependencies "${SELECTED_MODULES[@]}"

echo
echo -e "Will ${YELLOW}copy${RESET}: ${GREEN}${SELECTED_MODULES[*]}${RESET} for ${GREEN}$TARGET_USER${RESET}"
if [ "$CHECK" != 1 ] && [ -t 0 ]; then
  if ! confirm "Proceed?"; then
    echo "Cancelled."
    exit 0
  fi
fi

for mod in "${SELECTED_MODULES[@]}"; do
  case "$mod" in
    agent-config) install_agents ;;
    nvim) install_nvim ;;
    zsh) install_zsh ;;
    hypr) install_hypr ;;
    ags) install_ags ;;
    matugen) install_matugen ;;
    kitty) install_kitty ;;
    mpv) install_mpv ;;
    fastfetch) install_fastfetch ;;
    atuin) install_atuin ;;
  esac
done

echo
if [ "$CHECK" = 1 ]; then
  echo -e "${YELLOW}Done (dry-run)${RESET} — no changes made. Run without --check to apply."
else
  echo -e "${GREEN}Done.${RESET} Copied ${SELECTED_MODULES[*]} for $TARGET_USER ($TARGET_HOME)"
  if [[ " ${SELECTED_MODULES[*]} " == *" zsh "* ]]; then
    echo -e "  ${DIM}→ restart zsh or run: exec zsh${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" nvim "* ]]; then
    echo -e "  ${DIM}→ nvim config copied; run nvim to install plugins${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" agent-config "* ]]; then
    echo -e "  ${DIM}→ agent skills copied; restart your agent${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" hypr "* ]]; then
    echo -e "  ${DIM}→ hypr config copied; run hyprctl reload or restart Hyprland${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" ags "* ]]; then
    echo -e "  ${DIM}→ ags config copied; run ags run or ags toggle${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" matugen "* ]]; then
    echo -e "  ${DIM}→ matugen config copied; run: matugen image <wallpaper.png> to regenerate theme${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" kitty "* ]]; then
    echo -e "  ${DIM}→ kitty config copied; restart kitty${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" mpv "* ]]; then
    echo -e "  ${DIM}→ mpv config copied; restart mpv${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" fastfetch "* ]]; then
    echo -e "  ${DIM}→ fastfetch config copied; run fastfetch${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" atuin "* ]]; then
    echo -e "  ${DIM}→ atuin config copied; restart your shell${RESET}"
  fi
  echo -e "  ${DIM}→ files are independent copies; to pick up repo changes later, re-run this installer${RESET}"
fi

# Verify
if [ "$CHECK" != 1 ]; then
  echo
  echo -e "${DIM}Verify:${RESET}"
  for mod in "${SELECTED_MODULES[@]}"; do
    case "$mod" in
      nvim) ls -ld "$TARGET_HOME/.config/nvim" 2>&1 | sed 's/^/  /' ;;
      zsh)  ls -ld "$TARGET_HOME/.config/zsh" "$TARGET_HOME/.zshenv" 2>&1 | sed 's/^/  /' ;;
      hypr) ls -ld "$TARGET_HOME/.config/hypr" 2>&1 | sed 's/^/  /' ;;
      ags)  ls -ld "$TARGET_HOME/.config/ags" 2>&1 | sed 's/^/  /' ;;
      matugen) ls -ld "$TARGET_HOME/.config/matugen" 2>&1 | sed 's/^/  /' ;;
      kitty) ls -ld "$TARGET_HOME/.config/kitty" 2>&1 | sed 's/^/  /' ;;
      mpv)  ls -ld "$TARGET_HOME/.config/mpv" 2>&1 | sed 's/^/  /' ;;
      fastfetch) ls -ld "$TARGET_HOME/.config/fastfetch" 2>&1 | sed 's/^/  /' ;;
      atuin) ls -ld "$TARGET_HOME/.config/atuin" 2>&1 | sed 's/^/  /' ;;
      agent-config)
        for p in "$TARGET_HOME/.config/opencode/AGENTS.md" "$TARGET_HOME/.config/opencode/skills" "$TARGET_HOME/.claude/CLAUDE.md" "$TARGET_HOME/.commandcode/AGENTS.md"; do
          if [ -e "$p" ] || [ -L "$p" ]; then ls -ld "$p" 2>&1 | sed 's/^/  /'; fi
        done
        ;;
    esac
  done
fi