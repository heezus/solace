extends RefCounted
## Draws a home's scaffold on the map, from HomeLook.state: Codex's open scaffold over the house, with a bar under it that fills
## as the materials arrive and then as the build goes. The tier itself is the house art (GrowthArt.draw_house, called by the map
## in place of the Dwelling sprite). Static; draws on any CanvasItem.

const Art = preload("res://scripts/art.gd")
const GrowthArt = preload("res://scripts/growth_art.gd")
const HomeLook = preload("res://scripts/home_look.gd")
const Ui = preload("res://scripts/ui.gd")


## Draw home `b`'s scaffold in tile rect `r`, if one stands.
static func draw(ci: CanvasItem, b: Dictionary, r: Rect2) -> void:
	var look := HomeLook.state(b)
	if not look["scaffold"]:
		return
	GrowthArt.draw_scaffold(ci, r)
	var bar := Rect2(r.position + Vector2(r.size.x * 0.1, r.size.y * 0.8), Vector2(r.size.x * 0.8, r.size.y * 0.1))
	ci.draw_rect(bar, Art.OUTLINE)
	var frac: float = look["fill"] * 0.5  # the first half of the bar is the materials arriving, the second the build
	if look["site"] == "building":
		frac = 0.5 + look["progress"] * 0.5
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Ui.HIGHLIGHT)
