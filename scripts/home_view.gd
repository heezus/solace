extends RefCounted
## Draws a home's tier and scaffold on the map, from HomeLook.state, until Codex's tier and scaffold art lands: a Homestead
## and a Longhouse wear a tinted roof band and pips over the Dwelling sprite, and a scaffold is a hatched wash with
## crossed beams and a bar that fills as the materials arrive and then as the build goes. Static; draws on any CanvasItem.

const Art = preload("res://scripts/art.gd")
const HomeLook = preload("res://scripts/home_look.gd")
const Ui = preload("res://scripts/ui.gd")

## The roof band of each tier (none for a Dwelling).
const TIER_TINTS := [Color(0, 0, 0, 0), Color(0.95, 0.78, 0.35, 0.85), Color(0.82, 0.38, 0.28, 0.9)]
const BEAM := Color(0.55, 0.38, 0.2, 0.95)
const WASH := Color(0.85, 0.75, 0.55, 0.38)


## Draw home `b` in tile rect `r`.
static func draw(ci: CanvasItem, b: Dictionary, r: Rect2) -> void:
	var look := HomeLook.state(b)
	var tier: int = look["tier"]
	if tier > 0:
		var band := Rect2(r.position + Vector2(r.size.x * 0.1, 0.0), Vector2(r.size.x * 0.8, r.size.y * 0.16))
		ci.draw_rect(band, TIER_TINTS[tier])
		ci.draw_rect(band, Art.OUTLINE, false, maxf(r.size.x * 0.04, 1.0))
		for n in tier:
			var c := r.position + Vector2(r.size.x * (0.2 + 0.14 * n), r.size.y * 0.88)
			Art.outlined_circle(ci, c, r.size.x * 0.06, TIER_TINTS[tier])
	if look["scaffold"]:
		_scaffold(ci, r, look)


static func _scaffold(ci: CanvasItem, r: Rect2, look: Dictionary) -> void:
	ci.draw_rect(r, WASH)
	var w := maxf(r.size.x * 0.06, 1.5)
	var a := r.grow(-r.size.x * 0.08)
	ci.draw_line(a.position, a.end, BEAM, w)
	ci.draw_line(Vector2(a.end.x, a.position.y), Vector2(a.position.x, a.end.y), BEAM, w)
	ci.draw_rect(r.grow(-r.size.x * 0.04), BEAM, false, w)
	var bar := Rect2(r.position + Vector2(r.size.x * 0.1, r.size.y * 0.8), Vector2(r.size.x * 0.8, r.size.y * 0.1))
	ci.draw_rect(bar, Art.OUTLINE)
	var frac: float = look["fill"] * 0.5  # the first half of the bar is the materials arriving, the second the build
	if look["site"] == "building":
		frac = 0.5 + look["progress"] * 0.5
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Ui.HIGHLIGHT)
