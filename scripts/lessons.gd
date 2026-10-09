extends RefCounted
## What the Lessons do in the world (design-system/19-ironfall.md): the small reads other scripts ask, and the placeholder
## map overlays for the two Bloom Lessons. A Lesson is learned at the Teardown Bench (`sim.teardown.knows`); the effects that
## ride on a number live in Data.BONUSES (Iron Gears, Starfruit in smoke), the Iron Gears recipe in Data.RECIPES, the Rain
## Barrel in Data.BUILDINGS. Static, and works on the Sim passed in.

const Data = preload("res://scripts/data.gd")
const Art = preload("res://scripts/art.gd")

const TILE := 48.0  # map px per tile at the default zoom (scripts/overlays.gd)


## The extra share of a bundle a Field at `tile` pays for a Rain Barrel within Data.RAIN_BARREL_RADIUS tiles (Water glass), else 0.
static func rain_share(s, tile: Vector2i) -> float:
	if not s.teardown.knows("water_glass"):
		return 0.0
	for b in s.town.buildings:
		if b["type"] == "rain_barrel" and Vector2(b["pos"]).distance_to(Vector2(tile)) <= Data.RAIN_BARREL_RADIUS:
			return Data.RAIN_BARREL_FIELD
	return 0.0


## The Bloom signs on the map: the first one the Starfall ended on, and the three patches in the south (a sample's tile or the
## Bloom ground it was taken from). One centre per patch, as tile positions.
static func bloom_centres(s) -> Array:
	var out: Array = []
	if s.starfall.bloom.x >= 0:
		out.append(s.starfall.bloom)
	if not s.world.is_grown_south():
		return out
	var w: int = s.world.width
	var found: Array = []
	for i in range(s.world.base_height * w, s.world.tiles.size()):
		var tile: String = s.world.tiles[i]
		if tile == Data.BLOOM_GROUND or tile in Data.BLOOM_TILES.values():
			found.append(Vector2i(i % w, floori(float(i) / w)))
	for p in found:
		if out.all(func(c): return maxi(absi(c.x - p.x), absi(c.y - p.y)) > Data.SPORE_REACH):
			out.append(p)
	return out


## The overlays of the Lessons, drawn over the ground (scripts/kith_art.gd calls it beside the Bloom sign). Lamp core: the pale
## light of each burning Shard Lamp. Then the two Bloom overlays. Spore: a ring of
## Data.SPORE_REACH tiles round each sign, where the Bloom would eat. Root: the roads and rocks it crosses slowest, lit. Both
## are plain stand-ins until Codex paints them (docs/art/requests.md).
static func draw_overlays(ci: CanvasItem, s) -> void:
	for b in s.town.buildings:  # a burning Shard Lamp lights the tiles round it
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		if def["kind"] == "lamp" and b["burn"] > 0.0 and s.fog.is_revealed(b["pos"]):
			var lamp := (Vector2(b["pos"]) + Vector2(0.5, 0.5)) * TILE
			ci.draw_circle(lamp, (def["light"] + 0.5) * TILE, Color(0.6, 0.95, 1.0, 0.1))
			ci.draw_circle(lamp, (def["light"] * 0.5 + 0.25) * TILE, Color(0.7, 0.97, 1.0, 0.12))
	if s.teardown.knows("spore"):
		for c in bloom_centres(s):
			if s.fog.is_revealed(c):
				var at := (Vector2(c) + Vector2(0.5, 0.5)) * TILE
				ci.draw_circle(at, (Data.SPORE_REACH + 0.5) * TILE, Color(0.75, 0.29, 0.62, 0.12))
				Art.dashed_circle(ci, at, (Data.SPORE_REACH + 0.5) * TILE, Color(0.75, 0.29, 0.62, 0.7), 2.0, 10.0, 7.0)
	if s.teardown.knows("root"):
		for y in s.world.height:
			for x in s.world.width:
				var p := Vector2i(x, y)
				if is_slow_ground(s, p) and s.fog.is_revealed(p):
					ci.draw_rect(
						Rect2(Vector2(p) * TILE, Vector2(TILE, TILE)).grow(-4.0), Color(0.44, 0.66, 0.29, 0.28)
					)


## True for ground the Bloom crosses slowest (Data.ROOT_LIT: roads and rock), which the Root Lesson lights.
static func is_slow_ground(s, p: Vector2i) -> bool:
	return s.world.roads.has(p) or s.world.tile_at(p) in Data.ROOT_LIT
