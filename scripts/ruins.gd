extends RefCounted
## What a Cataclysm leaves (Step 7, design-system/18-roadmap.md "Endings as built"): the old town's buildings as rubble on the
## same map, and a few dormant Bloom patches by the largest of them. A ruin is the tile a building stood on with the weight of what
## it cost; the largest are kept (Data.ENDINGS["ruins_max"]) and none lies near the Hearth. `of` and `patches_of` read the ended
## run; the next run's carry holds the lists (scripts/carry.gd), and `lay` puts them on the ground: the map the run begins
## with, and each strip of land (east, then south) as it grows, so a cleared ruin is never laid again. The Bloom tide wakes from
## the patches too (scripts/tide.gd, `patch_tiles`). Clearing a ruin with Demolish gives Stone (scripts/clearing.gd, `stone_at`).
## Static, and works on the Sim passed in, like Roads and Workers.

const Data = preload("res://scripts/data.gd")

const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const RING_FROM := 2  # a patch lies this many tiles from its ruin at the least, and RING_TO at the most
const RING_TO := 4


## The ruins the town in `s` would leave: [{"pos": [x, y], "weight": what the building cost}], the dearest first (ties by row,
## then column), at most Data.ENDINGS["ruins_max"], none within Data.ENDINGS["ruins_clear"] tiles of the Hearth.
static func of(s) -> Array:
	var out: Array = []
	for b in s.town.buildings:
		if b["type"] == "camp" or _near_camp(s, b["pos"], Data.ENDINGS["ruins_clear"]):
			continue
		var weight := 0
		for item in Data.BUILDINGS[b["type"]].get("cost", {}):
			weight += int(Data.BUILDINGS[b["type"]]["cost"][item])
		out.append({"pos": [b["pos"].x, b["pos"].y], "weight": weight})
	out.sort_custom(func(a, c): return _before(a, c))
	return out.slice(0, Data.ENDINGS["ruins_max"])


static func _before(a: Dictionary, c: Dictionary) -> bool:
	if a["weight"] != c["weight"]:
		return a["weight"] > c["weight"]
	if a["pos"][1] != c["pos"][1]:
		return a["pos"][1] < c["pos"][1]
	return a["pos"][0] < c["pos"][0]


static func _near_camp(s, p: Vector2i, within: int) -> bool:
	var d: Vector2i = (p - s.world.camp_pos).abs()
	return maxi(d.x, d.y) <= within


## The dormant Bloom patches beside the largest of `ruins`: [[x, y], ...], each the first open grass two to four tiles from
## its ruin (two tiles side by side) and Data.ENDINGS["patch_clear"] tiles or more from the Hearth, at least Data.ENDINGS["patches_min"]
## and at most "patches_max" (a town of few ruins gets the fewest).
static func patches_of(s, ruins: Array) -> Array:
	var out: Array = []
	if ruins.is_empty():
		return out
	var n := clampi(floori(ruins.size() / 12.0), Data.ENDINGS["patches_min"], Data.ENDINGS["patches_max"])
	var taken := {}
	for r in ruins:
		taken[_pos(r)] = true
	for r in ruins:  # the largest first; a ruin with no open grass round it gives its turn to the next
		if out.size() >= n:
			break
		var p := _open_near(s, _pos(r), taken)
		if p.x >= 0:
			taken[p] = true
			taken[p + Vector2i(1, 0)] = true
			out.append([p.x, p.y])
	return out


## The first open grass tile `RING_FROM` to `RING_TO` tiles from `from` (nearest ring first, row by row), (-1, -1) when there is none.
static func _open_near(s, from: Vector2i, taken: Dictionary) -> Vector2i:
	for ring in range(RING_FROM, RING_TO + 1):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var p := from + Vector2i(dx, dy)
				if (
					s.world.in_bounds(p)
					and s.world.in_bounds(p + Vector2i(1, 0))
					and s.world.tile_at(p) == "grass"
					and s.world.tile_at(p + Vector2i(1, 0)) == "grass"
					and not taken.has(p)
					and not taken.has(p + Vector2i(1, 0))
					and not _near_camp(s, p, Data.ENDINGS["patch_clear"] - 1)
					and not _near_camp(s, p + Vector2i(1, 0), Data.ENDINGS["patch_clear"] - 1)
				):
					return p
	return Vector2i(-1, -1)


## The tile of a ruin or of a patch of the carry (a ruin is {"pos": [x, y], "weight": n}, a patch [x, y]).
static func tile_of(r) -> Vector2i:
	return _pos(r)


static func _pos(r) -> Vector2i:
	var a = r["pos"] if typeof(r) == TYPE_DICTIONARY else r
	return Vector2i(int(a[0]), int(a[1]))


## Lay the ruins and patches of the carry on the plain grass of `region` (a Rect2i of the map): ruin tiles and, for a patch, its
## tile and the one east of it as Bloom ground. Ground that is not open grass (water, ore, forest) keeps what it is.
static func lay(s, region: Rect2i) -> void:
	for r in s.carry.ruins:
		var p := _pos(r)
		if region.has_point(p) and s.world.tile_at(p) == "grass":
			s.world.set_tile(p, "ruins")
	for a in s.carry.patches:
		for p in [_pos(a), _pos(a) + Vector2i(1, 0)]:
			if region.has_point(p) and s.world.tile_at(p) == "grass":
				s.world.set_tile(p, "bloom_ground")


## The tiles of the dormant patches that are Bloom ground now: where the tide begins besides the south (scripts/tide.gd).
static func patch_tiles(s) -> Array:
	var out: Array = []
	for a in s.carry.patches:
		for p in [_pos(a), _pos(a) + Vector2i(1, 0)]:
			if s.world.tile_at(p) == "bloom_ground":
				out.append(p)
	return out


## The Stone clearing the ruin at `p` gives: its weight over Data.ENDINGS["stone_per"], between "stone_min" and "stone_max".
static func stone_at(s, p: Vector2i) -> int:
	for r in s.carry.ruins:
		if _pos(r) == p:
			return clampi(
				floori(float(r["weight"]) / Data.ENDINGS["stone_per"]),
				Data.ENDINGS["stone_min"],
				Data.ENDINGS["stone_max"]
			)
	return Data.ENDINGS["stone_min"]
