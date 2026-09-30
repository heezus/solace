extends RefCounted
## Unit testbench for the map generator (scripts/map_gen.gd, scripts/map_terrain.gd): a seed always makes
## the same map, every map on seeds 1 to 30 is fair (everything the opening needs is near the Hearth and
## reachable by land), the river runs downhill from edge to edge, the resources follow the land, the maps
## differ from one another, and a tiny World is safe. It also prints maps 1 to 4 as ASCII so a person can
## look at them. Run from tests/run_tests.gd, which owns check().

const Data = preload("res://scripts/data.gd")
const MapGen = preload("res://scripts/map_gen.gd")
const Terrain = preload("res://scripts/map_terrain.gd")
const World = preload("res://scripts/world.gd")

const SEEDS := 30
const GLYPHS := {
	"grass": ".",
	"river": "~",
	"tree": "T",
	"rock": "^",
	"berry": "b",
	"grain": "g",
	"flax": "f",
	"gravel": ":",
	"clay": "c",
	"shard": "*",
}
const BASIC := ["tree", "rock", "berry", "grain", "flax", "gravel", "clay"]

var t  # the runner, tests/run_tests.gd
var _made: Dictionary = {}  # map seed -> {"world": World, "report": Dictionary}, so each map is made once


func run(runner) -> void:
	t = runner
	test_a_seed_makes_the_same_map()
	test_the_reroll_sequence_is_fixed()
	test_every_map_is_fair()
	test_the_opening_guarantees_are_where_they_always_were()
	test_the_river_runs_from_high_to_low()
	test_there_is_a_river_to_bridge()
	test_the_hearth_is_on_dry_lowland_by_the_river()
	test_there_is_room_for_a_water_wheel()
	test_rocks_lie_high_and_forest_lies_wet()
	test_grain_flax_and_berries_follow_the_land()
	test_clay_and_gravel_lie_on_the_banks()
	test_the_strange_stone_is_a_lone_high_point()
	test_the_ridge_has_a_gap()
	test_maps_differ()
	test_patching_makes_a_ruined_map_fair()
	test_tiny_maps_are_safe()
	print_maps([1, 2, 3, 4])


# --- Helpers -------------------------------------------------------------------


## The map for `map_seed` on the game's size, made once: {"world", "report"}.
func _map(map_seed: int) -> Dictionary:
	if not _made.has(map_seed):
		var w := World.new()
		var report := {}
		MapGen.build(w, map_seed, report)
		_made[map_seed] = {"world": w, "report": report}
	return _made[map_seed]


func _world(map_seed: int) -> World:
	return _map(map_seed)["world"]


func _land(map_seed: int) -> Dictionary:
	return _map(map_seed)["report"]["terrain"]


## The tiles of one kind on a world, in row order.
static func tiles_of(w: World, tile: String) -> Array:
	var found: Array = []
	for y in w.height:
		for x in w.width:
			if w.tile_at(Vector2i(x, y)) == tile:
				found.append(Vector2i(x, y))
	return found


static func mean(values: Array) -> float:
	var total := 0.0
	for v in values:
		total += float(v)
	return total / maxf(values.size(), 1.0)


## The map as text, one row a line: the Hearth is H, the river ~, forest T, rocks ^, berries b, grain g,
## flax f, gravel :, clay c, the Strange Stone *, open grass a dot.
static func ascii(w: World) -> String:
	var rows: Array = []
	for y in w.height:
		var row := ""
		for x in w.width:
			var p := Vector2i(x, y)
			row += "H" if p == w.camp_pos else GLYPHS[w.tile_at(p)]
		rows.append(row)
	return "\n".join(rows)


func print_maps(seeds: Array) -> void:
	for map_seed in seeds:
		print(
			(
				"Map %d (H the Hearth, ~ river, T forest, ^ rock, b berries, g grain, f flax, : gravel, c clay, * the Strange Stone):"
				% map_seed
			)
		)
		print(ascii(_world(map_seed)))


## Every land tile of one component of `tiles` (a Dictionary of positions), side by side: the sizes of the pieces.
static func component_sizes(cells: Dictionary) -> Array:
	var seen := {}
	var sizes: Array = []
	for start in cells:
		if seen.has(start):
			continue
		var size := 0
		var todo: Array = [start]
		seen[start] = true
		while not todo.is_empty():
			var p: Vector2i = todo.pop_back()
			size += 1
			for n in World.NEIGHBORS:
				if cells.has(p + n) and not seen.has(p + n):
					seen[p + n] = true
					todo.append(p + n)
		sizes.append(size)
	return sizes


func _positions(w: World, tile: String) -> Dictionary:
	var cells := {}
	for p in tiles_of(w, tile):
		cells[p] = true
	return cells


# --- Tests ---------------------------------------------------------------------


func test_a_seed_makes_the_same_map() -> void:
	for map_seed in [1, 2, 3, 17, 30]:
		var a := World.new()
		var b := World.new()
		a.generate(map_seed)
		b.generate(map_seed)
		t.check(a.tiles == b.tiles, "seed %d: the same tiles twice" % map_seed)
		t.check(
			a.camp_pos == b.camp_pos and a.shard_pos == b.shard_pos, "seed %d: the same Hearth and stone" % map_seed
		)
		t.check(a.tiles == _world(map_seed).tiles, "seed %d: generate and build agree" % map_seed)
		t.check(a.roads.is_empty() and a.fields.is_empty(), "seed %d: it lays no roads or fields" % map_seed)
	var again := World.new()
	again.generate(9)
	again.generate(9)
	var once := World.new()
	once.generate(9)
	t.check(again.tiles == once.tiles, "generating over an old map gives the same result")
	t.check(_world(1).tiles != _world(2).tiles, "different seeds, different maps")


func test_the_reroll_sequence_is_fixed() -> void:
	var seen := {}
	for k in MapGen.ATTEMPTS:
		var a := MapGen.attempt_seed(5, k)
		t.check(
			a == MapGen.attempt_seed(5, k) and a >= 0 and a < 2147483647,
			"attempt %d has a seed in range, the same each time" % k
		)
		seen[a] = true
	t.check(seen.size() == MapGen.ATTEMPTS, "each attempt has its own seed")
	t.check(MapGen.attempt_seed(5, 0) != MapGen.attempt_seed(6, 0), "and so does each map")
	var a: Dictionary = _map(4)["report"]
	var again := {}
	MapGen.build(World.new(), 4, again)
	t.check(
		again["attempts"] == a["attempts"] and again["patched"] == a["patched"], "the same number of tries every time"
	)
	t.check(a["attempts"] >= 1 and a["attempts"] <= MapGen.ATTEMPTS, "between 1 and %d tries" % MapGen.ATTEMPTS)


func test_every_map_is_fair() -> void:
	var patched := 0
	for map_seed in range(1, SEEDS + 1):
		var w := _world(map_seed)
		var report: Dictionary = _map(map_seed)["report"]
		patched += 1 if report["patched"] else 0
		t.check(report["faults"].is_empty(), "seed %d is fair (%s)" % [map_seed, report["faults"]])
		t.check(MapGen.faults_of(w, _land(map_seed)).is_empty(), "seed %d: faults_of agrees with the report" % map_seed)
		for tile in w.tiles:
			t.check(Data.TILES.has(tile), "seed %d: only known tiles" % map_seed)
			if not Data.TILES.has(tile):
				break
		t.check(w.tiles.size() == World.WIDTH * World.HEIGHT, "seed %d: the World's size" % map_seed)
		for tile in ["river"] + BASIC:
			t.check(w.tiles.has(tile), "seed %d: has %s" % [map_seed, tile])
		# Everything the Hearth needs is inside the first fog radius and can be walked to (no river or rock between).
		var walk := MapGen._flood(w, w.camp_pos, false)
		var near := MapGen._reachable_counts(w, walk, w.camp_pos, Data.SIGHT_START)
		for tile in MapGen.NEAR_MIN:
			t.check(
				near.get(tile, 0) >= MapGen.NEAR_MIN[tile],
				"seed %d: %s in the first fog radius (%d)" % [map_seed, tile, near.get(tile, 0)]
			)
		var whole := MapGen._reachable_counts(w, walk, w.camp_pos, 1000)
		for tile in MapGen.REACH_MIN:
			t.check(
				whole.get(tile, 0) >= MapGen.REACH_MIN[tile],
				"seed %d: %s reachable by land (%d)" % [map_seed, tile, whole.get(tile, 0)]
			)
		t.check(
			w.tile_at(w.camp_pos) == "grass" and w.tiles.count("shard") == 1,
			"seed %d: the Hearth on grass, one stone" % map_seed
		)
		t.check(
			Vector2(w.shard_pos).distance_to(Vector2(w.camp_pos)) > 10.0,
			"seed %d: the stone is more than 10 tiles off" % map_seed
		)
		t.check(MapGen._flood(w, w.camp_pos, true).has(w.shard_pos), "seed %d: and can be walked to" % map_seed)
	t.check(patched == 0, "no seed from 1 to %d needed the last-resort patch (%d did)" % [SEEDS, patched])


## The little patches every map has around the Hearth are still there, at the same offsets from it.
func test_the_opening_guarantees_are_where_they_always_were() -> void:
	for map_seed in range(1, SEEDS + 1):
		var w := _world(map_seed)
		var camp := w.camp_pos
		var want := {
			"flax": MapGen.FLAX_PATCH,
			"tree": MapGen.TREES,
			"rock": MapGen.OUTCROP,
			"berry": MapGen.BERRY_PATCH,
			"grain": MapGen.GRAIN,
			"gravel": MapGen.FLINT,
		}
		for tile in want:
			for off in want[tile]:
				t.check(w.tile_at(camp + off) == tile, "seed %d: %s at the Hearth %s" % [map_seed, tile, off])
		t.check(
			MapGen.FLAX_PATCH == [Vector2i(-2, -3), Vector2i(-1, -3), Vector2i(-2, -4)],
			"the flax patch is where it was"
		)
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				t.check(
					w.tile_at(camp + Vector2i(dx, dy)) == "grass", "seed %d: bare ground round the Hearth" % map_seed
				)


func test_the_river_runs_from_high_to_low() -> void:
	for map_seed in range(1, SEEDS + 1):
		var w := _world(map_seed)
		var land := _land(map_seed)
		var path: Array = land["paths"][0]
		var first: Vector2i = path[0]
		var last: Vector2i = path[path.size() - 1]
		var on_edge := func(p: Vector2i) -> bool:
			return p.x == 0 or p.y == 0 or p.x == w.width - 1 or p.y == w.height - 1
		t.check(
			on_edge.call(first) and on_edge.call(last), "seed %d: the river runs from one edge to another" % map_seed
		)
		t.check(
			Terrain.height_of(land, first) > Terrain.height_of(land, last),
			"seed %d: it starts higher than it ends" % map_seed
		)
		var third := path.size() / 3
		var upper := mean(path.slice(0, third).map(func(p): return Terrain.height_of(land, p)))
		var lower := mean(path.slice(path.size() - third).map(func(p): return Terrain.height_of(land, p)))
		t.check(upper > lower, "seed %d: the top third is higher than the bottom third" % map_seed)
		var joined := true
		for i in range(1, path.size()):
			joined = joined and absi(path[i].x - path[i - 1].x) + absi(path[i].y - path[i - 1].y) == 1
		t.check(joined, "seed %d: the river is one unbroken line of tiles" % map_seed)
		var made_of_river := true
		for p in land["water"]:
			made_of_river = made_of_river and w.tile_at(p) == "river"
		t.check(
			made_of_river and land["water"].size() == w.tiles.count("river"),
			"seed %d: every river tile is on the map, and only those" % map_seed
		)
		t.check(
			component_sizes(_positions(w, "river")).size() == 1,
			"seed %d: with its tributary or fork, one river" % map_seed
		)


func test_there_is_a_river_to_bridge() -> void:
	var with_stream := 0
	for map_seed in range(1, SEEDS + 1):
		var w := _world(map_seed)
		var land := _land(map_seed)
		with_stream += 1 if land["paths"].size() > 1 else 0
		var reach := MapGen._flood(w, w.camp_pos, true)
		var land_tiles: int = w.tiles.size() - w.tiles.count("river")
		t.check(
			reach.size() < land_tiles * 0.92,
			(
				"seed %d: a good part of the land is across the river (%d of %d walked)"
				% [map_seed, reach.size(), land_tiles]
			)
		)
		t.check(reach.size() > land_tiles / 3, "seed %d: and the Hearth's side is a real place to live" % map_seed)
		# A bridge fixes it: with every river tile walkable, all the land is one piece.
		var open := World.new(w.width, w.height)
		open.tiles = w.tiles.duplicate()
		for p in tiles_of(open, "river"):
			open.set_tile(p, "grass")
		t.check(
			MapGen._flood(open, w.camp_pos, true).size() == w.tiles.size(),
			"seed %d: bridging the river joins the two banks" % map_seed
		)
	t.check(
		with_stream >= 5 and with_stream <= SEEDS - 5,
		"some seeds have a tributary or fork, some don't (%d of %d)" % [with_stream, SEEDS]
	)


func test_the_hearth_is_on_dry_lowland_by_the_river() -> void:
	var lowland := 0
	for map_seed in range(1, SEEDS + 1):
		var w := _world(map_seed)
		var land := _land(map_seed)
		var d := Terrain.dist_of(land, w.camp_pos)
		t.check(
			d >= MapGen.CAMP_RIVER.x and d <= MapGen.CAMP_RIVER.y + 2,
			"seed %d: the river is a short walk from the Hearth (%d)" % [map_seed, d]
		)
		t.check(Terrain.wet_of(land, w.camp_pos) <= MapGen.CAMP_WET_MAX, "seed %d: dry ground" % map_seed)
		lowland += 1 if Terrain.height_of(land, w.camp_pos) <= Terrain.height_at_percent(land, 50) else 0
		for dy in range(-5, 6):
			for dx in range(-4, 6):
				t.check(
					w.tile_at(w.camp_pos + Vector2i(dx, dy)) != "river",
					"seed %d: no river on the Hearth's ground" % map_seed
				)
	t.check(lowland == SEEDS, "every Hearth is on the lower half of the land")


## A Water Wheel must touch the river and its workshops stand within 3 tiles: every map keeps open ground on a
## bank the Hearth can walk to, a little way from it (near enough to be built up, far enough to have room).
func test_there_is_room_for_a_water_wheel() -> void:
	for map_seed in range(1, SEEDS + 1):
		var w := _world(map_seed)
		var walk := MapGen._flood(w, w.camp_pos, false)
		var best := 0
		var at := Vector2i(-1, -1)
		for p in walk:
			if w.tile_at(p) == "grass" and w.touches_river(p) and MapGen._cheb(p, w.camp_pos) <= 16:
				var room := MapGen._count_near(w, p, "grass", 3)
				if room > best:
					best = room
					at = p
		t.check(
			best >= MapGen.WHEEL_ROOM,
			"seed %d: open bank for a wheel within 16 tiles of the Hearth (%d grass round %s)" % [map_seed, best, at]
		)
		t.check(MapGen._open_banks(w, walk) >= MapGen.OPEN_BANK_MIN, "seed %d: open bank tiles to build on" % map_seed)


func test_rocks_lie_high_and_forest_lies_wet() -> void:
	var rock_higher := 0
	var forest_closer := 0
	var forest_wetter := 0
	for map_seed in range(1, SEEDS + 1):
		var w := _world(map_seed)
		var land := _land(map_seed)
		var heights := func(tile: String) -> Array:
			return tiles_of(w, tile).map(func(p): return Terrain.height_of(land, p))
		var dists := func(tile: String) -> Array: return tiles_of(w, tile).map(func(p): return Terrain.dist_of(land, p))
		var wets := func(tile: String) -> Array: return tiles_of(w, tile).map(func(p): return Terrain.wet_of(land, p))
		rock_higher += 1 if mean(heights.call("rock")) > mean(heights.call("grain")) else 0
		forest_closer += 1 if mean(dists.call("tree")) < mean(dists.call("grain")) else 0
		forest_wetter += 1 if mean(wets.call("tree")) > mean(wets.call("grain")) else 0
		t.check(
			mean(heights.call("rock")) > mean(heights.call("grass")),
			"seed %d: rocks are higher than open grass on average" % map_seed
		)
		t.check(mean(heights.call("rock")) > mean(heights.call("tree")), "seed %d: and than forest" % map_seed)
		t.check(
			mean(dists.call("tree")) < mean(dists.call("grass")),
			"seed %d: forest is closer to the river than open grass" % map_seed
		)
	t.check(
		rock_higher == SEEDS, "rocks are on higher ground than grain on every map (%d of %d)" % [rock_higher, SEEDS]
	)
	t.check(
		forest_closer == SEEDS,
		"forest is closer to the river than grain on every map (%d of %d)" % [forest_closer, SEEDS]
	)
	t.check(forest_wetter == SEEDS, "and stands on wetter ground (%d of %d)" % [forest_wetter, SEEDS])


func test_grain_flax_and_berries_follow_the_land() -> void:
	var edge := 0
	var berries := 0
	var open_flax := 0
	var flax_tiles := 0
	var grain_mid := 0
	var grain_tiles := 0
	for map_seed in range(1, SEEDS + 1):
		var w := _world(map_seed)
		var land := _land(map_seed)
		for p in tiles_of(w, "berry"):
			berries += 1
			edge += 1 if w.touches(p, "tree") else 0
		for p in tiles_of(w, "flax"):
			flax_tiles += 1
			open_flax += 1 if not w.touches(p, "tree") and not w.touches(p, "rock") and not w.touches_river(p) else 0
		for p in tiles_of(w, "grain"):
			grain_tiles += 1
			var wet := Terrain.wet_of(land, p)
			grain_mid += 1 if wet >= 150 and wet <= 800 and Terrain.dist_of(land, p) >= 2 else 0
	t.check(edge * 100 >= berries * 60, "berries grow at forest edges (%d of %d touch a tree)" % [edge, berries])
	t.check(open_flax * 100 >= flax_tiles * 85, "flax is on open grassland (%d of %d)" % [open_flax, flax_tiles])
	t.check(
		grain_mid * 100 >= grain_tiles * 85,
		"grain is in mid-wet meadows off the bank (%d of %d)" % [grain_mid, grain_tiles]
	)


func test_clay_and_gravel_lie_on_the_banks() -> void:
	var gravel := 0
	var gravel_wet := 0
	var clay := 0
	var clay_wet := 0
	var inside_clay := 0
	var bend_clay := 0
	var outside_gravel := 0
	var bend_gravel := 0
	for map_seed in range(1, SEEDS + 1):
		var w := _world(map_seed)
		var land := _land(map_seed)
		for p in tiles_of(w, "gravel"):
			gravel += 1
			gravel_wet += 1 if Terrain.dist_of(land, p) <= 2 or w.touches(p, "rock") or _by_rock(w, p) else 0
			var side := _bend_side(w, land, p)
			if side != 0:
				bend_gravel += 1
				outside_gravel += 1 if side < 0 else 0
		for p in tiles_of(w, "clay"):
			clay += 1
			clay_wet += 1 if Terrain.dist_of(land, p) <= 2 else 0
			var side := _bend_side(w, land, p)
			if side != 0:
				bend_clay += 1
				inside_clay += 1 if side > 0 else 0
	t.check(gravel_wet * 100 >= gravel * 90, "gravel lies by the river or the rock (%d of %d)" % [gravel_wet, gravel])
	t.check(clay_wet * 100 >= clay * 95, "clay lies by the river (%d of %d)" % [clay_wet, clay])
	t.check(
		bend_clay > 20 and inside_clay * 100 >= bend_clay * 60,
		"clay is mostly on the inside of bends (%d of %d)" % [inside_clay, bend_clay]
	)
	t.check(
		bend_gravel > 20 and outside_gravel * 100 >= bend_gravel * 55,
		"gravel is mostly on the outside (%d of %d)" % [outside_gravel, bend_gravel]
	)
	var flint := 0
	for map_seed in range(1, SEEDS + 1):
		var w := _world(map_seed)
		for p in tiles_of(w, "gravel"):
			flint += 1 if _by_rock(w, p) and Terrain.dist_of(_land(map_seed), p) <= 2 else 0
	t.check(flint >= SEEDS, "flint gravel lies where rock meets the river (%d tiles)" % flint)


static func _by_rock(w: World, p: Vector2i) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if w.tile_at(p + Vector2i(dx, dy)) == "rock":
				return true
	return false


## For a bank tile: +1 on the inside of a bend of the river, -1 on the outside, 0 on a straight or away from the river.
static func _bend_side(w: World, land: Dictionary, p: Vector2i) -> int:
	var r := MapGen._river_beside(w, p)
	if r.x < 0:
		return 0
	var at: Vector2i = land["water"][r]
	var path: Array = land["paths"][at.x]
	var here: Vector2i = path[at.y]
	var before: Vector2i = here - path[maxi(at.y - MapGen.BEND, 0)]
	var after: Vector2i = path[mini(at.y + MapGen.BEND, path.size() - 1)] - here
	var turn := before.x * after.y - before.y * after.x
	if absi(turn) < MapGen.BEND_MIN:
		return 0
	var flow := before + after
	var d := p - here
	return 1 if (flow.x * d.y - flow.y * d.x) * turn > 0 else -1


func test_the_strange_stone_is_a_lone_high_point() -> void:
	var high := 0
	var above_hearth := 0
	var alone := 0
	for map_seed in range(1, SEEDS + 1):
		var w := _world(map_seed)
		var land := _land(map_seed)
		high += 1 if Terrain.height_of(land, w.shard_pos) > Terrain.height_at_percent(land, 50) else 0
		above_hearth += 1 if Terrain.height_of(land, w.shard_pos) > Terrain.height_of(land, w.camp_pos) else 0
		alone += 1 if w.touches(w.shard_pos, "grass") and not w.touches_river(w.shard_pos) else 0
	t.check(high >= SEEDS * 9 / 10, "the Strange Stone stands on high ground (%d of %d)" % [high, SEEDS])
	t.check(above_hearth == SEEDS, "always above the Hearth")
	t.check(alone == SEEDS, "and has open ground beside it")


## Rocks form ridges: a long unbroken run of rock on most maps, and it has a gap or is thin enough to cut a pass.
func test_the_ridge_has_a_gap() -> void:
	var long_ridge := 0
	for map_seed in range(1, SEEDS + 1):
		var w := _world(map_seed)
		var sizes := component_sizes(_positions(w, "rock"))
		sizes.sort()
		long_ridge += 1 if not sizes.is_empty() and sizes[-1] >= 20 else 0
		var thin := 0  # rock tiles with open ground on two opposite sides: a ridge no thicker than 2 in places
		for p in tiles_of(w, "rock"):
			var across_x: bool = w.tile_at(p + Vector2i(-1, 0)) != "rock" and w.tile_at(p + Vector2i(1, 0)) != "rock"
			var across_y: bool = w.tile_at(p + Vector2i(0, -1)) != "rock" and w.tile_at(p + Vector2i(0, 1)) != "rock"
			thin += 1 if across_x or across_y else 0
		t.check(
			thin >= 10, "seed %d: the ridge is thin in places, a pass is 3 Stone (%d thin tiles)" % [map_seed, thin]
		)
	t.check(long_ridge >= SEEDS * 8 / 10, "most maps have a long ridge of rock (%d of %d)" % [long_ridge, SEEDS])


func test_maps_differ() -> void:
	var ups := {}
	var starts := {}
	var lengths := {}
	var camps := {}
	var mouths := {}
	for map_seed in range(1, SEEDS + 1):
		var w := _world(map_seed)
		var land := _land(map_seed)
		var path: Array = land["paths"][0]
		ups[land["dir"]] = true
		starts[_side_of(w, path[0])] = true
		mouths[_side_of(w, path[path.size() - 1])] = true
		lengths[path.size()] = true
		camps[w.camp_pos] = true
	t.check(ups.size() >= 5, "the high side varies (%d of 8 directions)" % ups.size())
	t.check(starts.size() >= 3, "the river starts on different sides (%d)" % starts.size())
	t.check(mouths.size() >= 3, "and ends on different sides (%d)" % mouths.size())
	t.check(lengths.size() >= SEEDS / 2, "it takes different shapes (%d lengths)" % lengths.size())
	t.check(camps.size() >= SEEDS * 2 / 3, "the Hearth is in different places (%d)" % camps.size())
	var vertical := 0
	for map_seed in range(1, SEEDS + 1):
		var path: Array = _land(map_seed)["paths"][0]
		vertical += 1 if absi(path[0].x - path[path.size() - 1].x) < 5 else 0
	t.check(vertical < SEEDS * 2 / 3, "it isn't always a strip down the same side (%d run straight down)" % vertical)


## 0 for the west edge, 1 the east, 2 the north, 3 the south, 4 a corner tile counts as the side it is nearest.
static func _side_of(w: World, p: Vector2i) -> int:
	var to := [p.x, w.width - 1 - p.x, p.y, w.height - 1 - p.y]
	return to.find(to.min())


## Ruin a map, patch it, and it is fair again: the last resort of the generator.
func test_patching_makes_a_ruined_map_fair() -> void:
	var w := World.new()
	var report := {}
	MapGen.build(w, 3, report)
	var land: Dictionary = report["terrain"]
	for tile in ["rock", "gravel", "clay", "flax"]:
		for p in tiles_of(w, tile):
			w.set_tile(p, "grass")
	w.set_tile(w.shard_pos, "grass")
	w.shard_pos = Vector2i(-1, -1)
	t.check(not MapGen.faults_of(w, land).is_empty(), "the ruined map is not fair")
	MapGen.patch(w, land)
	var faults := MapGen.faults_of(w, land)
	t.check(faults.is_empty(), "and the patch makes it fair again (%s)" % [faults])


func test_tiny_maps_are_safe() -> void:
	var sizes := [
		Vector2i(1, 1),
		Vector2i(2, 2),
		Vector2i(3, 9),
		Vector2i(4, 4),
		Vector2i(6, 4),
		Vector2i(12, 8),
		Vector2i(23, 30),
		Vector2i(30, 15),
		Vector2i(30, 20),
		Vector2i(MapGen.MIN_WIDTH, MapGen.MIN_HEIGHT),
		Vector2i(MapGen.MIN_WIDTH - 1, MapGen.MIN_HEIGHT),
		Vector2i(48, 30),
	]
	for size in sizes:
		for map_seed in [1, 2, 3]:
			var a := World.new(size.x, size.y)
			var b := World.new(size.x, size.y)
			a.generate(map_seed)
			b.generate(map_seed)
			var what := "%dx%d seed %d" % [size.x, size.y, map_seed]
			t.check(a.tiles.size() == size.x * size.y, what + ": keeps its size")
			t.check(
				a.tiles == b.tiles and a.camp_pos == b.camp_pos and a.shard_pos == b.shard_pos, what + ": repeatable"
			)
			t.check(a.in_bounds(a.camp_pos), what + ": the Hearth is on the map")
			t.check(
				a.shard_pos == Vector2i(-1, -1) or a.tile_at(a.shard_pos) == "shard",
				what + ": the stone is where it says"
			)
			if size.x * size.y > 4:
				t.check(a.in_bounds(a.shard_pos), what + ": there is a stone")
			for tile in a.tiles:
				t.check(Data.TILES.has(tile), what + ": known tiles only")
				if not Data.TILES.has(tile):
					break
	var report := {}
	MapGen.build(World.new(12, 8), 1, report)
	t.check(report.has("small") and not report.has("terrain"), "a small map gets the plain layout")
	report = {}
	MapGen.build(World.new(48, 30), 1, report)
	t.check(report["faults"].is_empty() and not report.has("small"), "a bigger map gets terrain, and it is fair")
