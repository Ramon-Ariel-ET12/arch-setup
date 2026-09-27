#!/usr/bin/env bash
# Production-style build: type-check, then compile the stylesheet.
# This file is the single home for the build command (`bun run build` wraps it).

set -euo pipefail
cd "$(dirname "$0")/.."

bunx tsc --noEmit
sass style/main.scss dist/style.css --style=expanded --no-source-map --no-charset