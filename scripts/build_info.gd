extends RefCounted
## Which build this is, for the corner of the title screen and the pause menu: the version, the day it was built and the
## commit it was built from. DATE and COMMIT stay "dev" in the repo; the desktop build workflow (.github/workflows/release.yml)
## writes this file with the real values just before it exports, so a downloaded build says what it is.

const VERSION := "v0.1"
const DATE := "dev"
const COMMIT := "dev"


## "v0.1 · 2026-10-14 · a1b2c3d", or "v0.1 · dev build" when it was run from the project.
static func line() -> String:
	if DATE == "dev" or COMMIT == "dev":
		return "%s · dev build" % VERSION
	return "%s · %s · %s" % [VERSION, DATE, COMMIT]


## The small dim label the menus show it in.
static func label(size: int) -> Label:
	var l := Label.new()
	l.text = line()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
