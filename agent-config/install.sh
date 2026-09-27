#!/usr/bin/env bash
#
# install.sh — link agent-config into Claude Code, OpenCode, Command Code, and/or pi.
#
# Uses symlinks instead of copies, so the canonical files stay in this directory
# and every agent always sees the same content.
#
# Native Windows (no WSL)? This script needs bash — run install.ps1 instead
#
# Memory file locations (official docs):
#   Claude Code   ~/.claude/CLAUDE.md           https://code.claude.com/docs/en/memory
#   OpenCode      ~/.config/opencode/AGENTS.md  https://opencode.ai/v2/docs/instructions
#   Command Code  ~/.commandcode/AGENTS.md      https://commandcode.ai/docs/memory
#   pi            ~/.pi/agent/AGENTS.md         https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md#context-files
#
# Skills locations (official docs):
#   Claude Code   ~/.claude/skills/             https://code.claude.com/docs/en/skills
#   OpenCode      ~/.config/opencode/skills/    https://opencode.ai/v2/docs/skills
#   Command Code  ~/.commandcode/skills/        https://commandcode.ai/docs/skills
#   pi            ~/.pi/agent/skills/           https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md#skills
#
# Config file locations (official docs):
#   Claude Code   ~/.claude/settings.json       https://code.claude.com/docs/en/settings
#   OpenCode      ~/.config/opencode/opencode.json  https://opencode.ai/docs/config
#   Command Code  ~/.commandcode/settings.json  https://commandcode.ai/docs
#   pi            ~/.pi/agent/settings.json     https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/settings.md
#
# Usage:
#   ./install.sh             interactive selection
#   ./install.sh --force     replace existing files/symlinks without asking
#   ./install.sh --check     dry run: show what would be installed
#   ./install.sh --help      show this help
#
# Skill directories in skills/ (each must contain a SKILL.md) are linked
# one-by-one, so adding a new skill later only requires re-running this script.

set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY_SRC="$CONFIG_DIR/AGENTS.md"

FORCE=0
CHECK=0
# Indices into AGENTS selected by the user (empty = none selected).
SELECTED_IDX=()

# agent|label|memory dir|memory file name|skills dir|config source|config dest
AGENTS=(
  "claude-code|Claude Code|$HOME/.claude|CLAUDE.md|$HOME/.claude/skills|claude-code/settings.json|$HOME/.claude/settings.json"
  "opencode|OpenCode|$HOME/.config/opencode|AGENTS.md|$HOME/.config/opencode/skills|opencode/opencode.json|$HOME/.config/opencode/opencode.json"
  "command-code|Command Code|$HOME/.commandcode|AGENTS.md|$HOME/.commandcode/skills|command-code/settings.json|$HOME/.commandcode/settings.json"
  "pi|pi|$HOME/.pi/agent|AGENTS.md|$HOME/.pi/agent/skills|pi/settings.json|$HOME/.pi/agent/settings.json"
)

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

  --force    replace existing files/symlinks without asking
  --check    dry run: show what would be installed, change nothing
  --help     show this help

Without options, the script prompts for which agents to configure.
EOF
  exit 0
}

while (($#)); do
  case "$1" in
    --force) FORCE=1 ;;
    --check) CHECK=1 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
  shift
done

confirm() {
  local ans
  read -r -p "$1 [y/N] " ans
  [[ "${ans,,}" == y* ]]
}

link_one() {
  local src="$1" dest="$2"

  if [ "$CHECK" = 1 ]; then
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      echo "  ✓ would skip (already linked): $dest"
    else
      echo "  → would link $dest -> $src"
    fi
    return
  fi

  if [ -L "$dest" ]; then
    local cur
    cur="$(readlink "$dest")"
    if [ "$cur" = "$src" ]; then
      echo "  ✓ already linked: $dest"
      return
    fi
    if [ "$FORCE" = 1 ] || confirm "  Replace existing symlink $dest (currently -> $cur)?"; then
      rm "$dest"
    else
      echo "  · skipped $dest"
      return
    fi
  elif [ -e "$dest" ]; then
    if [ "$FORCE" = 1 ] || confirm "  $dest already exists. Back it up and symlink?"; then
      local backup="${dest}.backup-$(date +%s)"
      mv "$dest" "$backup"
      echo "  · backed up to $backup"
    else
      echo "  · skipped $dest"
      return
    fi
  fi

  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  echo "  ✓ linked $dest -> $src"
}

install_agent() {
  IFS='|' read -r id label memdir memname skillsdir cfgsrc cfgdest <<<"$1"

  echo
  echo "== $label =="
  link_one "$MEMORY_SRC" "$memdir/$memname"

  if [ -n "$cfgsrc" ] && [ -n "$cfgdest" ]; then
    if [ -f "$CONFIG_DIR/$cfgsrc" ]; then
      link_one "$CONFIG_DIR/$cfgsrc" "$cfgdest"
    else
      echo "  (config not found: $cfgsrc)"
    fi
  fi

  if [ "$id" = "pi" ] && [ -d "$CONFIG_DIR/pi" ]; then
    # Mirror everything under pi/ into the live dir, so new configs
    # (agents, themes, ...) deploy without touching this script.
    # Exceptions: package.json lives at npm/package.json, and settings.json
    # is already linked by the generic config step above.
    if [ -f "$CONFIG_DIR/pi/package.json" ]; then
      link_one "$CONFIG_DIR/pi/package.json" "$memdir/npm/package.json"
    fi
    # One-time migration: a previous version of this script linked agents
    # per-file instead of linking the directory.
    if [ -e "$memdir/agents" ] && [ ! -L "$memdir/agents" ]; then
      for old in "$memdir/agents"/*.md; do
        [ -L "$old" ] || continue
        case "$(readlink "$old")" in
          "$CONFIG_DIR/pi/agents/"*) rm "$old" && echo "  · removed legacy link $old" ;;
        esac
      done
      rmdir "$memdir/agents" 2>/dev/null || true
    fi
    for src in "$CONFIG_DIR"/pi/*; do
      [ -e "$src" ] || continue
      case "$(basename "$src")" in
        package.json|settings.json) continue ;;
      esac
      link_one "$src" "$memdir/$(basename "$src")"
    done
  fi

  if ((${#SKILLS[@]})); then
    for skill in "${SKILLS[@]}"; do
      link_one "$skill" "$skillsdir/$(basename "$skill")"
    done
  else
    echo "  (no skills found in $CONFIG_DIR/skills)"
  fi
}

select_agents() {
  while true; do
    echo "Install for which agents?"
    local i=1
    for entry in "${AGENTS[@]}"; do
      IFS='|' read -r id label _ _ _ <<<"$entry"
      printf '  %d) %s\n' "$i" "$label"
      i=$((i + 1))
    done
    printf '  a) All agents\n  (empty = install nothing)\n'
    if ! read -r -p "> " input; then
      return 0   # EOF on stdin: treat as "install nothing"
    fi

    input="${input,,}"
    if [[ "$input" == a* ]]; then
      SELECTED_IDX=( "${!AGENTS[@]}" )
      return
    fi
    [ -n "$input" ] || return 0

    local -a idxs=()
    local ok=1 token
    for token in $input; do
      if [[ "$token" =~ ^[0-9]+$ ]] && ((token >= 1 && token <= ${#AGENTS[@]})); then
        idxs+=("$((token - 1))")
      else
        echo "  Invalid selection: $token"
        ok=0
        break
      fi
    done
    if ((ok)); then
      # de-duplicate while preserving order
      local -A seen=()
      SELECTED_IDX=()
      for t in "${idxs[@]}"; do
        if [[ -z "${seen[$t]:-}" ]]; then
          seen[$t]=1
          SELECTED_IDX+=("$t")
        fi
      done
      return
    fi
  done
}

# --- gather skills -----------------------------------------------------------

SKILLS=()
for skill in "$CONFIG_DIR"/skills/*/SKILL.md; do
  [ -e "$skill" ] || continue
  SKILLS+=("${skill%/SKILL.md}")
done

# --- main ---------------------------------------------------------------------

if [ ! -f "$MEMORY_SRC" ]; then
  echo "Error: memory file not found: $MEMORY_SRC" >&2
  exit 1
fi

echo "agent-config: $CONFIG_DIR"
printf 'memory file:  %s\n' "$MEMORY_SRC"
if ((${#SKILLS[@]})); then
  skill_names=()
  for s in "${SKILLS[@]}"; do
    skill_names+=("$(basename -- "$s")")
  done
  printf 'skills:       %s\n' "${skill_names[*]}"
else
  echo 'skills:       (none)'
fi
if [ -d "$CONFIG_DIR/pi" ]; then
  pi_names=()
  for p in "$CONFIG_DIR"/pi/*; do
    [ -e "$p" ] || continue
    case "$(basename "$p")" in
      package.json|settings.json) continue ;;
    esac
    pi_names+=("$(basename -- "$p")")
  done
  if ((${#pi_names[@]})); then
    printf 'pi extra:     %s (mirrored)\n' "${pi_names[*]}"
  else
    echo 'pi extra:     (none)'
  fi
else
  echo 'pi extra:     (none)'
fi

if [ "$CHECK" = 1 ]; then
  echo
  echo "Dry run: nothing will be changed."
  SELECTED_IDX=( "${!AGENTS[@]}" )
else
  select_agents
fi

if ((${#SELECTED_IDX[@]})); then
  for idx in "${SELECTED_IDX[@]}"; do
    install_agent "${AGENTS[$idx]}"
  done
  echo
  if [ "$CHECK" = 1 ]; then
    echo "Done (dry run — no changes made)."
  else
    echo "Done. Changes take effect on the next session; restart your agent if it is running."
  fi
else
  echo
  echo "Nothing selected — no changes made."
fi