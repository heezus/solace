#!/usr/bin/env bash
# Import the project with Godot, retrying when Godot itself crashes. On the Mac runner the first import of a fresh checkout
# sometimes dies with a segfault in a worker thread (exit 139, no error line, seen once at a font import); a second go on a clean
# cache passes. A failure that prints errors or exits with a plain status is not retried.
# Usage: tests/tools/import_project.sh [godot]
godot="${1:-./godot}"
cd "$(dirname "$0")/../.."
for attempt in 1 2 3; do
	tests/tools/run_checked.sh "$godot" --headless --path . --import
	status=$?
	[ "$status" -eq 0 ] && exit 0
	[ "$status" -ge 128 ] || exit "$status"
	echo "::warning::Godot crashed during import (exit $status), attempt $attempt of 3"
	rm -rf .godot
done
exit 1
