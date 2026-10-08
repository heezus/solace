extends RefCounted
## The land that grows south when the first of Coal Seams or Ironstone is learned (design-system/19-ironfall.md): a strip as
## wide as the map is then, laid under its south edge. It is made from the map's seed, so a seed always grows the same land,
## and it never touches what is already there. It is open country with forest and rock, and it holds the era's two ores:
## three Coal Seams near its north edge (the near side), each a few tiles that share one pile (World.seam_left), and
## plentiful Iron Hills further in. Stage 2 adds the three Bloom patches at its far (south) edge: a small spread of Bloom
## ground with a sample tile at its middle, one each of the Spore, Root and Sap samples, left to right (Data.BLOOM_TILES).
## They are laid after the ore, from a random stream of their own, so the coal and iron of a seed are what stage 1 made.
##
## Fairness works like MapEast's: make() builds a strip, faults_of() says what is wrong with it, and a strip that fails is
## thrown away and another is made from the next attempt seed. The strip needs exactly COAL_SEAMS separate seams, enough iron
## and some of it near, and the way south must be open: at most MAX_CROSSINGS river tiles between the Hearth and the old
## map's south edge. Static, and works on the World passed in: it reads the old tiles and the Hearth and returns the new tiles.

const Data = preload("res://scripts/data.gd")
const Terrain = preload("res://scripts/map_terrain.gd")

const ATTEMPTS := 12
const COAL_SEAMS := 3
const COAL_TILES_MIN := 4  # tiles in a seam, at least
const COAL_TILES_MAX := 7
const COAL_ROWS := 9  # the seams lie in the strip's first rows: the near side
const IRON_CLUSTERS := 6
const IRON_NEAR_CLUSTERS := 2  # the first of them lie in the near rows too
const IRON_MIN := 22  # Iron Hills tiles in the strip, at least
const IRON_NEAR_MIN := 6  # ...of them in the first NEAR_ROWS rows
const NEAR_ROWS := 13
const MAX_CROSSINGS := 3  # river tiles between the Hearth and the strip, at most
const BLOOM_ROWS := 8  # a patch lies in the strip's last rows: the far edge of the fog
const BLOOM_GROUND_MIN := 5  # tiles in a patch (its ground and its sample), at least
const BLOOM_GROUND_MAX := 9
const BLOOM_APART := 7  # tiles between two patches' middles, at least
const FOREST_PERCENT := 13
const ROCK_PERCENT := 6
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const NONE := 1000


## The new land for `s` (a World that has not grown south): an Array of tile ids, `width` by Data.SOUTH_ROWS, row by row.
## `report` is filled with "attempts", "faults" (what the chosen strip still fails, [] for a fair one) and "crossings".
static func make(s, report: Dictionary = {}) -> Array:
	var best: Array = []
	var best_faults: Array = ["no attempt"]
	var tries := 0
	while tries < ATTEMPTS and not best_faults.is_empty():
		var strip := _attempt(s, south_seed(s.map_seed, tries))
		var faults := faults_of(s, strip)
		tries += 1
		if best.is_empty() or faults.size() < best_faults.size():
			best = strip
			best_faults = faults
	report["attempts"] = tries
	report["faults"] = best_faults
	report["crossings"] = crossings_to_south(s)
	return best


## The seed of attempt `k` for a map seed: a fixed sequence, so a reroll is as repeatable as the first try.
static func south_seed(map_seed: int, k: int) -> int:
	return absi(map_seed * 1597334677 + k * 7919 + 313) % 2147483647


static func _attempt(s, land_seed: int) -> Array:
	var w: int = s.width
	var h: int = Data.SOUTH_ROWS
	var rng := RandomNumberGenerator.new()
	rng.seed = land_seed
	var strip: Array = []
	strip.resize(w * h)
	strip.fill("grass")
	_scatter(strip, Terrain.noise_field(w, h, land_seed + 1, 0.12), w, h, FOREST_PERCENT, "tree")
	_scatter(strip, Terrain.noise_field(w, h, land_seed + 2, 0.13), w, h, ROCK_PERCENT, "rock")
	_lay_coal(strip, w, h, rng)
	_lay_iron(strip, w, h, rng)
	var bloom_rng := RandomNumberGenerator.new()
	bloom_rng.seed = land_seed + 9
	_lay_bloom(strip, w, h, bloom_rng)
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


## Three seams, one in each third of the strip's width, in its first COAL_ROWS rows: a short walk of COAL_TILES_MIN to MAX tiles.
static func _lay_coal(strip: Array, w: int, _h: int, rng: RandomNumberGenerator) -> void:
	for i in COAL_SEAMS:
		var lo := 2 + Terrain.div(w * i, COAL_SEAMS)
		var hi := Terrain.div(w * (i + 1), COAL_SEAMS) - 3
		var at := Vector2i(rng.randi_range(lo, hi), rng.randi_range(2, COAL_ROWS - 1))
		var laid := 0
		var want := rng.randi_range(COAL_TILES_MIN, COAL_TILES_MAX)
		var guard := 0
		while laid < want and guard < 60:
			guard += 1
			if strip[at.y * w + at.x] != "coal_seam":
				strip[at.y * w + at.x] = "coal_seam"
				laid += 1
			var next: Vector2i = at + NEIGHBORS[rng.randi_range(0, 3)]
			if next.x >= lo and next.x <= hi and next.y >= 1 and next.y < COAL_ROWS:
				at = next


## Iron Hills in blobs: the first clusters in the near rows (the way in), the rest anywhere deeper. They never cover coal.
static func _lay_iron(strip: Array, w: int, h: int, rng: RandomNumberGenerator) -> void:
	var centres: Array = []
	for i in IRON_CLUSTERS:
		var near := i < IRON_NEAR_CLUSTERS
		var lo := 2 if near else NEAR_ROWS - 2
		var hi := NEAR_ROWS - 1 if near else h - 3
		for attempt in 30:
			var c := Vector2i(rng.randi_range(2, w - 3), rng.randi_range(lo, hi))
			if centres.all(func(o): return maxi(absi(o.x - c.x), absi(o.y - c.y)) >= 5):
				centres.append(c)
				break
	for c in centres:
		var at: Vector2i = c
		for i in rng.randi_range(4, 7):
			if at.x >= 0 and at.y >= 0 and at.x < w and at.y < h and strip[at.y * w + at.x] != "coal_seam":
				strip[at.y * w + at.x] = "iron_hills"
			at += NEIGHBORS[rng.randi_range(0, 3)]


## The three Bloom patches, one in each third of the strip's width, in its last BLOOM_ROWS rows: a sample tile (spore, root, sap
## from the west) with a handful of Bloom ground round it. A patch never covers ore, and it takes the trees and rocks it grows over.
static func _lay_bloom(strip: Array, w: int, h: int, rng: RandomNumberGenerator) -> void:
	for i in Data.BLOOM_KINDS.size():
		var lo := 3 + Terrain.div(w * i, Data.BLOOM_KINDS.size())
		var hi := Terrain.div(w * (i + 1), Data.BLOOM_KINDS.size()) - 4
		var at := Vector2i(Terrain.div(lo + hi, 2), h - 4)
		for attempt in 30:
			var c := Vector2i(rng.randi_range(lo, hi), rng.randi_range(h - BLOOM_ROWS + 2, h - 3))
			if _bare(strip[c.y * w + c.x]):
				at = c
				break
		var want := rng.randi_range(BLOOM_GROUND_MIN, BLOOM_GROUND_MAX) - 1
		var spread: Array = []
		var edge: Array = [at]
		while spread.size() < want and not edge.is_empty():
			var from: Vector2i = edge.pop_front()
			for n in NEIGHBORS:
				var q: Vector2i = from + n
				if q.x < 1 or q.x >= w - 1 or q.y < h - BLOOM_ROWS or q.y >= h:
					continue
				if q != at and not spread.has(q) and _bare(strip[q.y * w + q.x]) and rng.randi_range(0, 2) > 0:
					spread.append(q)
					edge.append(q)
					if spread.size() >= want:
						break
		for q in spread:
			strip[q.y * w + q.x] = Data.BLOOM_GROUND
		strip[at.y * w + at.x] = Data.BLOOM_TILES[Data.BLOOM_KINDS[i]]


## True for a strip tile a patch may cover: not ore, not another patch.
static func _bare(tile: String) -> bool:
	return tile in ["grass", "tree", "rock"]


# --- Fairness ----------------------------------------------------------------------


## What is wrong with `strip`, as short sentences: [] when it is fair.
static func faults_of(s, strip: Array) -> Array:
	var faults: Array = []
	var w: int = s.width
	var iron := 0
	var near := 0
	for i in strip.size():
		if strip[i] == "iron_hills":
			iron += 1
			near += 1 if floori(float(i) / w) < NEAR_ROWS else 0
	var seams := seams_in(strip, w)
	if seams.size() != COAL_SEAMS:
		faults.append("%d coal seams, not %d" % [seams.size(), COAL_SEAMS])
	for seam in seams:
		if seam.size() < COAL_TILES_MIN:
			faults.append("a coal seam of %d tiles" % seam.size())
	if iron < IRON_MIN:
		faults.append("too little iron (%d)" % iron)
	if near < IRON_NEAR_MIN:
		faults.append("too little iron in the near rows (%d)" % near)
	faults.append_array(_bloom_faults(strip, w, int(float(strip.size()) / float(w))))
	var cross := crossings_to_south(s)
	if cross > MAX_CROSSINGS:
		faults.append("the new land is %d river tiles away (at most %d)" % [cross, MAX_CROSSINGS])
	return faults


## What is wrong with the Bloom patches in `strip` (`w` wide, `h` tall): one sample of each kind, each with enough ground, all
## in the far rows and well apart.
static func _bloom_faults(strip: Array, w: int, h: int) -> Array:
	var faults: Array = []
	var middles: Array = []
	for kind in Data.BLOOM_KINDS:
		var at: int = strip.find(Data.BLOOM_TILES[kind])
		if at < 0 or strip.count(Data.BLOOM_TILES[kind]) != 1:
			faults.append("no single %s sample" % kind)
			continue
		var p := Vector2i(at % w, floori(float(at) / w))
		middles.append(p)
		if p.y < h - BLOOM_ROWS:
			faults.append("the %s patch is not at the far edge" % kind)
		var ground := 1
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var q := p + Vector2i(dx, dy)
				if q.x >= 0 and q.x < w and q.y >= 0 and q.y < h and strip[q.y * w + q.x] == Data.BLOOM_GROUND:
					ground += 1
		if ground < BLOOM_GROUND_MIN:
			faults.append("the %s patch has %d tiles" % [kind, ground])
	for i in middles.size():
		for j in range(i + 1, middles.size()):
			if maxi(absi(middles[i].x - middles[j].x), absi(middles[i].y - middles[j].y)) < BLOOM_APART:
				faults.append("two Bloom patches stand side by side")
	return faults


## The coal seams in `strip` (`w` wide) as lists of tile indexes: the connected groups of coal tiles, side by side, in row order.
static func seams_in(strip: Array, w: int) -> Array:
	var seams: Array = []
	var taken := {}
	for i in strip.size():
		if strip[i] != "coal_seam" or taken.has(i):
			continue
		var group: Array = []
		var todo: Array = [i]
		taken[i] = true
		while not todo.is_empty():
			var at: int = todo.pop_back()
			group.append(at)
			var p := Vector2i(at % w, floori(float(at) / w))
			for n in NEIGHBORS:
				var q: Vector2i = p + n
				var qi := q.y * w + q.x
				if (
					q.x >= 0
					and q.x < w
					and q.y >= 0
					and qi < strip.size()
					and strip[qi] == "coal_seam"
					and not taken.has(qi)
				):
					taken[qi] = true
					todo.append(qi)
		seams.append(group)
	return seams


## The fewest river tiles a walker from the Hearth must cross to reach the old map's south edge, from where the new land goes
## on (the strip has no river). 0 when it can be walked to by land; NONE when it cannot be reached at all.
static func crossings_to_south(s) -> int:
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
				if q.x < 0 or q.x >= s.width or q.y < 0 or q.y >= s.height:
					continue
				var cost := 1 if s.tile_at(q) == "river" else 0
				if not dist.has(q) or d + cost < dist[q]:
					dist[q] = d + cost
					if cost == 0:
						level.append(q)
					else:
						next.append(q)
		d += 1
		level = next
		next = []
	var best := NONE
	for x in s.width:
		var edge := Vector2i(x, s.height - 1)
		if dist.has(edge):
			best = mini(best, dist[edge])
	return best
