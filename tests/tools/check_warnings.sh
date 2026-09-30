#!/usr/bin/env bash
# Fail on any GDScript warning the Godot editor would show. Usage: tests/tools/check_warnings.sh [godot]
set -euo pipefail
GODOT="${1:-godot}"
cd "$(dirname "$0")/../.."
log=$(mktemp)
trap 'rm -f override.cfg "$log"' EXIT
names=$("$GODOT" --headless --path . -s tests/tools/check_warnings.gd -- list | grep '^gdscript/warnings/')
{
	echo "[debug]"
	for n in $names; do echo "$n=2"; done
} > override.cfg
"$GODOT" --headless --path . -s tests/tools/check_warnings.gd 2>&1 | tee "$log"
! grep -E "ERROR|WARNING|Parse Error" "$log"
