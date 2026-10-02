extends RefCounted
## Is the land that grows east fair? A thin wrapper for the many-seed test (tests/era_fair_tests.gd) and the scan tool
## (tests/tools/east_scan.gd) over MapEast.road_ways, run on a grown World: what a road from the Hearth faces on the way
## to the copper and to the tin. Static, sets nothing.

const World = preload("res://scripts/world.gd")
const MapEast = preload("res://scripts/map_east.gd")

const ORE := ["copper_hills", "tin_stream"]


## A grown World for `map_seed`: the stone-age map and the land beside it, as the game makes them.
static func grown(map_seed: int) -> World:
	var w := World.new()
	w.generate(map_seed)
	w.grow_east()
	return w


## MapEast.road_ways for a grown world, plus "bad_ore": ore tiles lying in the stone-age half (there should be none).
static func report(w: World) -> Dictionary:
	var strip: Array = []
	var bad := 0
	for y in w.height:
		for x in w.width:
			if x >= w.stone_width:
				strip.append(w.tile_at(Vector2i(x, y)))
			elif w.tile_at(Vector2i(x, y)) in ORE:
				bad += 1
	var out := MapEast.road_ways(w, strip)
	out["bad_ore"] = bad
	return out


## The faults of a report, as sentences: [] when fair (a road reaches each ore with at most `max_rivers` bridges).
static func faults(r: Dictionary, max_rivers: int) -> Array:
	var out: Array = []
	for ore in ["copper", "tin"]:
		if r[ore]["rivers"] > max_rivers:
			out.append(
				(
					"%s needs %s river tiles"
					% [ore, "unreachable" if r[ore]["rivers"] >= MapEast.NONE else r[ore]["rivers"]]
				)
			)
	if r["bad_ore"] > 0:
		out.append("%d ore tiles are in the stone-age half" % r["bad_ore"])
	return out
