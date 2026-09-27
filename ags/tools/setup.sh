#!/usr/bin/env bash
# One-time / repeatable environment setup:
#
#  1. Vendors the system ags runtime into .deps/ags.
#  2. Links it as node_modules/ags: bun cannot express ags init's npm
#     symlink, and tsc follows this path for the ags/* module types.
#  3. Regenerates @girs when missing.
#
# Re-run any time; it always re-copies from the system runtime so the
# vendored copy can never go stale.
set -euo pipefail
cd "$(dirname "$0")/.."

AGS_RUNTIME="${AGS_RUNTIME:-/usr/share/ags/js}"

if [ ! -d "$AGS_RUNTIME" ]; then
    echo "error: ags runtime not found at $AGS_RUNTIME" >&2
    exit 1
fi

echo "vendoring $AGS_RUNTIME -> .deps/ags"
rm -rf .deps
mkdir -p .deps
cp -a "$AGS_RUNTIME" .deps/ags

ln -sfn ../.deps/ags node_modules/ags

if [ ! -d @girs ]; then
    echo "generating @girs (this can take a minute)…"
    ags types
fi

echo "setup: OK"
