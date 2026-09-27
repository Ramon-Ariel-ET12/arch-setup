#!/usr/bin/env bash
# Dev loop: restart `ags run` on any source/style change and log to logs.log.
# This file is the single home for the dev command (`bun run dev` wraps it).
# Requires watchexec (pacman -S watchexec).

set -euo pipefail
cd "$(dirname "$0")/.."

: > logs.log
export AGS_DEBUG=1
watchexec -c -w . -r \
    -e tsx,ts,scss \
    -i "**/node_modules/**" \
    -i "**/@girs/**" \
    -i "**/dist/**" \
    -i "logs.log" \
    -i "_matugen.scss" \
    -i "_hyprland.scss" \
    -- 'echo "" > logs.log ; ags run 2>&1' 2>&1 | tee -a logs.log