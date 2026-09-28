#!/usr/bin/env bash

set -euo pipefail

readonly SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
readonly OUTPUT_FILE="$SCREENSHOT_DIR/$(date '+%Y-%m-%d_%H-%M-%S').png"

mkdir -p -- "$SCREENSHOT_DIR"

grim -t ppm - |
  GSK_RENDERER=gl satty \
    --filename - \
    --fullscreen=current-screen \
    --output-filename "$OUTPUT_FILE" \
    --early-exit=save

if [[ -f "$OUTPUT_FILE" ]]; then
  wl-copy --type image/png <"$OUTPUT_FILE"
fi
