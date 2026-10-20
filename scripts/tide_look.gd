extends RefCounted
## Tide object/status overlays: lamp glow, Scorcher flame, overgrown buildings and Tide Watch front.
## WorldGround paints Bloom/burnt ground. All overlays remain gated by the existing tide and fog state.

const Data = preload("res://scripts/data.gd")

const TILE := 48.0  # map px per tile at the default zoom (scripts/overlays.gd)
const FRONT := Color(0.85, 0.35, 0.72, 0.55)
const FRONT_SOON := Color(0.95, 0.5, 0.85, 0.9)
const ARC := Color(1.0, 0.95, 0.7, 0.1)
const FLAME := Color(1.0, 0.5, 0.2, 0.12)
const OVERGROWN := Color(0.62, 0.22, 0.58, 0.4)


static func _rect(p: Vector2i) -> Rect2:
	return Rect2(Vector2(p) * TILE, Vector2(TILE, TILE))


static func draw(ci: CanvasItem, s) -> void:
	var tide = s.tide
	if not tide.begun:
		return
	for b in s.town.buildings:
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		var at := (Vector2(b["pos"]) + Vector2(0.5, 0.5)) * TILE
		if not s.fog.is_revealed(b["pos"]):
			continue
		if tide.is_overgrown(b):
			ci.draw_rect(_rect(b["pos"]), OVERGROWN)
		elif def["kind"] == "arc_lamp" and s.town.is_powered(b["pos"]):
			ci.draw_circle(at, (float(def["light"]) + 0.5) * TILE, ARC)
		elif def["kind"] == "scorcher" and b["burn"] > 0.0:
			ci.draw_circle(at, (float(def["reach"]) + 0.5) * TILE, FLAME)
	if s.tech_tree.researched.has("tide_watch"):
		for p in tide.front:
			if s.fog.is_revealed(p):
				var soon: bool = tide.front[p] - tide.time <= 30.0
				ci.draw_rect(_rect(p).grow(-3.0), FRONT_SOON if soon else FRONT, false, 2.0)
