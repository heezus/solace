extends RefCounted
## Map drawing for huts and the tiles they reach: while a field is laid or hovered, each hut that reaches it is outlined
## and its reach is shaded, so "which hut reaps this" is on the map and not only in the Info panel. Static.

const Data = preload("res://scripts/data.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Patch = preload("res://scripts/patch.gd")


## Outline every hut that reaches tile `p` and shade the ground it reaches (the same box the hut shows on hover).
static func draw_huts_reaching(ci: CanvasItem, s, p: Vector2i) -> void:
	var r: int = s.town.hut_radius()
	for b in Patch.huts_reaching(s, p):
		var hp: Vector2i = b["pos"]
		var reach := Rect2(Overlays.rect(hp - Vector2i(r, r)).position, Overlays.rect(hp).size * float(2 * r + 1))
		ci.draw_rect(reach, Color(Ui.HIGHLIGHT, 0.12))
		Art.dashed_rect(ci, reach, Ui.HIGHLIGHT, 2.0 * Art.ui_k, 10.0 * Art.ui_k, 6.0 * Art.ui_k)
		ci.draw_rect(Overlays.rect(hp).grow(2), Ui.HIGHLIGHT, false, 3.0)
