#!/usr/bin/env bash
# screenshot.sh — full-screen capture piped into Satty for crop/annotate.
# --fullscreen opens Satty true-fullscreen (whitelisted in
# modules/fullscreen.lua). Ctrl+S saves + closes Satty (--early-exit
# save), then the saved file is copied to the clipboard here.
# Esc cancels, saving nothing.
set -euo pipefail

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
save_target="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

grim -t ppm - | satty --filename - --fullscreen \
  --output-filename "$save_target" --early-exit save

if [ -f "$save_target" ]; then
  wl-copy --type image/png < "$save_target"
fi
