extends RefCounted
## Placeholder look for the tide (design-system/23-livewire.md, stage 2), drawn over the map until Codex paints it (docs/art/requests.md,
## "The tide"): a wash on Bloom ground that keeps its own tile (ore, water, a road, a building), the ash of burnt ground, a pale glow
## round a lit Arc Lamp, a flame ring round a burning Scorcher, a tint on overgrown buildings and, with Tide Watch, the front. Bloom
## ground the tide made is a tile of its own (`bloom_tide`, drawn by scripts/bloom_look.gd). Static: it takes the CanvasItem to draw
## on (the map) and the Sim, and only draws tiles the fog has lifted from.

const Data = preload("res://scripts/data.gd")

const TILE := 48.0  # map px per tile at the default zoom (scripts/overlays.gd)
const WASH := Color(0.62, 0.22, 0.58, 0.32)
const ASH := Color(0.16, 0.14, 0.14, 0.42)
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
	var seen := Rect2i(0, 0, s.world.width, s.world.height)  # only the tiles in view: the Bloom may cover most of the map
	if ci.has_method("_visible_tiles"):
		seen = ci._visible_tiles()
	for y in range(seen.position.y, seen.end.y):
		for x in range(seen.position.x, seen.end.x):
			var p := Vector2i(x, y)
			if tide.grown.has(p) and s.fog.is_revealed(p) and s.world.tile_at(p) != Data.TILE_BLOOM_TIDE:
				ci.draw_rect(_rect(p), WASH)
			elif tide.burnt.has(p) and s.fog.is_revealed(p):
				ci.draw_rect(_rect(p).grow(-2.0), ASH)
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
