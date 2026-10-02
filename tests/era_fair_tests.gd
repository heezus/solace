extends RefCounted
## Is the land that grows east fair on any map the game can draw? The real game makes its map from a random seed, and a
## player's roads are the only way to the ore. This checks, on many seeds (a sampled range here, 300 or more with
## tests/tools/east_scan.gd): a road can follow a way from the Hearth to both ores, over ground roads go on, crossing at
## most MapEast.MAX_CROSSINGS river tiles (a bridge each), no ore lies in the stone-age half, and the ore tiles
## themselves have open ground beside them (a Mine's road). And that the check itself sees a wall of water or a bank no road
## can cross. Run from tests/run_tests.gd, which owns check().

const EastFairness = preload("res://tests/east_fairness.gd")
const MapEast = preload("res://scripts/map_east.gd")
const World = preload("res://scripts/world.gd")

const FIRST := 41  # seeds 1 to 40 are the east tests' own; this range comes after them
const COUNT := 50
const BIG := [3405691904, 4022250974, 2863311530, 3735928559, 305419896, 2271560481, 1431655765, 4294967295]
const MAX_PASSES := 12  # rock tiles to cut a pass through on the way to an ore, at most (3 Stone each)

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_many_seeds_are_fair()
	test_the_check_sees_a_wall_of_water()
	test_the_check_sees_a_bank_no_road_can_cross()
	test_the_check_counts_rivers_passes_and_steps()


func test_many_seeds_are_fair() -> void:
	var seeds: Array = range(FIRST, FIRST + COUNT)
	seeds.append_array(BIG)  # 32-bit values, like the game's own randi()
	var worst := {"rivers": 0, "rocks": 0}
	for map_seed in seeds:
		var w := EastFairness.grown(map_seed)
		var r := EastFairness.report(w)
		var faults := EastFairness.faults(r, MapEast.MAX_CROSSINGS)
		t.check(faults.is_empty(), "seed %d: a road reaches the copper and the tin (%s)" % [map_seed, faults])
		for ore in ["copper", "tin"]:
			worst["rivers"] = maxi(worst["rivers"], mini(r[ore]["rivers"], 99))
			worst["rocks"] = maxi(worst["rocks"], mini(r[ore]["rocks"], 99))
			t.check(
				r[ore]["rocks"] <= MAX_PASSES,
				"seed %d: %d passes through rocks to the %s" % [map_seed, r[ore]["rocks"], ore]
			)
		var copper := 0
		var open := 0
		for y in w.height:
			for x in range(w.stone_width, w.width):
				var p := Vector2i(x, y)
				if w.tile_at(p) == "copper_hills":
					copper += 1
					open += 1 if _open_beside(w, p) else 0
		t.check(copper >= MapEast.COPPER_MIN, "seed %d: copper is common (%d tiles)" % [map_seed, copper])
		t.check(
			open >= MapEast.COPPER_NEAR_MIN,
			"seed %d: and %d of it has open ground beside it for a road" % [map_seed, open]
		)
	print(
		(
			"East fairness: %d seeds, worst %d bridges and %d passes through rocks"
			% [seeds.size(), worst["rivers"], worst["rocks"]]
		)
	)


## Some road ground (grass, forest, rock) or a road already beside p, so the ore can be reached.
func _open_beside(w: World, p: Vector2i) -> bool:
	for n in MapEast.NEIGHBORS:
		if w.tile_at(p + n) in ["grass", "tree", "rock"]:
			return true
	return false


## A World of open grass with a strip of `tile` across the whole stone-age map, `width` columns wide from column `at`.
func _walled(at: int, width: int, tile: String) -> World:
	var w := World.new()
	w.camp_pos = Vector2i(5, 10)
	for y in w.height:
		for x in range(at, at + width):
			w.set_tile(Vector2i(x, y), tile)
	return w


## A strip with copper and tin as the generator lays them, on open grass.
func _strip(w: World) -> Array:
	var strip: Array = []
	strip.resize(w.stone_width * w.height)
	strip.fill("grass")
	strip[3 * w.stone_width + 4] = "copper_hills"
	strip[3 * w.stone_width + 30] = "tin_stream"
	return strip


func test_the_check_sees_a_wall_of_water() -> void:
	var w := _walled(20, 5, "river")
	var ways := MapEast.road_ways(w, _strip(w))
	t.check(ways["copper"]["rivers"] == 5 and ways["tin"]["rivers"] == 5, "a river five tiles wide takes five bridges")
	t.check(ways["copper"]["rocks"] == 0 and ways["copper"]["steps"] > 30, "and a long road: %s" % [ways["copper"]])
	t.check(MapEast.faults_of(w, _strip(w)).any(func(f): return f.contains("bridges")), "so the strip is faulted")
	var narrow := _walled(20, 3, "river")
	t.check(MapEast.road_ways(narrow, _strip(narrow))["tin"]["rivers"] == 3, "three tiles is as wide as is fair")
	t.check(
		not MapEast.faults_of(narrow, _strip(narrow)).any(func(f): return f.contains("no road")),
		"and passes the road check"
	)


func test_the_check_sees_a_bank_no_road_can_cross() -> void:
	var w := _walled(20, 1, "river")
	for y in w.height:
		w.set_tile(Vector2i(19, y), "gravel")
		w.set_tile(Vector2i(21, y), "gravel")
	var ways := MapEast.road_ways(w, _strip(w))
	t.check(ways["copper"]["rivers"] >= MapEast.NONE, "a river with a bank of gravel the whole way has no road across")
	t.check(MapEast.faults_of(w, _strip(w)).any(func(f): return f.contains("no road")), "so the strip is faulted")
	w.set_tile(Vector2i(19, 4), "grass")
	w.set_tile(Vector2i(21, 4), "grass")
	var open := MapEast.road_ways(w, _strip(w))
	t.check(open["copper"]["rivers"] == 1, "one grass landing on each side gives a way: %s" % [open["copper"]])


func test_the_check_counts_rivers_passes_and_steps() -> void:
	var w := _walled(20, 2, "rock")
	var ways := MapEast.road_ways(w, _strip(w))
	t.check(ways["copper"]["rocks"] == 2 and ways["copper"]["rivers"] == 0, "a ridge two rocks thick is two passes")
	t.check(ways["tin"]["rocks"] == 2, "for the tin too")
	var open := _walled(0, 0, "grass")
	var free := MapEast.road_ways(open, _strip(open))
	t.check(free["copper"]["rocks"] == 0 and free["copper"]["rivers"] == 0, "open ground costs neither")
	t.check(free["copper"]["steps"] < ways["copper"]["steps"] + 1, "and no more steps than the ridge's way")
