#!/usr/bin/env bash
# test/qmlSmoke.sh -- real-engine (Qt V4) smoke check.
#
# Why this exists: every other suite in test/ runs under Node (V8). That is not
# enough. Qt's V4 JS engine silently no-ops `\p{L}` Unicode property escapes,
# so slugify() was green under Node for the whole plan while being broken in
# the shipped app; and QML-side errors (cyclic type dependencies, missing
# imports, non-existent properties like font.families) never reach Node at all.
#
# This is deliberately coarse: boot the real binary headless and fail if the
# log contains any known-bad pattern. It is a smoke check, not a QML test
# framework.
#
# Usage: ./test/qmlSmoke.sh     (exit 0 = clean, exit 1 = bad pattern found)

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BINARY="$REPO_ROOT/build/desktop-stickers"

if [ ! -x "$BINARY" ]; then
    echo "qmlSmoke: no binary at $BINARY -- run 'cmake --build build' first." >&2
    exit 1
fi

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
export XDG_DATA_HOME="$TMP_ROOT/data"
export XDG_CONFIG_HOME="$TMP_ROOT/config"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"

# Seed real sample content, including the full demo document as sticker 004.
"$REPO_ROOT/scripts/test-sticker.sh" >/dev/null 2>&1 || {
    echo "qmlSmoke: scripts/test-sticker.sh failed" >&2
    exit 1
}

LOG="$TMP_ROOT/stderr.log"

# The app is a background daemon -- it never exits on its own, so `timeout`
# killing it after startup is the expected outcome, not a failure. We only
# care about what it logged on the way up. QT_FORCE_STDERR_LOGGING=1 is
# essential: without it QML errors are swallowed entirely.
QT_FORCE_STDERR_LOGGING=1 \
QT_QPA_PLATFORM=offscreen \
timeout 8 dbus-run-session -- "$BINARY" >"$LOG" 2>&1

BAD_PATTERN="is not a type|unavailable|TypeError|Binding loop|Cyclic dependency"

if grep -qE "$BAD_PATTERN" "$LOG"; then
    echo "FAIL qmlSmoke: QML engine reported problems at startup:" >&2
    grep -nE "$BAD_PATTERN" "$LOG" >&2
    exit 1
fi

echo "PASS qmlSmoke: app started clean under the real Qt/V4 engine"
exit 0
