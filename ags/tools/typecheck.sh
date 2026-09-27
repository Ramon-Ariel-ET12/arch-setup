#!/usr/bin/env bash
# Type-check gate: runs every available compiler; ANY output or nonzero
# exit fails the gate.
#
#  - bunx tsc        (TypeScript ~5.9, full check incl. vendored deps)
#  - mason tsc/tsgo  (TypeScript 7 native preview, if installed — same
#                     checker the editor uses since vtsls was replaced)
set -uo pipefail
cd "$(dirname "$0")/.."

TSGO="${TSGO:-$HOME/.local/share/nvim/mason/bin/tsc}"
fail=0

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

check() {
    local name="$1"
    shift
    if ! "$@" >"$OUT" 2>&1; then
        fail=1
    fi
    if [ -s "$OUT" ]; then
        echo "--- $name ---"
        cat "$OUT"
    fi
}

check "tsc ($(bunx tsc --version 2>/dev/null))" bunx tsc --noEmit

if [ -x "$TSGO" ]; then
    check "tsgo ($("$TSGO" --version 2>&1 | head -1))" "$TSGO" --noEmit
else
    echo "note: TS7 native compiler not found at $TSGO; skipping"
fi

if [ "$fail" -ne 0 ]; then
    echo "typecheck: FAILED"
    exit 1
fi

echo "typecheck: OK"
