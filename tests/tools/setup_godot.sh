#!/usr/bin/env bash
# Put Godot at ./godot, downloading it only the first time on a machine (CI runs on one Mac that stays up, so every later run
# reuses the copy in ~/.cache/solace). Works on Linux and macOS. With "templates" it also installs the export templates the
# desktop builds need.
# Usage: tests/tools/setup_godot.sh [templates]     (GODOT_VERSION defaults to 4.7.2)
set -euo pipefail
version="${GODOT_VERSION:-4.7.2}"
cache="${SOLACE_CACHE:-$HOME/.cache/solace}/godot-$version"
base="https://github.com/godotengine/godot/releases/download/$version-stable"
cd "$(dirname "$0")/../.."

case "$(uname -s)" in
Darwin)
	archive="Godot_v$version-stable_macos.universal.zip"
	binary="$cache/Godot.app/Contents/MacOS/Godot"
	templates_dir="$HOME/Library/Application Support/Godot/export_templates"
	;;
Linux)
	archive="Godot_v$version-stable_linux.x86_64.zip"
	binary="$cache/godot"
	templates_dir="$HOME/.local/share/godot/export_templates"
	;;
*)
	echo "Unsupported system: $(uname -s)" >&2
	exit 1
	;;
esac

if [ ! -x "$binary" ]; then
	mkdir -p "$cache"
	tmp="$(mktemp -d)"
	curl -sSL --fail -o "$tmp/godot.zip" "$base/$archive"
	unzip -q "$tmp/godot.zip" -d "$tmp/out"
	if [ "$(uname -s)" = Darwin ]; then
		rm -rf "$cache/Godot.app"
		mv "$tmp/out/Godot.app" "$cache/Godot.app"
		xattr -cr "$cache/Godot.app" 2>/dev/null || true  # no quarantine flag, so Gatekeeper never asks
	else
		mv "$tmp/out/Godot_v$version-stable_linux.x86_64" "$binary"
	fi
	rm -rf "$tmp"
fi

# ./godot is a one-line launcher, so every step can say ./godot whatever the system.
printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "$binary" > godot
chmod +x godot

if [ "${1:-}" = templates ] && [ ! -d "$templates_dir/$version.stable" ]; then
	tmp="$(mktemp -d)"
	curl -sSL --fail -o "$tmp/templates.tpz" "$base/Godot_v$version-stable_export_templates.tpz"
	unzip -q "$tmp/templates.tpz" -d "$tmp/out"
	mkdir -p "$templates_dir"
	mv "$tmp/out/templates" "$templates_dir/$version.stable"
	rm -rf "$tmp"
fi

./godot --version
