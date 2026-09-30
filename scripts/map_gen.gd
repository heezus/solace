extends RefCounted
## Makes a new map that reads as land. MapTerrain gives it a height field (a high side and a low side),
## a river that runs downhill to the edge (with a tributary or a fork on some seeds) and a wetness for
## every tile; this script lets the resources follow it: a ridge of rock on the high ground with a gap
## or two, rocks on the hills, forest in the wet ground by the river, grain in the open mid-wet meadows,
## berries at the forest edge, clay on the inside of river bends and gravel on the outside (and where
## rock meets the river), wild flax in patches on open grassland, and the Strange Stone on a lone high
## point far from home. Then the Hearth goes on dry lowland near the river, with the small patches every
## map guarantees around it.
##
## Fairness checks (faults_of) decide whether a land is playable. A land that fails is thrown away and
## another is made from the next attempt seed; after ATTEMPTS tries the last one is patched instead.
## Static, and works on the World passed in: it sets the tiles, camp_pos and shard_pos, nothing more (the
## Hearth building, the fog, the walk grid and the first Kith are set up by whoever owns the World). A map
## too small for real terrain gets a plain safe layout. Deterministic: the same seed, the same map.

const Data = preload("res://scripts/data.gd")
const Terrain = preload("res://scripts/map_terrain.gd")

## The flax patch every map gets near the Hearth (offsets from it), within a hut's reach of it.
const FLAX_PATCH := [Vector2i(-2, -3), Vector2i(-1, -3), Vector2i(-2, -4)]
## The rest of what every map gets near the Hearth, so the opening never stalls.
const TREES := [Vector2i(-3, -1), Vector2i(-3, 0)]
const OUTCROP := [Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3)]  # every tier costs Stone
const BERRY_PATCH := [Vector2i(-2, 3), Vector2i(-1, 3), Vector2i(-2, 4)]  # food for the first Kith
const GRAIN := [Vector2i(2, -3)]
const FLINT := [Vector2i(4, 0), Vector2i(4, 1)]  # Knapping needs flint before anything can be built out on the banks

const MIN_WIDTH := 24  # smaller maps get the plain layout
const MIN_HEIGHT := 16
const ATTEMPTS := 24
## The Hearth sits this many tiles from the edge and this close to the river (steps) on dry lowland.
const CAMP_MARGIN := Vector2i(5, 5)
const CAMP_RIVER := Vector2i(5, 10)
const CAMP_LOW_PERCENT := 50  # the Hearth's ground is below this share of the map's heights
const CAMP_WET_MAX := 700
## The patch of ground around the Hearth every map guarantees a resource in, from the corner to corner.
const FOOTPRINT_MIN := Vector2i(-4, -5)
const FOOTPRINT_MAX := Vector2i(5, 5)
## What a map must offer, counted as reachable tiles: within the first fog radius of the Hearth, and on the whole map.
const NEAR_MIN := {"tree": 5, "rock": 4, "berry": 3, "grain": 2, "flax": 3, "gravel": 2}
const REACH_MIN := {"tree": 12, "rock": 8, "berry": 5, "grain": 6, "flax": 6, "gravel": 4, "clay": 3}
const FAR_BANK_SHARE := 8  # at least this percent of the land must lie across the water: a crossing to solve

const RIDGE_PERCENT := 72  # the ridge follows this height
const FLOODPLAIN_MIN := 5.0  # the open bank lies this far from the Hearth, at least
const FLOODPLAIN_AT := 6.0  # and as near to this as the river allows: close enough to build up, far enough to have room
const FLOODPLAIN_REACH := 4  # and keeps open ground this many tiles round it
const WHEEL_ROOM := 20  # grass tiles in the 7 by 7 round a bank tile that a Water Wheel can stand on
const BANK_FOREST := 450  # forest noise (thousandths) above which trees grow right down to the water
const OPEN_BANK_MIN := 5  # grass tiles beside the river, reachable by land
const BEND := 3  # how many steps either way the river's turn is read over
const BEND_MIN := 2  # a turn sharper than this has an inside and an outside
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## `s` is the World; the map is as big as it is.
static func generate(s, seed_value: int) -> void:
	build(s, seed_value, {})


## The same as generate, and fills `report` with what happened: "terrain" (the land, see MapTerrain), "attempts"
## (how many lands were made), "patched" (true when none passed and the last was patched) and "faults" (what the
## final map still fails: [] for a fair one). A map too small for terrain reports only "small".
static func build(s, seed_value: int, report: Dictionary) -> void:
	if s.width < MIN_WIDTH or s.height < MIN_HEIGHT:
		report["small"] = true
		_plain_map(s, seed_value)
		return
	var land := {}
	var faults: Array = ["no attempt"]
	var tries := 0
	while tries < ATTEMPTS and not faults.is_empty():
		land = _attempt(s, attempt_seed(seed_value, tries))
		faults = faults_of(s, land)
		tries += 1
	report["patched"] = not faults.is_empty()
	if not faults.is_empty():
		patch(s, land)
		faults = faults_of(s, land)
	report["terrain"] = land
	report["attempts"] = tries
	report["faults"] = faults


## The seed of attempt `k` for a map seed: a fixed sequence, so a reroll is as repeatable as the first try.
static func attempt_seed(seed_value: int, k: int) -> int:
	return absi(seed_value * 1103515245 + k * 12345 + 7) % 2147483647


static func _attempt(s, land_seed: int) -> Dictionary:
	var land := Terrain.make(s.width, s.height, land_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = land_seed + 3
	s.reset("grass")
	s.shard_pos = Vector2i(-1, -1)
	for p in land["water"]:
		s.set_tile(p, "river")
	s.camp_pos = _pick_camp(s, land, rng)
	land["camp"] = s.camp_pos
	land["zone"] = _floodplain(s)
	land["seed_rock"] = land_seed + 4
	land["seed_forest"] = land_seed + 5
	land["seed_meadow"] = land_seed + 6
	land["seed_berry"] = land_seed + 7
	_lay_ridge(s, land, rng)
	_lay_boulders(s, land)
	_lay_banks(s, land, rng)
	_lay_forest(s, land)
	_lay_meadows(s, land)
	_lay_berries(s, land, rng)
	_lay_flax(s, land, rng)
	_lay_hearth(s, rng)
	_lay_shard(s, land)
	return land


# --- Where the Hearth goes -----------------------------------------------------


## Dry lowland with the river a short walk away, some way from the edge; the spot is a little random.
static func _pick_camp(s, land: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var low := Terrain.height_at_percent(land, CAMP_LOW_PERCENT)
	var best := Vector2i(clampi(s.width / 3, 0, s.width - 1), clampi(s.height / 2, 0, s.height - 1))
	var best_score := 1 << 60
	for y in range(CAMP_MARGIN.y, s.height - CAMP_MARGIN.y):
		for x in range(CAMP_MARGIN.x, s.width - CAMP_MARGIN.x):
			var p := Vector2i(x, y)
			var d := Terrain.dist_of(land, p)
			if d < CAMP_RIVER.x or d > CAMP_RIVER.y or Terrain.height_of(land, p) > low:
				continue
			if Terrain.wet_of(land, p) > CAMP_WET_MAX or not _footprint_dry(land, p):
				continue
			var score := absi(d - 6) * 35 + Terrain.height_of(land, p) / 25 + rng.randi_range(0, 100)
			if score < best_score:
				best_score = score
				best = p
	return best


## No river tile in the ground around p that the Hearth's patches take.
static func _footprint_dry(land: Dictionary, p: Vector2i) -> bool:
	for q in land["water"]:
		var d: Vector2i = q - p
		if d.x >= FOOTPRINT_MIN.x and d.x <= FOOTPRINT_MAX.x and d.y >= FOOTPRINT_MIN.y and d.y <= FOOTPRINT_MAX.y:
			return false
	return true


## The floodplain: open ground by the river, a short way from the Hearth. Nothing but grass
## is laid on it, so there is room for a Water Wheel and the workshops that need its power. A set of tiles.
static func _floodplain(s) -> Dictionary:
	var reach := _flood(s, s.camp_pos, true)
	var landing := Vector2i(-1, -1)
	var best_d := 1000000.0
	for y in s.height:
		for x in s.width:
			var p := Vector2i(x, y)
			if not reach.has(p) or s.tile_at(p) != "grass" or _river_beside(s, p).x < 0:
				continue
			if (
				x < FLOODPLAIN_REACH
				or y < FLOODPLAIN_REACH
				or x >= s.width - FLOODPLAIN_REACH
				or y >= s.height - FLOODPLAIN_REACH
			):
				continue  # the whole plain must be on the map
			var d := Vector2(p).distance_to(Vector2(s.camp_pos))
			if d >= FLOODPLAIN_MIN and absf(d - FLOODPLAIN_AT) < best_d:
				best_d = absf(d - FLOODPLAIN_AT)
				landing = p
	var zone := {}
	if landing.x < 0:
		return zone
	for dy in range(-FLOODPLAIN_REACH, FLOODPLAIN_REACH + 1):
		for dx in range(-FLOODPLAIN_REACH, FLOODPLAIN_REACH + 1):
			var q := landing + Vector2i(dx, dy)
			if s.in_bounds(q) and s.tile_at(q) != "river":
				zone[q] = true
	return zone


# --- Rock ------------------------------------------------------------------------


## A ridge along the high ground, across the slope, from one edge to the other. It is 1 or 2 rocks thick
## and has a gap or two: the way over is a pass cut through it with Stone, or round by the gap.
static func _lay_ridge(s, land: Dictionary, rng: RandomNumberGenerator) -> void:
	var level := Terrain.height_at_percent(land, RIDGE_PERCENT)
	var up: Vector2i = land["dir"]
	var across := Vector2i(-up.y, up.x)
	var edge: Array = Terrain.border_by_height(land)
	var lo := 1 << 30
	var hi := -(1 << 30)
	for p in edge:
		lo = mini(lo, p.x * across.x + p.y * across.y)
		hi = maxi(hi, p.x * across.x + p.y * across.y)
	var from := Vector2i(-1, -1)  # the start: on the near end, where the land is closest to the ridge's height
	var goal := {}  # the other end: any edge tile out there
	for p in edge:
		var along: int = p.x * across.x + p.y * across.y
		if along >= hi - 1:
			goal[p] = true
		elif (
			along <= lo + 1
			and (from.x < 0 or absi(Terrain.height_of(land, p) - level) < absi(Terrain.height_of(land, from) - level))
		):
			from = p
	var cost := func(_a: Vector2i, b: Vector2i) -> int: return 10 + absi(Terrain.height_of(land, b) - level) / 5
	var path := Terrain.route(land, from, func(p): return goal.has(p), cost)
	var gaps := _gaps(path.size(), rng)
	for i in path.size():
		if gaps.has(i):
			continue
		_rock_at(s, land, path[i])
		if rng.randf() < 0.45 and i + 1 < path.size():
			var step: Vector2i = path[i + 1] - path[i]
			_rock_at(s, land, path[i] + Vector2i(-step.y, step.x))


## The path indexes left open: one or two gaps, each 3 long, away from both ends.
static func _gaps(n: int, rng: RandomNumberGenerator) -> Dictionary:
	var gaps := {}
	if n < 12:
		return gaps
	for k in rng.randi_range(1, 2):
		var start := rng.randi_range(n * 15 / 100, n * 85 / 100)
		for i in range(start, mini(start + 3, n)):
			gaps[i] = true
	return gaps


## Rock on a grass tile that is not by the Hearth.
static func _rock_at(s, land: Dictionary, p: Vector2i) -> void:
	if s.tile_at(p) == "grass" and _cheb(p, land["camp"]) > 6 and not land["zone"].has(p):
		s.set_tile(p, "rock")


## Rocks on the hills: the highest ground, in clumps.
static func _lay_boulders(s, land: Dictionary) -> void:
	var rock := Terrain.noise_field(s.width, s.height, land["seed_rock"], 0.13)
	var floor_h := Terrain.height_at_percent(land, 65)
	var cells: Array = []
	for y in s.height:
		for x in s.width:
			var p := Vector2i(x, y)
			if _free(s, land, p) and _cheb(p, land["camp"]) > 6 and Terrain.height_of(land, p) >= floor_h:
				cells.append(p)
	var score := func(p: Vector2i) -> int: return Terrain.height_of(land, p) / 2 + rock[p.y * s.width + p.x]
	for p in _top(cells, score, s.width * s.height * 5 / 100):
		s.set_tile(p, "rock")


# --- Forest, meadow, berries, flax -------------------------------------------------


## Forest where it is wet: by the river, more or less, in clumps. The bank itself stays open grass (room for a
## Water Wheel, a weir, a field) except where the forest is thickest.
static func _lay_forest(s, land: Dictionary) -> void:
	var noise := Terrain.noise_field(s.width, s.height, land["seed_forest"], 0.12)
	var cap := Terrain.height_at_percent(land, 85)
	var cells: Array = []
	for y in s.height:
		for x in s.width:
			var p := Vector2i(x, y)
			if not _free(s, land, p) or _cheb(p, land["camp"]) <= 2 or Terrain.height_of(land, p) > cap:
				continue
			if Terrain.dist_of(land, p) > 1 or noise[y * s.width + x] > BANK_FOREST:
				cells.append(p)
	var score := func(p: Vector2i) -> int: return Terrain.wet_of(land, p) * 8 / 10 + noise[p.y * s.width + p.x] * 4 / 10
	for p in _top(cells, score, s.width * s.height * 20 / 100):
		s.set_tile(p, "tree")


## Grain in open lowland meadows: mid-wet, low, with no forest touching.
static func _lay_meadows(s, land: Dictionary) -> void:
	var noise := Terrain.noise_field(s.width, s.height, land["seed_meadow"], 0.12)
	var cap := Terrain.height_at_percent(land, 70)
	var cells: Array = []
	for y in s.height:
		for x in s.width:
			var p := Vector2i(x, y)
			var wet := Terrain.wet_of(land, p)
			if not _free(s, land, p) or _cheb(p, land["camp"]) <= 2 or Terrain.dist_of(land, p) < 2:
				continue
			if wet >= 200 and wet <= 750 and Terrain.height_of(land, p) <= cap and _count_near(s, p, "tree", 1) == 0:
				cells.append(p)
	var score := func(p: Vector2i) -> int:
		return 1000 - absi(Terrain.wet_of(land, p) - 480) + noise[p.y * s.width + p.x] / 2
	for p in _top(cells, score, s.width * s.height * 8 / 100):
		s.set_tile(p, "grain")


## Berries along the forest edge: grass with a tree beside it, in patches.
static func _lay_berries(s, land: Dictionary, rng: RandomNumberGenerator) -> void:
	var noise := Terrain.noise_field(s.width, s.height, land["seed_berry"], 0.2)
	for y in s.height:
		for x in s.width:
			var p := Vector2i(x, y)
			if not _free(s, land, p) or _cheb(p, land["camp"]) <= 2 or not s.touches(p, "tree"):
				continue
			if noise[y * s.width + x] > -200 and rng.randf() < 0.3:
				s.set_tile(p, "berry")


## Wild flax in a few small patches on open grassland: grass all round, and not on the wet bank.
static func _lay_flax(s, land: Dictionary, rng: RandomNumberGenerator) -> void:
	var open: Array = []
	for y in s.height:
		for x in s.width:
			var p := Vector2i(x, y)
			if _open_grass(s, land, p):
				open.append(p)
	var centres: Array = []
	for i in 40:
		if open.is_empty() or centres.size() >= 5:
			break
		var c: Vector2i = open[rng.randi_range(0, open.size() - 1)]
		if centres.all(func(o): return _cheb(o, c) >= 5):
			centres.append(c)
			_flax_patch(s, land, c, rng)


static func _flax_patch(s, land: Dictionary, c: Vector2i, rng: RandomNumberGenerator) -> void:
	var at := c
	for i in rng.randi_range(3, 5):
		if _flax_ok(s, land, at):
			s.set_tile(at, "flax")
		at += NEIGHBORS[rng.randi_range(0, 3)]


## Flax may grow on grass that is off the bank and has no forest or rock touching it.
static func _flax_ok(s, land: Dictionary, p: Vector2i) -> bool:
	if not _free(s, land, p) or Terrain.dist_of(land, p) < 2 or _cheb(p, land["camp"]) <= 2:
		return false
	return _count_near(s, p, "tree", 1) == 0 and _count_near(s, p, "rock", 1) == 0


static func _open_grass(s, land: Dictionary, p: Vector2i) -> bool:
	if not s.in_bounds(p) or not _free(s, land, p) or _cheb(p, land["camp"]) <= 2:
		return false
	return Terrain.dist_of(land, p) >= 2 and Terrain.wet_of(land, p) <= 650 and _count_near(s, p, "grass", 1) == 9


# --- The river banks ---------------------------------------------------------------


## Clay on the inside of the river's bends, gravel on the outside; a little of either on the straights;
## and flint gravel wherever rock comes down to the river.
static func _lay_banks(s, land: Dictionary, rng: RandomNumberGenerator) -> void:
	var water: Dictionary = land["water"]
	var clay: Array = []
	for y in s.height:
		for x in s.width:
			var b := Vector2i(x, y)
			var r := _river_beside(s, b)
			if not _free(s, land, b) or r == Vector2i(-1, -1) or _cheb(b, land["camp"]) <= 2:
				continue
			var tile := _bank_tile(land, water[r], b, rng)
			if _count_near(s, b, "rock", 2) > 0 and rng.randf() < 0.8:
				tile = "gravel"
			if tile != "":
				s.set_tile(b, tile)
			if tile == "clay":
				clay.append(b)
	for c in clay:  # clay lies a little way in from the water, too
		for n in NEIGHBORS:
			if _free(s, land, c + n) and _cheb(c + n, land["camp"]) > 2 and rng.randf() < 0.5:
				s.set_tile(c + n, "clay")


## The river tile beside b, or (-1, -1).
static func _river_beside(s, b: Vector2i) -> Vector2i:
	for n in NEIGHBORS:
		if s.tile_at(b + n) == "river":
			return b + n
	return Vector2i(-1, -1)


## What lies on bank tile b, by the river at `at` = Vector2i(path number, index): "clay", "gravel" or "".
static func _bank_tile(land: Dictionary, at: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> String:
	var path: Array = land["paths"][at.x]
	var here: Vector2i = path[at.y]
	var before: Vector2i = here - path[maxi(at.y - BEND, 0)]
	var after: Vector2i = path[mini(at.y + BEND, path.size() - 1)] - here
	var turn := before.x * after.y - before.y * after.x
	var flow := before + after
	var d := b - here
	var side := flow.x * d.y - flow.y * d.x
	var roll := rng.randf()
	if absi(turn) < BEND_MIN:
		return "clay" if roll < 0.15 else ("gravel" if roll < 0.23 else "")
	if side * turn > 0:  # the inside of the bend: slow water leaves clay
		return "clay" if roll < 0.6 else ""
	return "gravel" if roll < 0.5 else ""


# --- The Hearth --------------------------------------------------------------------


## Clear the Hearth and the ground around it, then lay the patches every map has near it, each grown
## a little into a natural clump.
static func _lay_hearth(s, rng: RandomNumberGenerator) -> void:
	var camp: Vector2i = s.camp_pos
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var p := camp + Vector2i(dx, dy)
			if s.in_bounds(p) and s.tile_at(p) != "river":
				s.set_tile(p, "grass")
	var patches := [
		["tree", TREES, 0.6],
		["rock", OUTCROP, 0.75],
		["berry", BERRY_PATCH, 0.45],
		["grain", GRAIN, 0.5],
		["flax", FLAX_PATCH, 0.35],
		["gravel", FLINT, 0.3],
	]
	for patch_def in patches:
		for off in patch_def[1]:
			s.set_tile(camp + off, patch_def[0])
	for patch_def in patches:
		for off in patch_def[1]:
			for n in NEIGHBORS:
				var q: Vector2i = camp + off + n
				var ground: Array = ["grass"] if patch_def[0] == "flax" else ["grass", "tree"]
				if s.tile_at(q) in ground and _cheb(q, camp) > 2 and rng.randf() < patch_def[2]:
					s.set_tile(q, patch_def[0])


# --- The Strange Stone ------------------------------------------------------------


## On a lone high point far from the Hearth: grass all round, on the Hearth's side of the river.
static func _lay_shard(s, land: Dictionary) -> void:
	var reach := _flood(s, s.camp_pos, true)
	# Tiers, best first: (room, share of the land it must stand above). Room is grass in the 3 by 3 around it.
	for tier in [[9, 60], [5, 60], [9, 40], [5, 40], [9, 0], [5, 0]]:
		var floor_h := Terrain.height_at_percent(land, tier[1])
		var best := Vector2i(-1, -1)
		var best_score := -(1 << 60)
		for y in range(1, s.height - 1):
			for x in range(1, s.width - 1):
				var p := Vector2i(x, y)
				var far := Vector2(p).distance_to(Vector2(s.camp_pos))
				if (
					not reach.has(p)
					or s.tile_at(p) != "grass"
					or far <= 10.0
					or _count_near(s, p, "grass", 1) < tier[0]
				):
					continue
				if Terrain.height_of(land, p) < floor_h:
					continue
				var score := Terrain.height_of(land, p) + int(far * 3.0)
				if score > best_score:
					best_score = score
					best = p
		if best.x >= 0:
			s.set_tile(best, "shard")
			s.shard_pos = best
			return


# --- Fairness ----------------------------------------------------------------------


## What is wrong with the map, as short sentences: [] when it is fair. The Hearth is on dry lowland near
## the river; every basic resource is within the fog's first radius and reachable by land (not over the
## river or rock); there is clay, gravel and a Strange Stone far off; and a bank of the river is only
## reachable by a bridge.
static func faults_of(s, land: Dictionary) -> Array:
	var faults: Array = []
	var camp: Vector2i = s.camp_pos
	if not _footprint_dry(land, camp):
		faults.append("river on the Hearth's ground")
	if Terrain.dist_of(land, camp) > CAMP_RIVER.y + 2:
		faults.append("the river is far from the Hearth")
	if Terrain.height_of(land, camp) > Terrain.height_at_percent(land, CAMP_LOW_PERCENT):
		faults.append("the Hearth is not on lowland")
	if Terrain.wet_of(land, camp) > CAMP_WET_MAX:
		faults.append("the Hearth is on wet ground")
	var walk := _flood(s, camp, false)
	var loose := _flood(s, camp, true)
	var near := _reachable_counts(s, walk, camp, Data.SIGHT_START)
	var whole := _reachable_counts(s, walk, camp, 1000)
	for tile in NEAR_MIN:
		if near.get(tile, 0) < NEAR_MIN[tile]:
			faults.append("too little %s near the Hearth (%d)" % [tile, near.get(tile, 0)])
	for tile in REACH_MIN:
		if whole.get(tile, 0) < REACH_MIN[tile]:
			faults.append("too little %s reachable (%d)" % [tile, whole.get(tile, 0)])
	if _open_banks(s, walk) < OPEN_BANK_MIN:
		faults.append("no open river bank for a wheel or a weir")
	if not _wheel_site(s, walk, camp):
		faults.append("no room for a Water Wheel and its workshops by the river")
	var far: Vector2i = s.shard_pos
	if not s.in_bounds(far) or s.tile_at(far) != "shard":
		faults.append("no Strange Stone")
	elif Vector2(far).distance_to(Vector2(camp)) <= 10.0 or not loose.has(far):
		faults.append("the Strange Stone is near or cut off")
	var land_tiles: int = s.tiles.size() - s.tiles.count("river")
	if loose.size() * 100 > land_tiles * (100 - FAR_BANK_SHARE):
		faults.append("no far bank to bridge to")
	return faults


## True if a Water Wheel has a place: a reachable bank tile near the Hearth with open grass round it.
static func _wheel_site(s, walk: Dictionary, camp: Vector2i) -> bool:
	for p in walk:
		if s.tile_at(p) == "grass" and _cheb(p, camp) <= 16 and _river_beside(s, p).x >= 0:
			if _count_near(s, p, "grass", 3) >= WHEEL_ROOM:
				return true
	return false


## How many grass tiles beside the river the Kith can walk to.
static func _open_banks(s, walk: Dictionary) -> int:
	var n := 0
	for p in walk:
		if s.tile_at(p) == "grass" and _river_beside(s, p).x >= 0:
			n += 1
	return n


## How many tiles of each resource the Kith can get at: the tile is on the walk, or beside it. Only tiles
## within `radius` (a square) of the Hearth.
static func _reachable_counts(s, walk: Dictionary, camp: Vector2i, radius: int) -> Dictionary:
	var counts := {}
	for y in range(maxi(camp.y - radius, 0), mini(camp.y + radius + 1, s.height)):
		for x in range(maxi(camp.x - radius, 0), mini(camp.x + radius + 1, s.width)):
			var p := Vector2i(x, y)
			var tile: String = s.tile_at(p)
			if tile == "grass" or tile == "river" or tile == "shard":
				continue
			if walk.has(p) or NEIGHBORS.any(func(n): return walk.has(p + n)):
				counts[tile] = counts.get(tile, 0) + 1
	return counts


## Every tile that can be walked to from `from` without crossing the river (or rock, unless `over_rock`).
static func _flood(s, from: Vector2i, over_rock: bool) -> Dictionary:
	var seen := {from: true}
	var todo: Array = [from]
	var head := 0
	while head < todo.size():
		var p: Vector2i = todo[head]
		head += 1
		for n in NEIGHBORS:
			var q: Vector2i = p + n
			var tile: String = s.tile_at(q)
			if tile == "" or tile == "river" or (tile == "rock" and not over_rock) or seen.has(q):
				continue
			seen[q] = true
			todo.append(q)
	return seen


## Make the last resort map fair: the Hearth's ground cleared of river, what it lacks made out of the
## nearest reachable grass, and a Strange Stone put down if there is none. Rarely needed.
static func patch(s, land: Dictionary) -> void:
	var camp: Vector2i = s.camp_pos
	for q in land["water"]:
		var d: Vector2i = q - camp
		if d.x >= FOOTPRINT_MIN.x and d.x <= FOOTPRINT_MAX.x and d.y >= FOOTPRINT_MIN.y and d.y <= FOOTPRINT_MAX.y:
			s.set_tile(q, "grass")
	var rng := RandomNumberGenerator.new()
	rng.seed = camp.x * 1000 + camp.y
	_lay_hearth(s, rng)
	for p in land["zone"]:  # the floodplain is open ground again
		if s.tile_at(p) != "river" and _cheb(p, camp) > 2:
			s.set_tile(p, "grass")
	for tile in NEAR_MIN:
		_top_up(s, tile, NEAR_MIN[tile], Data.SIGHT_START)
	for tile in REACH_MIN:
		_top_up(s, tile, REACH_MIN[tile], 1000)
	_open_up_banks(s)
	if not s.in_bounds(s.shard_pos) or s.tile_at(s.shard_pos) != "shard":
		_lay_shard(s, land)
	if not s.in_bounds(s.shard_pos) or s.tile_at(s.shard_pos) != "shard":  # nowhere lone: anywhere far and reachable
		_shard_anywhere(s)


## Fell trees on the reachable river bank, nearest the Hearth first, until there are open banks enough.
static func _open_up_banks(s) -> void:
	var camp: Vector2i = s.camp_pos
	var walk := _flood(s, camp, false)
	var need := OPEN_BANK_MIN - _open_banks(s, walk)
	var trees: Array = []
	for p in walk:
		if s.tile_at(p) == "tree" and _river_beside(s, p).x >= 0:
			trees.append(p)
	var near_first := func(p: Vector2i) -> int: return -int(Vector2(p).distance_to(Vector2(camp)) * 100.0)
	for p in _top(trees, near_first, maxi(need, 0)):
		s.set_tile(p, "grass")


## Turn the nearest reachable grass into `tile` until the map has `need` of it within `radius` of the Hearth.
static func _top_up(s, tile: String, need: int, radius: int) -> void:
	var camp: Vector2i = s.camp_pos
	var walk := _flood(s, camp, false)
	var have: int = _reachable_counts(s, walk, camp, radius).get(tile, 0)
	var bank := tile == "clay" or tile == "gravel"
	var cells: Array = []
	for p in walk:
		if s.tile_at(p) == "grass" and _cheb(p, camp) > 2 and _cheb(p, camp) <= radius:
			if not bank or _river_beside(s, p).x >= 0:
				cells.append(p)
	var near_first := func(p: Vector2i) -> int: return -int(Vector2(p).distance_to(Vector2(camp)) * 100.0)
	for p in _top(cells, near_first, maxi(need - have, 0)):
		s.set_tile(p, tile)


## The reachable grass tile farthest from the Hearth becomes the Strange Stone.
static func _shard_anywhere(s) -> void:
	var camp: Vector2i = s.camp_pos
	var best := Vector2i(-1, -1)
	var best_d := 10.0
	for p in _flood(s, camp, true):
		var d := Vector2(p).distance_to(Vector2(camp))
		if s.tile_at(p) == "grass" and d > best_d:
			best_d = d
			best = p
	if best.x >= 0:
		s.set_tile(best, "shard")
		s.shard_pos = best


# --- Small maps ---------------------------------------------------------------------


## A map too small for terrain (the tests use tiny Worlds): a river strip, the Hearth's patches and a
## Strange Stone on the tile farthest from it.
static func _plain_map(s, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	s.reset("grass")
	s.shard_pos = Vector2i(-1, -1)
	if s.width >= 6:
		var rx: int = s.width * 2 / 3
		for y in s.height:
			s.set_tile(Vector2i(rx, y), "river")
			s.set_tile(Vector2i(rx + 1, y), "river")
	s.camp_pos = Vector2i(clampi(s.width / 3, 0, s.width - 1), clampi(s.height / 2, 0, s.height - 1))
	_lay_hearth(s, rng)
	var best_d := 0.0
	for y in s.height:
		for x in s.width:
			var p := Vector2i(x, y)
			var d := Vector2(p).distance_to(Vector2(s.camp_pos))
			if s.tile_at(p) == "grass" and d > best_d:
				best_d = d
				s.shard_pos = p
	if s.in_bounds(s.shard_pos):
		s.set_tile(s.shard_pos, "shard")


# --- Helpers ------------------------------------------------------------------------


## Grass that no layer has claimed and that is not on the floodplain.
static func _free(s, land: Dictionary, p: Vector2i) -> bool:
	return s.tile_at(p) == "grass" and not land["zone"].has(p)


## Chebyshev distance: the size of the square between two tiles.
static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## How many of the tiles in the square of `radius` around p (p itself too) are `tile`.
static func _count_near(s, p: Vector2i, tile: String, radius: int) -> int:
	var n := 0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if s.tile_at(p + Vector2i(dx, dy)) == tile:
				n += 1
	return n


## The `count` cells with the highest score (ties by row, then column).
static func _top(cells: Array, score: Callable, count: int) -> Array:
	var ranked: Array = []
	for p in cells:
		ranked.append(Vector3i(score.call(p), p.y, p.x))
	ranked.sort_custom(func(a, b): return a.x > b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z))))
	var out: Array = []
	for i in mini(count, ranked.size()):
		out.append(Vector2i(ranked[i].z, ranked[i].y))
	return out
