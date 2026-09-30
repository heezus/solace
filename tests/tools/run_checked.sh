#!/usr/bin/env bash
# Run a Godot command and fail if it fails or prints any ERROR, SCRIPT ERROR, WARNING or Parse Error line.
# Usage: tests/tools/run_checked.sh <command...>
# Only the display-driver lines of a headless CI box are allowed (they come from the machine, not the
# game): no V-Sync control, and no 2D MSAA under the OpenGL fallback renderer.
set -uo pipefail
log=$(mktemp)
"$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
allowed='Could not set V-Sync mode|2D MSAA is not yet supported for GLES3'
if grep -E "ERROR|WARNING|Parse Error" "$log" | grep -vE "$allowed" | grep -q .; then
	echo "::error::Godot printed errors or warnings:"
	grep -nE "ERROR|WARNING|Parse Error" "$log" | grep -vE "$allowed"
	exit 1
fi
exit "$status"
