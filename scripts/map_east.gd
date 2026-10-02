extends RefCounted
## The land that grows east when Bronze Dawn is researched (design-system/10-bronze-dawn.md): a strip as wide as
## the stone-age map and as tall, laid beside its east edge. It is made from the map's seed, so a seed always grows
## the same land, and it never touches the stone-age half. It is open country with forest and rock, and it holds the
## era's two ores: Copper Hills, common and near the strip's west edge (the way in), and a short Tin Stream, three
## tiles, far off in the north-east corner.
##
## Fairness works like MapGen's: make() builds a strip, faults_of() says what is wrong with it, and a strip that fails
## is thrown away and another is made from the next attempt seed (a fixed sequence). Besides the ore counts and where
## they lie, the tin must be reachable: by land, or across the stone-age river by a bridge (or a raft), which is no more
## than MAX_CROSSINGS river tiles on the way from the Hearth. And a road must be able to follow the way (road_ways): over
## the ground roads go on, with a bridge for each river tile, to both ores. Static, and works on the World passed in: it
## reads the stone-age tiles and the Hearth and returns the new tiles, it sets nothing.

const Terrain = preload("res://scripts/map_terrain.gd")

const ATTEMPTS := 12
const COPPER_CLUSTERS := 5  # the first COPPER_NEAR_CLUSTERS of them lie in the west zone
const COPPER_NEAR_CLUSTERS := 3
const COPPER_MIN := 14  # Copper Hills tiles in the strip, at least
const COPPER_NEAR_MIN := 8  # ...of them within WEST_ZONE columns of its west edge
const WEST_ZONE := 10
const TIN_TILES := 3
const MAX_CROSSINGS := 3  # river tiles between the Hearth and the ore, at most (a bridge is dragged across them)
const FOREST_PERCENT := 14
const ROCK_PERCENT := 5
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const ROAD_TILES := ["grass", "rock", "tree", "river"]  # what a road (or a bridge, on the river) can be laid on
const RIVER_WEIGHT := 1000000  # in a road's price a river tile outweighs any run of dry tiles: fewest bridges first
const ROCK_WEIGHT := 1000  # then fewest passes cut through rocks (3 Stone each), then the shortest way
const NONE := 1000000  # "rivers" of an ore no road can reach


## The new land for `s` (a World that has not grown): an Array of tile ids, `stone_width` by `height`, row by row.
## `report` is filled with "attempts" (how many strips were made) and "faults" (what the chosen one still fails, [] for
## a fair one), and "crossings" (river tiles to cross to reach it).
static func make(s, report: Dictionary = {}) -> Array:
	var best: Array = []
	var best_faults: Array = ["no attempt"]
	var tries := 0
	while tries < ATTEMPTS and not best_faults.is_empty():
		var strip := _attempt(s, east_seed(s.map_seed, tries))
		var faults := faults_of(s, strip)
		tries += 1
		if best.is_empty() or faults.size() < best_faults.size():
			best = strip
			best_faults = faults
	report["attempts"] = tries
	report["faults"] = best_faults
	report["crossings"] = crossings_to_east(s)
	return best


## The seed of attempt `k` for a map seed: a fixed sequence, so a reroll is as repeatable as the first try.
static func east_seed(map_seed: int, k: int) -> int:
	return absi(map_seed * 2654435761 + k * 40503 + 91) % 2147483647


static func _attempt(s, land_seed: int) -> Array:
	var w: int = s.stone_width
	var h: int = s.height
	var rng := RandomNumberGenerator.new()
	rng.seed = land_seed
	var strip: Array = []
	strip.resize(w * h)
	strip.fill("grass")
	_scatter(strip, Terrain.noise_field(w, h, land_seed + 1, 0.12), w, h, FOREST_PERCENT, "tree")
	_scatter(strip, Terrain.noise_field(w, h, land_seed + 2, 0.13), w, h, ROCK_PERCENT, "rock")
	_lay_copper(strip, w, h, rng)
	_lay_tin(strip, w, h, rng)
	return strip


## `percent` of the strip's grass becomes `tile`: the cells the noise scores highest (ties by row, then column).
static func _scatter(strip: Array, noise: PackedInt32Array, w: int, h: int, percent: int, tile: String) -> void:
	var ranked: Array = []
	for y in h:
		for x in w:
			if strip[y * w + x] == "grass":
				ranked.append(Vector3i(noise[y * w + x], y, x))
	ranked.sort_custom(func(a, b): return a.x > b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z))))
	for i in mini(Terrain.div(w * h * percent, 100), ranked.size()):
		strip[ranked[i].y * w + ranked[i].z] = tile


## Copper Hills in blobs: the first clusters in the west zone (the strip's west edge, so the ore is near the way in),
## the rest further in.
static func _lay_copper(strip: Array, w: int, h: int, rng: RandomNumberGenerator) -> void:
	var centres: Array = []
	for i in COPPER_CLUSTERS:
		var near := i < COPPER_NEAR_CLUSTERS
		var lo := 1 if near else WEST_ZONE + 2
		var hi := WEST_ZONE if near else Terrain.div(w * 2, 3)
		for attempt in 30:
			var c := Vector2i(rng.randi_range(lo, hi), rng.randi_range(2, h - 3))
			if centres.all(func(o): return maxi(absi(o.x - c.x), absi(o.y - c.y)) >= 4):
				centres.append(c)
				break
	for c in centres:
		var at: Vector2i = c
		for i in rng.randi_range(4, 7):
			_put(strip, w, h, at, "copper_hills")
			at += NEIGHBORS[rng.randi_range(0, 3)]


## A short Tin Stream in the north-east corner: TIN_TILES tiles in a row of steps, the last third of the strip across and
## the top third down. The start is chosen by the generator, so the stream is not always in the same corner cell.
static func _lay_tin(strip: Array, w: int, h: int, rng: RandomNumberGenerator) -> void:
	var x_min := Terrain.div(w * 2, 3)
	var y_max := Terrain.div(h, 3)
	var at := Vector2i(rng.randi_range(x_min + 1, w - 3), rng.randi_range(1, y_max - 1))
	var laid := 0
	var guard := 0
	while laid < TIN_TILES and guard < 60:
		guard += 1
		if at.x >= x_min and at.x < w - 1 and at.y >= 1 and at.y <= y_max and strip[at.y * w + at.x] != "tin_stream":
			strip[at.y * w + at.x] = "tin_stream"
			laid += 1
		var next: Vector2i = at + NEIGHBORS[rng.randi_range(0, 3)]
		if next.x >= x_min and next.x < w - 1 and next.y >= 1 and next.y <= y_max:
			at = next


static func _put(strip: Array, w: int, h: int, p: Vector2i, tile: String) -> void:
	if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
		strip[p.y * w + p.x] = tile


# --- Fairness ----------------------------------------------------------------------


## What is wrong with `strip`, as short sentences: [] when it is fair. There is copper, a good share of it near the
## west edge, exactly TIN_TILES of tin in the north-east, and the way there is open: at most MAX_CROSSINGS river
## tiles from the Hearth (the east of the stone-age map is walked round or bridged).
static func faults_of(s, strip: Array) -> Array:
	var faults: Array = []
	var w: int = s.stone_width
	var copper := 0
	var near := 0
	var tin := 0
	for i in strip.size():
		if strip[i] == "copper_hills":
			copper += 1
			near += 1 if i % w < WEST_ZONE else 0
		elif strip[i] == "tin_stream":
			tin += 1
	if copper < COPPER_MIN:
		faults.append("too little copper (%d)" % copper)
	if near < COPPER_NEAR_MIN:
		faults.append("too little copper near the west edge (%d)" % near)
	if tin != TIN_TILES:
		faults.append("tin is %d tiles, not %d" % [tin, TIN_TILES])
	var cross := crossings_to_east(s)
	if cross > MAX_CROSSINGS:
		faults.append("the new land is %d river tiles away (at most %d)" % [cross, MAX_CROSSINGS])
	var ways := road_ways(s, strip)
	for ore in ways:
		if ways[ore]["rivers"] > MAX_CROSSINGS:
			faults.append("no road reaches the %s within %d bridges" % [ore, MAX_CROSSINGS])
	return faults


## What a road from the Hearth faces on its way to each ore, over the stone-age map of `s` and the new `strip` beside it:
## {"copper": {...}, "tin": {...}}, each with "rivers" (river tiles to bridge, NONE when no road can get there), "rocks"
## (rock tiles to cut a pass through), "steps" (tiles of road) and "at" (the ore tile it ends beside). It is the cheapest
## way from the Hearth over grass, forest, rocks and river (fewest bridges first, then fewest passes, then the shortest)
## to a tile beside the nearest ore of that kind. Gravel, clay and the like cannot take a road, so a bank of them is no
## way across.
static func road_ways(s, strip: Array) -> Dictionary:
	var w: int = s.stone_width
	var h: int = s.height
	var tiles: Array = []
	tiles.resize(w * 2 * h)
	for y in h:
		for x in w:
			tiles[y * w * 2 + x] = s.tile_at(Vector2i(x, y))
			tiles[y * w * 2 + w + x] = strip[y * w + x]
	var cost := _road_costs(tiles, w * 2, h, s.camp_pos)
	return {
		"copper": _cheapest_beside(tiles, cost, w * 2, h, "copper_hills"),
		"tin": _cheapest_beside(tiles, cost, w * 2, h, "tin_stream"),
	}


## The price of the cheapest road from `from` to every tile (index -> price) a road can reach: a binary heap of
## price * 4096 + index.
static func _road_costs(tiles: Array, w: int, h: int, from: Vector2i) -> Dictionary:
	var cost := {from.y * w + from.x: 0}
	var heap: Array = [from.y * w + from.x]
	while not heap.is_empty():
		var top: int = heap[0]
		var last: int = heap.pop_back()
		if not heap.is_empty():
			heap[0] = last
			var i := 0
			while true:
				var small := i
				for c in [2 * i + 1, 2 * i + 2]:
					if c < heap.size() and heap[c] < heap[small]:
						small = c
				if small == i:
					break
				var swap: int = heap[i]
				heap[i] = heap[small]
				heap[small] = swap
				i = small
		var at := top % 4096
		if top >> 12 != cost[at]:
			continue
		var p := Vector2i(at % w, floori(float(at) / w))
		for n in NEIGHBORS:
			var q: Vector2i = p + n
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
				continue
			var tile: String = tiles[q.y * w + q.x]
			if tile not in ROAD_TILES:
				continue
			var price: int = cost[at] + 1
			if tile == "river":
				price += RIVER_WEIGHT
			elif tile == "rock":
				price += ROCK_WEIGHT
			var qi := q.y * w + q.x
			if not cost.has(qi) or price < cost[qi]:
				cost[qi] = price
				heap.append((price << 12) + qi)
				var j := heap.size() - 1
				while j > 0 and heap[floori(float(j - 1) / 2.0)] > heap[j]:
					var parent := floori(float(j - 1) / 2.0)
					var swap: int = heap[j]
					heap[j] = heap[parent]
					heap[parent] = swap
					j = parent
	return cost


## The cheapest priced tile beside a tile of `ore`, as road_ways describes it.
static func _cheapest_beside(tiles: Array, cost: Dictionary, w: int, h: int, ore: String) -> Dictionary:
	var best := {"rivers": NONE, "rocks": NONE, "steps": NONE, "at": Vector2i(-1, -1)}
	var best_price := -1
	for i in tiles.size():
		if tiles[i] != ore:
			continue
		var p := Vector2i(i % w, floori(float(i) / w))
		for n in NEIGHBORS:
			var q: Vector2i = p + n
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or not cost.has(q.y * w + q.x):
				continue
			var price: int = cost[q.y * w + q.x]
			if tiles[q.y * w + q.x] in ROAD_TILES and (best_price < 0 or price < best_price):
				best_price = price
				best = {
					"rivers": floori(float(price) / RIVER_WEIGHT),
					"rocks": floori(float(price % RIVER_WEIGHT) / ROCK_WEIGHT),
					"steps": price % ROCK_WEIGHT,
					"at": p,
				}
	return best


## The fewest river tiles a walker from the Hearth must cross to reach the stone-age map's east edge, from where the
## new land goes on (the strip has no river). 0 when it can be walked to by land; a bridge or a raft is for the rest.
## 1000 when the edge cannot be reached at all.
static func crossings_to_east(s) -> int:
	var w: int = s.stone_width
	var dist := {s.camp_pos: 0}
	var level: Array = [s.camp_pos]
	var d := 0
	var next: Array = []
	while not level.is_empty():
		var head := 0
		while head < level.size():
			var p: Vector2i = level[head]
			head += 1
			if dist[p] != d:
				continue
			for n in NEIGHBORS:
				var q: Vector2i = p + n
				if q.x < 0 or q.x > w or q.y < 0 or q.y >= s.height:
					continue
				var tile: String = s.tile_at(q) if q.x < w else "grass"
				var cost := 1 if tile == "river" else 0
				if not dist.has(q) or d + cost < dist[q]:
					dist[q] = d + cost
					if cost == 0:
						level.append(q)
					else:
						next.append(q)
		d += 1
		level = next
		next = []
	var best := 1000
	for y in s.height:
		var edge := Vector2i(w, y)
		if dist.has(edge):
			best = mini(best, dist[edge])
	return best
