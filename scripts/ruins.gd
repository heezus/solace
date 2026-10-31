extends RefCounted
## What a Cataclysm leaves (Step 7, design-system/18-roadmap.md "Endings as built"): the old town's buildings as rubble on the
## same map, and a few dormant Bloom patches at the old town's rim. A ruin is the tile a building stood on with the weight of what
## it cost; the largest are kept (Data.ENDINGS["ruins_max"]) and none lies in the old square (within "ruins_clear" tiles of the Hearth).
## `of` and `patches_of` read the ended run; the next run's carry holds the lists (scripts/carry.gd), and `lay` puts them on the ground:
## the map the run begins with, and each strip of land (east, then south) as it grows, so a cleared ruin is never laid again. The
## Bloom tide wakes from the patches too (scripts/tide.gd, `patch_tiles`). A road laid on rubble (Buildings.place) or Demolish clears
## it and gives Stone (`stone_at`).
## Static, and works on the Sim passed in, like Roads and Workers.

const Data = preload("res://scripts/data.gd")
const Relics = preload("res://scripts/relics.gd")

const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const RING_FROM := 2  # a patch lies this many tiles from the ruin it is beside at the least, and RING_TO (the map's reach) at the most
const RING_TO := 64
const PATCH_APART := 6  # no two dormant patches lie closer than this (tiles, either way)


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
	return _dist(s, p) <= within


## Tiles from the Hearth, either way (the larger of the two distances).
static func _dist(s, p: Vector2i) -> int:
	var d: Vector2i = (p - s.world.camp_pos).abs()
	return maxi(d.x, d.y)


## The dormant Bloom patches the old town leaves: [[x, y], ...], each the open grass (two tiles side by side) nearest one of the
## largest of `ruins` that lies at least Data.ENDINGS["patch_clear"] tiles from the Hearth and beyond the old town's edge (`edge_of`),
## so the patches burn at the town's rim and never in the square. At least Data.ENDINGS["patches_min"], at most "patches_max" (a town
## of few ruins gets the fewest), none within PATCH_APART tiles of another. A town that reaches the map's rim leaves no room beyond its
## edge: then 20 tiles out is all that is asked.
static func patches_of(s, ruins: Array) -> Array:
	if ruins.is_empty():
		return []
	var n := clampi(floori(ruins.size() / 12.0), Data.ENDINGS["patches_min"], Data.ENDINGS["patches_max"])
	var out := _patches_beyond(s, ruins, n, maxi(Data.ENDINGS["patch_clear"], edge_of(s) + 1))
	if out.size() < Data.ENDINGS["patches_min"]:  # a town that reaches the map's rim leaves no room beyond it: 20 out will do
		out = _patches_beyond(s, ruins, n, Data.ENDINGS["patch_clear"])
	return out


## Up to `n` patches, none within `from` tiles of the Hearth (see patches_of).
static func _patches_beyond(s, ruins: Array, n: int, from: int) -> Array:
	var out: Array = []
	var taken := {}
	for r in ruins:
		taken[_pos(r)] = true
	for r in ruins:  # the largest first; a ruin with no open grass round it gives its turn to the next
		if out.size() >= n:
			break
		var p := _open_near(s, _pos(r), taken, from, out)
		if p.x >= 0:
			taken[p] = true
			taken[p + Vector2i(1, 0)] = true
			out.append([p.x, p.y])
	return out


## How far from the Hearth the old town reaches: the distance (tiles, either way) that Data.ENDINGS["patch_edge"] of its buildings
## stand within.
static func edge_of(s) -> int:
	var ds: Array = []
	for b in s.town.buildings:
		if b["type"] != "camp":
			ds.append(_dist(s, b["pos"]))
	if ds.is_empty():
		return 0
	ds.sort()
	return ds[mini(ds.size() - 1, floori(ds.size() * Data.ENDINGS["patch_edge"]))]


## The first open grass pair `RING_FROM` or more tiles from `from` (nearest ring first, row by row), `min_dist` or more from the Hearth and
## PATCH_APART from the patches already chosen: its left tile, (-1, -1) when there is none.
static func _open_near(s, from: Vector2i, taken: Dictionary, min_dist: int, chosen: Array) -> Vector2i:
	for ring in range(RING_FROM, RING_TO + 1):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var p := from + Vector2i(dx, dy)
				if _fits(s, p, taken, min_dist, chosen):
					return p
	return Vector2i(-1, -1)


static func _fits(s, p: Vector2i, taken: Dictionary, min_dist: int, chosen: Array) -> bool:
	var q := p + Vector2i(1, 0)
	if not (
		s.world.in_bounds(p)
		and s.world.in_bounds(q)
		and s.world.tile_at(p) == "grass"
		and s.world.tile_at(q) == "grass"
	):
		return false
	if taken.has(p) or taken.has(q) or _dist(s, p) < min_dist or _dist(s, q) < min_dist:
		return false
	for c in chosen:
		if maxi(absi(c[0] - p.x), absi(c[1] - p.y)) < PATCH_APART:
			return false
	return true


## What a road laid on the rubble at p would meet: {"relic": a relic lies under it (a road does not clear it, it is dug out first,
## scripts/scouting.gd), "stone": the Stone clearing it gives}.
static func rubble(s, p: Vector2i) -> Dictionary:
	return {"relic": Relics.tip(s, p) != "", "stone": stone_at(s, p)}


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
