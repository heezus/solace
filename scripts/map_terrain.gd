extends RefCounted
## The land under a new map: a height field with a high side and a low side, the river that runs down it
## (with a tributary or a fork on some seeds) and how wet each tile is. MapGen turns this land into tiles.
## Static, and it knows nothing of tiles or resources. The noise is sampled once and rounded to whole
## thousandths, and everything after that is integer work, so a seed makes the same land on every run.
##
## make() returns a Dictionary:
##   "w", "h"   the map size
##   "dir"      Vector2i: which way is up (the high side lies that way)
##   "height"   PackedInt32Array, thousandths, index y * w + x
##   "paths"    Array of Array[Vector2i]: the river first (source to mouth), then its tributary or fork
##   "water"    Dictionary Vector2i -> Vector2i(path number, index on it) for every river tile
##   "dist"     PackedInt32Array: steps (side by side) from the nearest river tile
##   "wet"      PackedInt32Array, thousandths: high near the river, falling off, with noise mixed in

## Which way is up: the four sides and the four corners.
const DIRS := [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(1, -1),
	Vector2i(-1, -1),
]
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const TILT := 600  # thousandths of height from one side of the map to the other
const HILLS := 500  # thousandths of height the noise adds or takes away
const HILL_FREQ := 0.07
const MEANDER_FREQ := 0.13
const WET_FALL := 110  # wetness lost per step away from the river
const UPHILL_DIV := 5  # a river pays (climb / this) extra for a step up: it goes round hills
const RIVER_START := 5  # the river is 1 wide until this share (in fifths) of the way down, then 2
const NONE := 1000000


## The land for `land_seed` on a `w` by `h` map.
static func make(w: int, h: int, land_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = land_seed
	var t := {"w": w, "h": h, "dir": DIRS[rng.randi_range(0, DIRS.size() - 1)]}
	t["height"] = _height_field(w, h, land_seed, t["dir"])
	t["meander"] = _sampled(w, h, noise(land_seed + 1, MEANDER_FREQ, 2), 14, 14)
	t["paths"] = _rivers(t, rng)
	t["water"] = water_tiles(t["paths"], w, h)
	t["dist"] = _river_distance(t)
	t["wet"] = _wetness(t, land_seed)
	return t


## Whole-number division, rounded toward zero (the integer / would warn).
static func div(a: int, b: int) -> int:
	return int(a / float(b))


static func noise(noise_seed: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = noise_seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n


## A noise field as whole numbers: `mid + noise * spread`, index y * w + x.
static func _sampled(w: int, h: int, n: FastNoiseLite, mid: int, spread: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			out[y * w + x] = roundi(mid + n.get_noise_2d(x, y) * spread)
	return out


## The same, in thousandths from -1000 to 1000, for a noise seed (MapGen reads its own fields this way).
static func noise_field(w: int, h: int, noise_seed: int, freq: float) -> PackedInt32Array:
	return _sampled(w, h, noise(noise_seed, freq, 3), 0, 1000)


static func _height_field(w: int, h: int, land_seed: int, dir: Vector2i) -> PackedInt32Array:
	var hills := noise(land_seed, HILL_FREQ, 4)
	var up := Vector2(dir).normalized()
	var out := PackedInt32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			var p := Vector2((x + 0.5) / w * 2.0 - 1.0, (y + 0.5) / h * 2.0 - 1.0)
			out[y * w + x] = roundi(p.dot(up) * TILT + hills.get_noise_2d(x, y) * HILLS)
	return out


# --- The river ---------------------------------------------------------------


static func _rivers(t: Dictionary, rng: RandomNumberGenerator) -> Array:
	var main := _main_river(t, rng)
	var paths: Array = [main]
	var roll := rng.randi_range(0, 9)
	if roll >= 7:
		_add_stream(paths, _fork(t, main, rng))
	elif roll >= 4:
		_add_stream(paths, _tributary(t, main, rng))
	return paths


static func _add_stream(paths: Array, stream: Array) -> void:
	if stream.size() >= 4:
		paths.append(stream)


static func _main_river(t: Dictionary, rng: RandomNumberGenerator) -> Array:
	var edge := border_by_height(t)
	var from: Vector2i = edge[rng.randi_range(0, mini(4, edge.size() - 1))]  # one of the five highest edge tiles
	var low := _low_edge(edge)
	var far := maxi(div(mini(t["w"], t["h"]) * 3, 4), 3)
	return route(t, from, func(p): return low.has(p) and _steps(p, from) >= far, _flow_cost.bind(t, {}))


## A stream from high ground on the edge that runs down into the river.
static func _tributary(t: Dictionary, main: Array, rng: RandomNumberGenerator) -> Array:
	var bank := water_tiles([main], t["w"], t["h"])
	var edge := border_by_height(t).filter(func(p): return _dist_to(bank, p) > 6)
	if edge.is_empty():
		return []
	var from: Vector2i = edge[rng.randi_range(0, mini(3, edge.size() - 1))]
	var joins := {}
	for i in range(div(main.size(), 4), main.size()):
		joins[main[i]] = true
	return route(t, from, func(p): return joins.has(p), _flow_cost.bind(t, {}))


## A branch that leaves the river part way down and reaches the edge somewhere else.
static func _fork(t: Dictionary, main: Array, rng: RandomNumberGenerator) -> Array:
	var i := rng.randi_range(div(main.size() * 35, 100), div(main.size() * 60, 100))
	var from: Vector2i = main[i]
	var banned := {}
	for p in main:
		banned[p] = true
	banned.erase(from)
	var mouth: Vector2i = main[main.size() - 1]
	var low := _low_edge(border_by_height(t))
	return route(t, from, func(p): return low.has(p) and _steps(p, mouth) >= 8, _flow_cost.bind(t, banned))


## What a step onto tile b costs the river: a little, plus more for climbing, for hugging the map edge and
## for the meander noise. -1 (never) for a tile in `banned`.
static func _flow_cost(a: Vector2i, b: Vector2i, t: Dictionary, banned: Dictionary) -> int:
	if banned.has(b):
		return -1
	var w: int = t["w"]
	var height: PackedInt32Array = t["height"]
	var climb := maxi(0, height[b.y * w + b.x] - height[a.y * w + a.x])
	var cost: int = 4 + div(climb, UPHILL_DIV) + t["meander"][b.y * w + b.x]
	if b.x == 0 or b.y == 0 or b.x == w - 1 or b.y == t["h"] - 1:
		cost += 60
	elif b.x == 1 or b.y == 1 or b.x == w - 2 or b.y == t["h"] - 2:
		cost += 25
	return cost


static func _steps(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _dist_to(water: Dictionary, p: Vector2i) -> int:
	var best := NONE
	for q in water:
		best = mini(best, _steps(p, q))
	return best


## The edge tiles, highest first (ties by position).
static func border_by_height(t: Dictionary) -> Array:
	var w: int = t["w"]
	var h: int = t["h"]
	var height: PackedInt32Array = t["height"]
	var edge: Array = []
	for y in h:
		for x in w:
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				edge.append(Vector2i(x, y))
	edge.sort_custom(
		func(a, b):
			var ha: int = height[a.y * w + a.x]
			var hb: int = height[b.y * w + b.x]
			return ha > hb or (ha == hb and (a.y < b.y or (a.y == b.y and a.x < b.x)))
	)
	return edge


## The lowest quarter of the edge, as a set.
static func _low_edge(edge_high_first: Array) -> Dictionary:
	var low := {}
	for i in range(div(edge_high_first.size() * 3, 4), edge_high_first.size()):
		low[edge_high_first[i]] = true
	return low


## The cheapest side-by-side route from `from` to the first tile `is_goal` accepts, by Dijkstra over
## `step_cost(a, b)` (-1 for a step that may not be taken). [] when there is no way.
static func route(t: Dictionary, from: Vector2i, is_goal: Callable, step_cost: Callable) -> Array:
	var w: int = t["w"]
	var h: int = t["h"]
	var best := PackedInt32Array()
	best.resize(w * h)
	best.fill(NONE)
	var came := PackedInt32Array()
	came.resize(w * h)
	came.fill(-1)
	var open: Array = [from.y * w + from.x]
	best[open[0]] = 0
	while not open.is_empty():
		var at := 0
		for i in open.size():
			if best[open[i]] < best[open[at]] or (best[open[i]] == best[open[at]] and open[i] < open[at]):
				at = i
		var here: int = open[at]
		open[at] = open[open.size() - 1]
		open.pop_back()
		var p := Vector2i(here % w, div(here, w))
		if p != from and is_goal.call(p):
			return _walk_back(came, here, w)
		for n in NEIGHBORS:
			var q: Vector2i = p + n
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
				continue
			var cost: int = step_cost.call(p, q)
			var qi := q.y * w + q.x
			if cost >= 0 and best[here] + cost < best[qi]:
				if best[qi] == NONE:
					open.append(qi)
				best[qi] = best[here] + cost
				came[qi] = here
	return []


static func _walk_back(came: PackedInt32Array, end: int, w: int) -> Array:
	var path: Array = []
	var at := end
	while at >= 0:
		path.append(Vector2i(at % w, div(at, w)))
		at = came[at]
	path.reverse()
	return path


## Every tile the rivers cover: the main one is 2 wide from RIVER_START fifths of the way down, streams
## are 1 wide. Value: Vector2i(path number, index on that path).
static func water_tiles(paths: Array, w: int, h: int) -> Dictionary:
	var water := {}
	for n in paths.size():
		var path: Array = paths[n]
		for i in path.size():
			var p: Vector2i = path[i]
			water[p] = Vector2i(n, i)
			if n == 0 and i >= div(path.size() * RIVER_START, 10):
				var q := p + _widen(path, i)
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and not water.has(q):
					water[q] = Vector2i(n, i)
	return water


## Which neighbour makes the river 2 wide at step i: east where it runs north-south, south where it runs east-west.
static func _widen(path: Array, i: int) -> Vector2i:
	var a: Vector2i = path[maxi(i - 1, 0)]
	var b: Vector2i = path[mini(i + 1, path.size() - 1)]
	return Vector2i(1, 0) if a.x == b.x else Vector2i(0, 1)


# --- Wetness -----------------------------------------------------------------


static func _river_distance(t: Dictionary) -> PackedInt32Array:
	var w: int = t["w"]
	var h: int = t["h"]
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(NONE)
	var todo: Array = []
	for p in t["water"]:
		dist[p.y * w + p.x] = 0
		todo.append(p)
	todo.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var head := 0
	while head < todo.size():
		var p: Vector2i = todo[head]
		head += 1
		for n in NEIGHBORS:
			var q: Vector2i = p + n
			if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and dist[q.y * w + q.x] == NONE:
				dist[q.y * w + q.x] = dist[p.y * w + p.x] + 1
				todo.append(q)
	return dist


static func _wetness(t: Dictionary, land_seed: int) -> PackedInt32Array:
	var w: int = t["w"]
	var h: int = t["h"]
	var dist: PackedInt32Array = t["dist"]
	var mix := _sampled(w, h, noise(land_seed + 2, 0.11, 3), 500, 500)  # 0 to 1000
	var out := PackedInt32Array()
	out.resize(w * h)
	for i in w * h:
		var near := maxi(0, 1000 - dist[i] * WET_FALL)
		out[i] = clampi(div(near * 7, 10) + div(mix[i] * 3, 10), 0, 1000)
	return out


# --- Reading the land --------------------------------------------------------


## The height below which `share_pct` percent of the map lies.
static func height_at_percent(t: Dictionary, share_pct: int) -> int:
	var sorted: PackedInt32Array = t["height"].duplicate()
	sorted.sort()
	return sorted[clampi(div(sorted.size() * share_pct, 100), 0, sorted.size() - 1)]


static func height_of(t: Dictionary, p: Vector2i) -> int:
	return t["height"][p.y * t["w"] + p.x]


static func wet_of(t: Dictionary, p: Vector2i) -> int:
	return t["wet"][p.y * t["w"] + p.x]


static func dist_of(t: Dictionary, p: Vector2i) -> int:
	return t["dist"][p.y * t["w"] + p.x]
