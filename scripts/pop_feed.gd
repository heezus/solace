extends RefCounted
## Short texts the simulation floats up over the Hearth ("-1 Charcoal" from a season, "+6 trust" from the Lumen): the blocks
## keep a `pops` list, and main takes them every frame as map popups, one line above the last.

const Ui = preload("res://scripts/ui.gd")


## Empty every block's `pops` and return them as popup dictionaries around `at` (what main's popups list takes).
static func drain(s, at: Vector2) -> Array:
	var out: Array = []
	for source in [[s.seasons.pops, Ui.SHORT], [s.starfall.pops, Ui.GOOD]]:
		for text in source[0]:
			out.append({"pos": at - Vector2(0, 16 * out.size()), "text": text, "t": 0.0, "col": source[1]})
		source[0].clear()
	return out
