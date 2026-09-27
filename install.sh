#!/usr/bin/env bash
# arch-setup/install.sh — unified installer for agent-config, nvim, zsh
#
# Supports any user via --user <name> or --home <path>.
# Uses symlinks so updates are reflected immediately.
#
# Usage:
#   ./install.sh                          interactive (pick user + modules)
#   ./install.sh --user <name>           interactive for that user (dry-run if no perms)
#   ./install.sh --home /tmp/test         install to arbitrary home directory
#   ./install.sh --only nvim,zsh          non-interactive module selection
#   ./install.sh --check                  dry-run: show what would be done
#   ./install.sh --force                  overwrite without prompting
#   ./install.sh --help                   show help
#
# Modules: agent-config, nvim, zsh, hypr, ags, matugen, kitty, mpv, fastfetch, atuin  (alias: agents, neovim)
# Target resolution: --home > --user > $HOME

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_OWNER="$(stat -c %U "$REPO_ROOT" 2>/dev/null || echo "${USER:-$(id -un 2>/dev/null || echo unknown)}")"

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
${CYAN}arch-setup installer${RESET} — ${DIM}$REPO_ROOT${RESET}

Usage: ./install.sh [options]

Options:
  --user <name>      install for system user <name> (resolves home via getent passwd)
  --home <path>      install to explicit home directory <path>
  --only <list>      comma-separated modules: agent-config,nvim,zsh,hypr,ags,matugen,kitty,mpv,fastfetch,atuin  (or agents,neovim)
                     if omitted, interactive selection is shown
  --force            overwrite existing files/symlinks without asking
  --check            dry-run: show what would be done, change nothing
  --ignore-deps      skip package/binary dependency validation
  --backup           back up replaced files to \$HOME/.config/arch-setup-backups/<ts> (default)
  --no-backup        override existing files without backing them up
  --restore <ts|dir> restore a previous backup (list with: ls ~/.config/arch-setup-backups)
  --help             show this help

Examples:
  ./install.sh
  ./install.sh --user <name> --check
  ./install.sh --home /tmp/test-home --only nvim,zsh,hypr,ags,matugen --force
  ./install.sh --only agent-config --force
  HOME=/tmp/fake ./install.sh --check

Modules:
  agent-config  -> links AGENTS.md + skills to Claude/OpenCode/CommandCode dirs
  nvim          -> links nvim/ -> \$HOME/.config/nvim
  zsh           -> links zsh/  -> \$HOME/.config/zsh + creates \$HOME/.zshenv
  hypr          -> links hypr/ -> \$HOME/.config/hypr
  ags           -> links ags/  -> \$HOME/.config/ags
  matugen       -> links matugen/ -> \$HOME/.config/matugen (Material You theme config; regenerated outputs into hypr/ags)
  kitty         -> links kitty/ -> \$HOME/.config/kitty
  mpv           -> links mpv/  -> \$HOME/.config/mpv
  fastfetch     -> links fastfetch/ -> \$HOME/.config/fastfetch
  atuin         -> links atuin/ -> \$HOME/.config/atuin
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
    # --home takes precedence, but also validate --user consistency if both given
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
# Normalize (remove trailing slash)
TARGET_HOME="${TARGET_HOME%/}"

# Determine target user name from home if not given (reverse lookup)
if [ -z "$TARGET_USER" ]; then
  TARGET_USER="$(getent passwd | awk -F: -v h="$TARGET_HOME" '$6==h {print $1; exit}')"
  TARGET_USER="${TARGET_USER:-${USER:-$(id -un 2>/dev/null || echo unknown)}}"
fi

# Validate target home
if [ ! -d "$TARGET_HOME" ]; then
  if [ "$CHECK" = 1 ]; then
    echo -e "${YELLOW}Note:${RESET} target home $TARGET_HOME does not exist (dry-run continues)" >&2
  else
    echo -e "${RED}Error:${RESET} target home does not exist: $TARGET_HOME" >&2
    exit 1
  fi
fi

# Permission check (unless dry-run)
if [ "$CHECK" != 1 ] && [ -d "$TARGET_HOME" ] && [ ! -w "$TARGET_HOME" ]; then
  echo -e "${RED}Error:${RESET} no write permission to $TARGET_HOME (owner: $(stat -c %U "$TARGET_HOME" 2>/dev/null || echo unknown))" >&2
  echo "  Try: sudo -u $TARGET_USER $REPO_ROOT/install.sh ${ONLY:+--only $ONLY} ${FORCE:+--force}" >&2
  echo "  Or:  ./install.sh --user $TARGET_USER --check   (dry-run)" >&2
  exit 1
fi

# Detect if we are installing for another user (need chown hint)
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

# Where backups for this run live: $TARGET_HOME/.config/arch-setup-backups/<ts>
backup_dir_for() {
  if [ -z "$RUN_TIMESTAMP" ]; then
    RUN_TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
  fi
  echo "$TARGET_HOME/$BACKUP_ROOT/$RUN_TIMESTAMP"
}

# Move an existing dest into the central backup dir, preserving its path
# relative to TARGET_HOME. Returns 0 on success, 1 if skipped/declined.
backup_existing() {
  local dest="$1"
  if [ "$BACKUP" != 1 ]; then
    # --no-backup: just remove the existing path (nothing to keep)
    echo -e "  ${DIM}·${RESET} override $dest (--no-backup)"
    rm -rf -- "$dest"
    return 0
  fi
  local bdir
  bdir="$(backup_dir_for)"
  # Relative path from TARGET_HOME (strip leading slash)
  local rel="${dest#"$TARGET_HOME"/}"
  local bpath="$bdir/$rel"
  mkdir -p "$(dirname "$bpath")"
  if [ -d "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$bpath"
  else
    mv "$dest" "$bpath"
  fi
  echo -e "  ${YELLOW}·${RESET} backed up $dest -> ${DIM}$bpath${RESET}"
  return 0
}

# Restore a previous backup run. --restore <ts|dir> moves all backed-up
# files back to their original locations under TARGET_HOME.
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
  local f rel dest parent

  # Restore files/symlinks. Restoring deepest-first so nested paths are
  # restored before their current subtree is disturbed; parents that are
  # occupied by a symlink/file (from the install) are reconciled first so the
  # backed-up path lands back as a real directory.
  while IFS= read -r f; do
    [ -e "$f" ] || continue
    [ -f "$f" ] || [ -L "$f" ] || continue   # files & symlinks only
    rel="${f#"$bdir"/}"
    dest="$TARGET_HOME/$rel"
    parent="$(dirname "$dest")"
    # Reconcile parent if it's currently a symlink or file (installed target).
    if [ -L "$parent" ] || [ -f "$parent" ]; then
      rm -rf -- "$parent"
      mkdir -p "$parent"
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      rm -rf -- "$dest"
    fi
    mkdir -p "$(dirname "$dest")"
    mv "$f" "$dest"
    echo -e "  ${GREEN}✓${RESET} restored $dest"
  done < <(find "$bdir" \( -type f -o -type l \) | sort -r)

  echo -e "${GREEN}Done.${RESET} Restored backup $bdir"
  # Clean up empty backup dir
  rmdir "$bdir" 2>/dev/null || true
  exit 0
}

link_one() {
  local src="$1" dest="$2"
  local dest_dir
  dest_dir="$(dirname "$dest")"

  if [ "$CHECK" = 1 ]; then
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      echo -e "  ${GREEN}✓${RESET} would skip (already linked): ${DIM}$dest${RESET}"
    elif [ -e "$dest" ] || [ -L "$dest" ]; then
      echo -e "  ${YELLOW}→${RESET} would replace $dest -> $src"
    else
      echo -e "  ${GREEN}→${RESET} would link $dest -> $src"
    fi
    return
  fi

  if [ -L "$dest" ]; then
    local cur
    cur="$(readlink "$dest")"
    if [ "$cur" = "$src" ]; then
      echo -e "  ${GREEN}✓${RESET} already linked: ${DIM}$dest${RESET}"
      return
    fi
    if [ "$FORCE" = 1 ] || confirm "  Replace symlink $dest (now -> $cur) with -> $src?"; then
      backup_existing "$dest" || { echo -e "  · skipped $dest"; return; }
    else
      echo -e "  · skipped $dest"
      return
    fi
  elif [ -e "$dest" ]; then
    if [ "$FORCE" = 1 ] || confirm "  $dest exists. Backup and replace with symlink?"; then
      backup_existing "$dest" || { echo -e "  · skipped $dest"; return; }
    else
      echo -e "  · skipped $dest"
      return
    fi
  fi

  mkdir -p "$dest_dir"
  ln -s "$src" "$dest"
  echo -e "  ${GREEN}✓${RESET} linked $dest -> $src"

  # If installing for another user and we are root, fix ownership
  if [ "$IS_OTHER_USER" = 1 ] && [ "$(id -u)" = 0 ]; then
    chown -h "$TARGET_USER" "$dest" 2>/dev/null || true
    # Also chown parent dirs we created if needed (best effort)
    chown "$TARGET_USER" "$dest_dir" 2>/dev/null || true
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
  local src="$REPO_ROOT/nvim"
  local dest="$TARGET_HOME/.config/nvim"
  if [ ! -d "$src" ]; then
    echo -e "  ${RED}✗${RESET} source not found: $src" >&2
    return 1
  fi
  link_one "$src" "$dest"
}

install_zsh() {
  echo
  echo -e "${CYAN}== zsh ==${RESET}  ${DIM}$REPO_ROOT/zsh -> $TARGET_HOME/.config/zsh${RESET}"
  local src="$REPO_ROOT/zsh"
  local dest="$TARGET_HOME/.config/zsh"
  if [ ! -d "$src" ]; then
    echo -e "  ${RED}✗${RESET} source not found: $src" >&2
    return 1
  fi

  # Decide symlink strategy:
  # - If installing for current user (same owner), symlink whole directory (simple).
  # - If installing for another user from shared repo path, symlink files individually
  #   to avoid sharing writable .zsh_history (which would be inside repo and permission-denied).
  local use_file_symlinks=0
  if [ "$IS_OTHER_USER" = 1 ]; then
    # Check if source history would be shared/writable issue
    # Use file-by-file if target user differs from repo owner
    if [ "$TARGET_USER" != "$REPO_OWNER" ]; then
      use_file_symlinks=1
    fi
  fi

  if [ "$use_file_symlinks" = 1 ]; then
    echo -e "  ${DIM}→ per-file symlinks (multi-user safe, history stays per-user)${RESET}"
    if [ "$CHECK" = 1 ]; then
      echo -e "  ${GREEN}→${RESET} would create $dest and symlink files (excluding .zsh_history, .git, .gitignore)"
    else
      # If dest is already a symlink to src, replace with real dir + per-file links
      if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        if [ "$FORCE" = 1 ] || confirm "  $dest is whole-dir symlink but multi-user install needs per-file links. Replace?"; then
          rm "$dest"
          mkdir -p "$dest"
        else
          echo -e "  · skipped $dest (kept whole-dir symlink)"
          ensure_zshenv
          return
        fi
      elif [ -L "$dest" ]; then
        if [ "$FORCE" = 1 ] || confirm "  Replace existing symlink $dest?"; then
          rm "$dest"
          mkdir -p "$dest"
        else
          echo -e "  · skipped $dest"
          ensure_zshenv
          return
        fi
      elif [ -e "$dest" ] && [ ! -d "$dest" ]; then
        local backup="${dest}.backup-$(date +%s)"
        mv "$dest" "$backup"
        echo -e "  ${YELLOW}·${RESET} backed up $dest to $backup"
        mkdir -p "$dest"
      else
        mkdir -p "$dest"
      fi

      # Symlink each top-level entry excluding history and git
      local exclude_re='\.zsh_history|\.git'
      for item in "$src"/* "$src"/.*; do
        # Skip non-existent globs and . / ..
        [ -e "$item" ] || continue
        local base
        base="$(basename "$item")"
        [[ "$base" == "." || "$base" == ".." ]] && continue
        if [[ "$base" =~ $exclude_re ]]; then
          echo -e "  ${DIM}· skip $base (per-user / ignored)${RESET}"
          continue
        fi
        link_one "$item" "$dest/$base"
      done
      # Ensure history file exists as regular file per-user
      local hist="$dest/.zsh_history"
      if [ ! -e "$hist" ] && [ ! -L "$hist" ]; then
        touch "$hist"
        echo -e "  ${GREEN}✓${RESET} created empty $hist (per-user history)"
        if [ "$(id -u)" = 0 ]; then
          chown "$TARGET_USER" "$hist" 2>/dev/null || true
        fi
      fi
      if [ "$(id -u)" = 0 ]; then
        chown -R "$TARGET_USER" "$dest" 2>/dev/null || true
      fi
    fi
  else
    link_one "$src" "$dest"
  fi

  ensure_zshenv
}

install_agents() {
  echo
  echo -e "${CYAN}== agent-config ==${RESET}  ${DIM}$REPO_ROOT/agent-config${RESET}"
  local installer="$REPO_ROOT/agent-config/install.sh"
  if [ ! -f "$installer" ]; then
    echo -e "  ${RED}✗${RESET} installer not found: $installer" >&2
    return 1
  fi

  # Delegate to sub-installer with HOME overridden to TARGET_HOME
  # It already handles --force/--check and interactive agent selection.
  local args=()
  [ "$FORCE" = 1 ] && args+=(--force)
  [ "$CHECK" = 1 ] && args+=(--check)

  echo -e "  ${DIM}→ delegating to agent-config/install.sh with HOME=$TARGET_HOME ${args[*]}${RESET}"
  if [ "$CHECK" = 1 ]; then
    HOME="$TARGET_HOME" bash "$installer" "${args[@]}"
  else
    # For non-check, sub-installer is interactive for agent selection.
    # If top-level was non-interactive (--only) or --force, auto-select all agents via "a".
    local agent_input="a"
    # If we are in an interactive tty and not --force with explicit --only, let user choose
    if [ -t 0 ] && [ "$FORCE" != 1 ] && [ -z "$ONLY" ]; then
      agent_input="" # let sub-installer prompt interactively
    fi

    if [ -n "$agent_input" ]; then
      if [ "$IS_OTHER_USER" = 1 ] && [ "$(id -u)" = 0 ]; then
        printf "%s\n" "$agent_input" | runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" bash "$installer" "${args[@]}"
      else
        printf "%s\n" "$agent_input" | HOME="$TARGET_HOME" bash "$installer" "${args[@]}"
      fi
    else
      if [ "$IS_OTHER_USER" = 1 ] && [ "$(id -u)" = 0 ]; then
        runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" bash "$installer" "${args[@]}"
      else
        HOME="$TARGET_HOME" bash "$installer" "${args[@]}"
      fi
    fi
    # Fix ownership if root
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
  local src="$REPO_ROOT/hypr"
  local dest="$TARGET_HOME/.config/hypr"
  if [ ! -d "$src" ]; then
    echo -e "  ${RED}✗${RESET} source not found: $src" >&2
    return 1
  fi

  local use_file_symlinks=0
  if [ "$IS_OTHER_USER" = 1 ] && [ "$TARGET_USER" != "$REPO_OWNER" ]; then
    use_file_symlinks=1
  fi

  if [ "$CHECK" = 1 ]; then
    if [ "$use_file_symlinks" = 1 ]; then
      echo -e "  ${GREEN}→${RESET} would create $dest and symlink files (per-file strategy)"
    else
      echo -e "  ${GREEN}→${RESET} would link $dest -> $src"
    fi
    # Note if generated/local files are git-ignored at repo root (informational)
    if git -C "$REPO_ROOT" check-ignore -q "hypr/hyprlock.conf" 2>/dev/null; then
      echo -e "  ${GREEN}✓${RESET} generated/hyprlock/.luarc ignored via root .gitignore"
    fi
    return
  fi

  if [ "$use_file_symlinks" = 1 ]; then
    # Per-file strategy: skip generated(matugen output), local env, docs.
    # hyprsplit is a vendored plugin required by hyprland.lua — link it.
    local exclude_re='^\.git$|^\.gitignore$|^\.luarc\.json$|^generated$|^hyprlock\.conf$|^AGENTS\.md$|^node_modules$|^dist$|^logs\.log$|^@girs$|^\.deps$|^style$|^data$|^\.commandcode$'
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      if [ "$FORCE" = 1 ] || confirm "  $dest is whole-dir symlink; replace with per-file links?"; then
        rm "$dest"
        mkdir -p "$dest"
      else
        echo -e "  · skipped $dest (kept whole-dir symlink)"
        return
      fi
    elif [ -L "$dest" ]; then
      if [ "$FORCE" = 1 ] || confirm "  Replace existing symlink $dest?"; then
        rm "$dest"
        mkdir -p "$dest"
      else
        echo -e "  · skipped $dest"
        return
      fi
    elif [ -e "$dest" ] && [ ! -d "$dest" ]; then
      local backup="${dest}.backup-$(date +%s)"
      mv "$dest" "$backup"
      echo -e "  ${YELLOW}·${RESET} backed up $dest to $backup"
      mkdir -p "$dest"
    else
      mkdir -p "$dest"
    fi

    for item in "$src"/* "$src"/.*; do
      [ -e "$item" ] || continue
      local base
      base="$(basename "$item")"
      [[ "$base" == "." || "$base" == ".." ]] && continue
      if [[ "$base" =~ $exclude_re ]]; then
        echo -e "  ${DIM}· skip $base (per-user / ignored / local-only)${RESET}"
        continue
      fi
      link_one "$item" "$dest/$base"
    done

    if [ "$(id -u)" = 0 ]; then
      chown -R "$TARGET_USER" "$dest" 2>/dev/null || true
    fi
  else
    link_one "$src" "$dest"
  fi
}

install_ags() {
  echo
  echo -e "${CYAN}== ags ==${RESET}  ${DIM}$REPO_ROOT/ags -> $TARGET_HOME/.config/ags${RESET}"
  local src="$REPO_ROOT/ags"
  local dest="$TARGET_HOME/.config/ags"
  if [ ! -d "$src" ]; then
    echo -e "  ${RED}✗${RESET} source not found: $src" >&2
    return 1
  fi

  local use_file_symlinks=0
  if [ "$IS_OTHER_USER" = 1 ] && [ "$TARGET_USER" != "$REPO_OWNER" ]; then
    use_file_symlinks=1
  fi

  if [ "$CHECK" = 1 ]; then
    if [ "$use_file_symlinks" = 1 ]; then
      echo -e "  ${GREEN}→${RESET} would create $dest and symlink files (per-file strategy)"
    else
      echo -e "  ${GREEN}→${RESET} would link $dest -> $src"
    fi
    # Note if runtime/vendored files are git-ignored at repo root (informational)
    if git -C "$REPO_ROOT" check-ignore -q "ags/node_modules/" 2>/dev/null; then
      echo -e "  ${GREEN}✓${RESET} node_modules/@girs/dist/logs/data ignored via root .gitignore"
    fi
    return
  fi

  if [ "$use_file_symlinks" = 1 ]; then
    # Per-file strategy: skip vendor/runtime/local/build/docs/agent-config from nested repo
    local exclude_re='^\.git$|^\.gitignore$|^\.luarc\.json$|^node_modules$|^@girs$|^dist$|^logs\.log$|^data$|^\.deps$|^style$|^\.commandcode$|^AGENTS\.md$|^README\.md$|^bun\.lock$|^tsconfig\.json$|^opencode\.json$|^package\.json$|^env\.d\.ts$'
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      if [ "$FORCE" = 1 ] || confirm "  $dest is whole-dir symlink; replace with per-file links?"; then
        rm "$dest"
        mkdir -p "$dest"
      else
        echo -e "  · skipped $dest (kept whole-dir symlink)"
        return
      fi
    elif [ -L "$dest" ]; then
      if [ "$FORCE" = 1 ] || confirm "  Replace existing symlink $dest?"; then
        rm "$dest"
        mkdir -p "$dest"
      else
        echo -e "  · skipped $dest"
        return
      fi
    elif [ -e "$dest" ] && [ ! -d "$dest" ]; then
      local backup="${dest}.backup-$(date +%s)"
      mv "$dest" "$backup"
      echo -e "  ${YELLOW}·${RESET} backed up $dest to $backup"
      mkdir -p "$dest"
    else
      mkdir -p "$dest"
    fi

    for item in "$src"/* "$src"/.*; do
      [ -e "$item" ] || continue
      local base
      base="$(basename "$item")"
      [[ "$base" == "." || "$base" == ".." ]] && continue
      if [[ "$base" =~ $exclude_re ]]; then
        echo -e "  ${DIM}· skip $base (per-user / ignored / local-only)${RESET}"
        continue
      fi
      link_one "$item" "$dest/$base"
    done

    if [ "$(id -u)" = 0 ]; then
      chown -R "$TARGET_USER" "$dest" 2>/dev/null || true
    fi
  else
    link_one "$src" "$dest"
  fi
}

install_matugen() {
  echo
  echo -e "${CYAN}== matugen ==${RESET}  ${DIM}$REPO_ROOT/matugen -> $TARGET_HOME/.config/matugen${RESET}"
  local src="$REPO_ROOT/matugen"
  local dest="$TARGET_HOME/.config/matugen"
  if [ ! -d "$src" ]; then
    echo -e "  ${RED}✗${RESET} source not found: $src" >&2
    return 1
  fi
  # Matugen config (config.toml + templates/) is read-only source.
  # It regenerates outputs into hypr/ and ags/ which are symlinked separately.
  link_one "$src" "$dest"
}

install_kitty() {
  echo
  echo -e "${CYAN}== kitty ==${RESET}  ${DIM}$REPO_ROOT/kitty -> $TARGET_HOME/.config/kitty${RESET}"
  install_config_dir "kitty" "kitty"
}

install_mpv() {
  echo
  echo -e "${CYAN}== mpv ==${RESET}  ${DIM}$REPO_ROOT/mpv -> $TARGET_HOME/.config/mpv${RESET}"
  install_config_dir "mpv" "mpv"
}

install_fastfetch() {
  echo
  echo -e "${CYAN}== fastfetch ==${RESET}  ${DIM}$REPO_ROOT/fastfetch -> $TARGET_HOME/.config/fastfetch${RESET}"
  install_config_dir "fastfetch" "fastfetch"
}

install_atuin() {
  echo
  echo -e "${CYAN}== atuin ==${RESET}  ${DIM}$REPO_ROOT/atuin -> $TARGET_HOME/.config/atuin${RESET}"
  install_config_dir "atuin" "atuin"
}

# Shared installer for simple flat config dirs (kitty, mpv, ...).
# Same-user => whole-dir symlink; other-user => per-file symlinks excluding
# local-only files (.git, .gitignore, .luarc.json) so each user regenerates
# their own runtime state (e.g. mpv watch_later, kitty shell integration).
install_config_dir() {
  local module="$1" sub="${2:-$1}"
  local src="$REPO_ROOT/$module"
  local dest="$TARGET_HOME/.config/$sub"
  if [ ! -d "$src" ]; then
    echo -e "  ${RED}✗${RESET} source not found: $src" >&2
    return 1
  fi

  local use_file_symlinks=0
  if [ "$IS_OTHER_USER" = 1 ] && [ "$TARGET_USER" != "$REPO_OWNER" ]; then
    use_file_symlinks=1
  fi

  if [ "$CHECK" = 1 ]; then
    if [ "$use_file_symlinks" = 1 ]; then
      echo -e "  ${GREEN}→${RESET} would create $dest and symlink files (per-file strategy)"
    else
      echo -e "  ${GREEN}→${RESET} would link $dest -> $src"
    fi
    return
  fi

  if [ "$use_file_symlinks" = 1 ]; then
    # Per-file strategy: skip git/local-only files so each user has their own
    # runtime/editor state (kept out of the shared repo).
    local exclude_re='^\.git$|^\.gitignore$|^\.luarc\.json$'
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      rm "$dest"; mkdir -p "$dest"
    elif [ -L "$dest" ]; then
      backup_existing "$dest" || return
      mkdir -p "$dest"
    elif [ -e "$dest" ] && [ ! -d "$dest" ]; then
      backup_existing "$dest" || return
      mkdir -p "$dest"
    else
      mkdir -p "$dest"
    fi
    for item in "$src"/* "$src"/.*; do
      [ -e "$item" ] || continue
      local base
      base="$(basename "$item")"
      [[ "$base" == "." || "$base" == ".." ]] && continue
      if [[ "$base" =~ $exclude_re ]]; then
        echo -e "  ${DIM}· skip $base (local-only)${RESET}"
        continue
      fi
      link_one "$item" "$dest/$base"
    done
    if [ "$(id -u)" = 0 ]; then
      chown -R "$TARGET_USER" "$dest" 2>/dev/null || true
    fi
  else
    link_one "$src" "$dest"
  fi
}

# --- interactive selectors ---
select_target_interactive() {
  # Only prompt if neither --user nor --home was given and we are in interactive terminal
  if [ -n "$TARGET_USER" ] || [ -n "$TARGET_HOME" ] || [ ! -t 0 ]; then
    return
  fi
  if [ -n "$ONLY" ]; then
    return
  fi
  echo
  echo -e "${CYAN}Target user/home${RESET}"
  echo -e "  current: ${GREEN}$CURRENT_USER${RESET} -> $HOME"
  # Show available users (human users uid>=1000)
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
  # Re-evaluate other-user flag
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
# Block the install when a binary the selected configs actually execute is
# missing (grouped pacman/yay advice); optional deps only warn.
# In --check mode everything is reported but never blocks; --ignore-deps
# skips validation entirely.
validate_dependencies() {
  [ "$IGNORE_DEPS" = 1 ] && { echo -e "  ${DIM}· dependency validation skipped (--ignore-deps)${RESET}"; return; }

  local mod b p pkg
  local -a need=() opt=() missing=() soft=() repo_pkgs=() aur_pkgs=()
  local -A seen_need seen_opt seen_pkg

  # Required binaries per module, derived from what the configs actually exec:
  # - nvim: lazy.nvim bootstrap shells out to git; fzf-lua backends need rg/fd/fzf
  # - zsh: .zshrc runs fastfetch bare and plugins.sh evals the
  #   starship/zoxide/atuin inits (a missing one errors on every new shell);
  #   the autosuggestions/syntax-highlighting files are sourced unconditionally
  # - hypr: autostart entries, media/brightness binds, the grim/satty/wl-copy
  #   screenshot flow, ags toggle binds, kitty terminal, matugen palette
  #   (general.lua requires generated/color.lua)
  # - ags: build/typecheck (bun, sass), wallpaper daemon (awww), palette
  #   (matugen), clipboard service (cclip)
  # - mpv: mpv.conf points ytdl_hook at yt-dlp
  local nvim_need=(nvim git rg fd fzf)
  local nvim_opt=(rustc cargo tree-sitter dotnet node bun npm gh)

  local zsh_need=(zsh git starship zoxide atuin fastfetch)
  local zsh_opt=(eza bat rg fzf)

  local font_need=(fc-match)
  local hypr_need=(Hyprland hyprctl hypridle hyprlock kitty ags matugen cclip cclipd grim satty wl-copy wpctl playerctl)
  local hypr_opt=(hyprpm brightnessctl nemo gnome-keyring-daemon brave-origin)

  local ags_need=(ags bun sass awww awww-daemon matugen cclip)
  local ags_opt=(node wl-copy notify-send watchexec)

  local matugen_need=(matugen)
  local kitty_need=(kitty)
  local mpv_need=(mpv yt-dlp)
  local fastfetch_need=(fastfetch)
  local atuin_need=(atuin)

  # Binary -> Arch package (binaries not listed install under their own name).
  local -A PKG_OF=(
    [Hyprland]=hyprland [hyprctl]=hyprland [hyprpm]=hyprpm
    [nvim]=neovim [rg]=ripgrep [gh]=github-cli
    [rustc]=rustup [cargo]=rustup [tree-sitter]=tree-sitter-cli
    [dotnet]=dotnet-sdk [sass]=dart-sass [node]=nodejs
    [ags]=aylurs-gtk-shell-git [cclip]=cclip [cclipd]=cclip
    [brave-origin]=brave-origin-bin
    [awww]=awww [awww-daemon]=awww
    [wl-copy]=wl-clipboard [wpctl]=wireplumber
    [notify-send]=libnotify [yt-dlp]=yt-dlp
    [fc-match]=fontconfig
  )
  # Packages that live in the AUR (installed with yay, not pacman).
  local -A AUR_PKG=(
    [aylurs-gtk-shell-git]=1 [cclip]=1 [brave-origin-bin]=1
  )

  # zsh plugin files sourced unconditionally by scripts/plugins.sh
  # (command -v cannot see them, so they are checked as paths; the key
  # doubles as the Arch package name).
  local -A ZSH_PLUGIN=(
    [zsh-autosuggestions]=/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    [zsh-syntax-highlighting]=/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  )
  # The polkit agent is exec'd by absolute path in modules/autostart.lua
  # (also invisible to command -v), so it is only an optional check.
  local POLKIT_AGENT=/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

  # Human-readable reason shown next to each missing binary.
  local -A reason=(
    [nvim]="neovim (editor)"
    [git]="git (lazy.nvim bootstrap + git tooling)"
    [rg]="ripgrep (fzf-lua backend)"
    [fd]="fd (fzf-lua backend)"
    [fzf]="fzf (picker backend)"
    [gh]="github-cli (octo.nvim)"
    [rustc]="rustup (rust LSP toolchain)"
    [cargo]="rustup (rust LSP toolchain)"
    [tree-sitter]="tree-sitter-cli (parser installs)"
    [dotnet]="dotnet-sdk (.NET LSP)"
    [node]="nodejs (optional tooling)"
    [bun]="bun (ags build tool)"
    [npm]="npm (optional tooling)"
    [zsh]="zsh"
    [starship]="starship (prompt, eval'd by plugins.sh)"
    [zoxide]="zoxide (eval'd by plugins.sh)"
    [atuin]="atuin (eval'd by plugins.sh)"
    [fastfetch]="fastfetch (runs on every shell start)"
    [eza]="eza (ls aliases)"
    [bat]="bat (cat alias)"
    [zsh-autosuggestions]="zsh-autosuggestions (sourced by plugins.sh)"
    [zsh-syntax-highlighting]="zsh-syntax-highlighting (sourced by plugins.sh)"
    [Hyprland]="hyprland (compositor)"
    [hyprctl]="hyprland (hyprctl)"
    [hypridle]="hypridle (idle daemon, autostarted)"
    [hyprlock]="hyprlock (lock screen)"
    [hyprpm]="hyprpm (plugin manager, autostart reload)"
    [kitty]="kitty (default terminal)"
    [ags]="aylurs-gtk-shell-git (desktop shell)"
    [matugen]="matugen (Material You theming)"
    [cclip]="cclip (clipboard history)"
    [cclipd]="cclip (clipboard daemon, autostarted)"
    [grim]="grim (screenshot flow)"
    [satty]="satty (screenshot annotator)"
    [wl-copy]="wl-clipboard (screenshot + emoji copy)"
    [wpctl]="wireplumber (volume binds)"
    [playerctl]="playerctl (media binds + idle lock)"
    [brightnessctl]="brightnessctl (brightness binds)"
    [nemo]="nemo (file manager)"
    [gnome-keyring-daemon]="gnome-keyring (secrets daemon, autostarted)"
    [polkit-gnome-authentication-agent-1]="polkit-gnome (auth agent, autostarted)"
    [brave-origin]="brave-origin-bin (browser, autostarted)"
    [sass]="dart-sass (ags stylesheet compiler)"
    [awww]="awww (wallpaper painter)"
    [awww-daemon]="awww (wallpaper daemon)"
    [notify-send]="libnotify (ags toasts)"
    [watchexec]="watchexec (ags dev loop)"
    [fc-match]="fontconfig (font fallback resolution)"
    [mpv]="mpv"
    [yt-dlp]="yt-dlp (mpv ytdl_hook backend)"
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
      ags)   for b in "${ags_need[@]}" "${font_need[@]}"; do add_need "$b"; done
             for b in "${ags_opt[@]}"; do add_opt "$b"; done ;;
      hypr)  for b in "${hypr_need[@]}" "${font_need[@]}"; do add_need "$b"; done
             for b in "${hypr_opt[@]}"; do add_opt "$b"; done ;;
      kitty) for b in "${kitty_need[@]}" "${font_need[@]}"; do add_need "$b"; done ;;
      mpv)   for b in "${mpv_need[@]}"; do add_need "$b"; done ;;
      matugen) for b in "${matugen_need[@]}"; do add_need "$b"; done ;;
      fastfetch) for b in "${fastfetch_need[@]}"; do add_need "$b"; done ;;
      atuin) for b in "${atuin_need[@]}"; do add_need "$b"; done ;;
    esac
  done

  for b in "${need[@]}"; do
    if ! command -v "$b" >/dev/null 2>&1; then missing+=("$b"); fi
  done
  for b in "${opt[@]}"; do
    if ! command -v "$b" >/dev/null 2>&1; then soft+=("$b"); fi
  done

  # Path-checked deps (invisible to command -v): zsh plugin files are
  # required, the polkit agent path is optional.
  if [[ " $* " == *" zsh "* ]]; then
    for p in "${!ZSH_PLUGIN[@]}"; do
      [ -f "${ZSH_PLUGIN[$p]}" ] || missing+=("$p")
    done
  fi
  if [[ " $* " == *" hypr "* ]]; then
    [ -x "$POLKIT_AGENT" ] || soft+=("polkit-gnome-authentication-agent-1")
  fi

  if ((${#missing[@]})); then
    echo
    echo -e "${RED}✗ Missing required packages/binaries:${RESET}"
    for b in "${missing[@]}"; do
      echo -e "  ${RED}•${RESET} ${YELLOW}$b${RESET} (${reason[$b]:-$b})"
    done
    if [ "$CHECK" = 1 ]; then
      echo -e "  ${DIM}(dry-run: reported only, not blocking)${RESET}"
    else
      # Group missing binaries by Arch package and source (repo vs AUR).
      for b in "${missing[@]}"; do
        pkg="${PKG_OF[$b]:-$b}"
        if [[ -z "${seen_pkg[$pkg]:-}" ]]; then
          seen_pkg[$pkg]=1
          if [[ -n "${AUR_PKG[$pkg]:-}" ]]; then aur_pkgs+=("$pkg"); else repo_pkgs+=("$pkg"); fi
        fi
      done
      if ((${#repo_pkgs[@]})); then
        echo -e "  ${DIM}Install repo packages:${RESET}"
        echo -e "    ${CYAN}sudo pacman -S ${repo_pkgs[*]}${RESET}"
      fi
      if ((${#aur_pkgs[@]})); then
        if command -v yay >/dev/null 2>&1; then
          echo -e "  ${DIM}Install AUR packages:${RESET}"
          echo -e "    ${CYAN}yay -S ${aur_pkgs[*]}${RESET}"
        else
          echo -e "  ${RED}✗${RESET} ${YELLOW}yay${RESET} is required for AUR packages (${aur_pkgs[*]}) but is not installed."
          echo -e "  ${DIM}Install yay first (https://github.com/Jguer/yay#installation), then:${RESET}"
          echo -e "    ${CYAN}yay -S ${aur_pkgs[*]}${RESET}"
        fi
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

  # Config-chain validation: files the dotfiles require at load time.
  local fail=0
  if [[ " $* " == *" nvim "* ]]; then
    if [ -f "$REPO_ROOT/nvim/init.lua" ] && [ -f "$REPO_ROOT/nvim/lua/config/lazy.lua" ]; then
      echo -e "  ${GREEN}✓${RESET} nvim config chain resolves (init.lua → config.lazy)"
    else
      echo -e "  ${YELLOW}⚠${RESET} nvim config chain broken (missing init.lua or lua/config/lazy.lua)" >&2
      fail=1
    fi
  fi
  if [[ " $* " == *" hypr "* ]]; then
    if [ -f "$REPO_ROOT/hypr/generated/color.lua" ]; then
      echo -e "  ${GREEN}✓${RESET} hypr theme output present (generated/color.lua)"
    else
      echo -e "  ${RED}✗${RESET} hypr/generated/color.lua missing — general.lua requires it at load." >&2
      echo -e "  ${DIM}Generate it with: matugen image ~/Pictures/Wallpapers/<wallpaper>${RESET}" >&2
      fail=1
    fi
  fi
  if [[ " $* " == *" ags "* ]]; then
    if [ -f "$REPO_ROOT/ags/style/abstracts/_matugen.scss" ]; then
      echo -e "  ${GREEN}✓${RESET} ags palette present (style/abstracts/_matugen.scss)"
    else
      echo -e "  ${RED}✗${RESET} ags/style/abstracts/_matugen.scss missing — sass compile fails without it." >&2
      echo -e "  ${DIM}Generate it with: matugen image ~/Pictures/Wallpapers/<wallpaper>${RESET}" >&2
      fail=1
    fi
  fi
  if [ "$fail" = 1 ] && [ "$CHECK" != 1 ]; then
    echo -e "  ${DIM}Re-run with --ignore-deps to force.${RESET}"
    exit 1
  fi
}

select_modules_interactive() {
  local all_modules=("agent-config" "nvim" "zsh" "hypr" "ags" "matugen" "kitty" "mpv" "fastfetch" "atuin")
  local selected=()

  # If --only provided, parse it
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
    # dedupe
    local -A seen=()
    local dedup=()
    for m in "${selected[@]}"; do
      if [[ -z "${seen[$m]:-}" ]]; then seen[$m]=1; dedup+=("$m"); fi
    done
    selected=("${dedup[@]}")
    SELECTED_MODULES=("${selected[@]}")
    return
  fi

  # Non-interactive if not a tty: default to all
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
echo -e "${CYAN}arch-setup${RESET} ${DIM}$REPO_ROOT${RESET}"
echo -e "target: ${GREEN}$TARGET_USER${RESET} -> $TARGET_HOME ${IS_OTHER_USER:+${DIM}(other user)${RESET}}"
if [ "$CHECK" = 1 ]; then
  echo -e "${YELLOW}mode: dry-run (--check)${RESET}"
elif [ "$FORCE" = 1 ]; then
  echo -e "${YELLOW}mode: force (--force)${RESET}"
fi
if [ ! -w "$TARGET_HOME" ] && [ "$CHECK" != 1 ]; then
  echo -e "${YELLOW}Warning: target not writable; will prompt or fail per file${RESET}"
fi

# --restore mode: restore a previous backup, then stop (no install)
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

# Validate required packages for the selected modules before any changes.
validate_dependencies "${SELECTED_MODULES[@]}"

echo
echo -e "Will install: ${GREEN}${SELECTED_MODULES[*]}${RESET} for ${GREEN}$TARGET_USER${RESET}"
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
  echo -e "${GREEN}Done.${RESET} Installed ${SELECTED_MODULES[*]} for $TARGET_USER ($TARGET_HOME)"
  if [[ " ${SELECTED_MODULES[*]} " == *" zsh "* ]]; then
    echo -e "  ${DIM}→ restart zsh or run: exec zsh${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" nvim "* ]]; then
    echo -e "  ${DIM}→ nvim config linked; run nvim to install plugins${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" agent-config "* ]]; then
    echo -e "  ${DIM}→ agent skills linked; restart your agent${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" hypr "* ]]; then
    echo -e "  ${DIM}→ hypr config linked; run hyprctl reload or restart Hyprland${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" ags "* ]]; then
    echo -e "  ${DIM}→ ags config linked; run ags run or ags toggle${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" matugen "* ]]; then
    echo -e "  ${DIM}→ matugen config linked; run: matugen image <wallpaper.png> to regenerate theme${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" kitty "* ]]; then
    echo -e "  ${DIM}→ kitty config linked; restart kitty${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" mpv "* ]]; then
    echo -e "  ${DIM}→ mpv config linked; restart mpv${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" fastfetch "* ]]; then
    echo -e "  ${DIM}→ fastfetch config linked; run fastfetch${RESET}"
  fi
  if [[ " ${SELECTED_MODULES[*]} " == *" atuin "* ]]; then
    echo -e "  ${DIM}→ atuin config linked; restart your shell${RESET}"
  fi
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
