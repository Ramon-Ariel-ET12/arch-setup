#!/usr/bin/env bash
# Regenerate the GI type definitions (@girs/) from the installed runtimes.
# This file is the single home for the types command (`bun run types` wraps it).

set -euo pipefail
cd "$(dirname "$0")/.."

ags types