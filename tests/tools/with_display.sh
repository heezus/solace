#!/usr/bin/env bash
# Run a command with a display: under xvfb on a Linux box with no screen, straight through on a Mac (which has one).
# Usage: tests/tools/with_display.sh <command...>
if command -v xvfb-run >/dev/null 2>&1 && [ -z "${DISPLAY:-}" ]; then
	exec xvfb-run -a -s "-screen 0 1280x800x24" "$@"
fi
exec "$@"
