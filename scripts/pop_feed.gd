extends RefCounted
## Short texts the simulation floats up over the Hearth ("-1 Charcoal" from a season, "+6 trust" from the Lumen): the blocks
## keep a `pops` list, and main takes them every frame as map popups, one line above the last.

const Art = preload("res://scripts/art.gd")
const KinName = preload("res://scripts/kin_name.gd")
const Ui = preload("res://scripts/ui.gd")

const LIFE := 1.2  # seconds a popup floats before it is gone


## Empty every block's `pops` and return them as popup dictionaries around `at` (what main's popups list takes).
static func drain(s, at: Vector2) -> Array:
	var out: Array = []
	for source in [[s.seasons.pops, Ui.SHORT], [s.starfall.pops, Ui.GOOD]]:
		for text in source[0]:
			out.append({"pos": at - Vector2(0, 16 * out.size()), "text": text, "t": 0.0, "col": source[1]})
		source[0].clear()
	return out


## Draw the popups of `ci` (main's list: pos, text, t, col) rising and fading over their LIFE.
static func draw(ci: CanvasItem, popups: Array) -> void:
	var font := ThemeDB.fallback_font
	for pop in popups:
		var pos: Vector2 = pop["pos"] + Vector2(-20, -10 - pop["t"] * 30) * Art.ui_k
		var a: float = 1.0 - pop["t"] / LIFE
		var px := roundi(16.0 * Art.ui_k)
		var text := KinName.say(pop["text"])
		ci.draw_string_outline(
			font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, roundi(5.0 * Art.ui_k), Color(Art.OUTLINE, a)
		)
		var col: Color = pop.get("col", Ui.TEXT)
		ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, a))
