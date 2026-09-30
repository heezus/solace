extends RefCounted
## Unit testbench for the World block (scripts/world.gd): bounds, tile lookups, neighbours and the river,
## which tiles a gatherer can work, map generation from a seed, and the roads and fields bookkeeping.
## World is built alone, on a tiny hand-made map; no Kith, no Fog and no Sim. The last tests check
## that the Sim's World and Buildings blocks agree. Run from tests/run_tests.gd, which owns check().

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const World = preload("res://scripts/world.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_a_new_world_is_open_grass()
	test_bounds_and_tile_at()
	test_set_tile()
	test_touches_is_side_by_side()
	test_touches_river()
	test_gather_tiles()
	test_gather_tiles_radius()
	test_generate_is_deterministic()
	test_generate_differs_by_seed()
	test_generated_map_has_a_camp_and_a_shard()
	test_generate_keeps_the_size()
	test_roads_bookkeeping()
	test_fields_bookkeeping()
	test_world_stands_alone()
	test_to_dict_and_from_dict()
	test_sim_world_and_town_agree()
	test_sim_generate_sets_the_camp_up()


## A 6 by 4 map: grass, a river down column 4, a tree at (1, 1), rocks at (2, 1) and (1, 2), and a
## berry patch at (0, 0), so a test can point at exact tiles.
func _tiny() -> World:
	var w := World.new(6, 4)
	for y in 4:
		w.set_tile(Vector2i(4, y), "river")
	w.set_tile(Vector2i(1, 1), "tree")
	w.set_tile(Vector2i(2, 1), "rock")
	w.set_tile(Vector2i(1, 2), "rock")
	w.set_tile(Vector2i(0, 0), "berry")
	return w


func test_a_new_world_is_open_grass() -> void:
	var w := World.new(6, 4)
	t.check(w.width == 6 and w.height == 4, "the map is the size it was made")
	t.check(w.tiles.size() == 24, "one tile per cell")
	t.check(w.tiles.count("grass") == 24, "all of it open grass")
	t.check(w.roads.is_empty() and w.fields.is_empty(), "no roads or fields yet")
	t.check(w.camp_pos == Vector2i.ZERO and w.shard_pos == Vector2i(-1, -1), "no camp or shard placed yet")
	var big := World.new()
	t.check(big.width == World.WIDTH and big.height == World.HEIGHT, "the game's size by default")
	t.check(big.tiles.size() == World.WIDTH * World.HEIGHT, "with a tile for every cell")


func test_bounds_and_tile_at() -> void:
	var w := _tiny()
	t.check(w.in_bounds(Vector2i(0, 0)) and w.in_bounds(Vector2i(5, 3)), "both corners are on the map")
	t.check(not w.in_bounds(Vector2i(-1, 0)) and not w.in_bounds(Vector2i(0, -1)), "nothing left of or above it")
	t.check(not w.in_bounds(Vector2i(6, 0)) and not w.in_bounds(Vector2i(0, 4)), "nothing right of or below it")
	t.check(w.tile_at(Vector2i(0, 0)) == "berry", "tile_at reads a tile")
	t.check(w.tile_at(Vector2i(4, 2)) == "river", "the river column")
	t.check(w.tile_at(Vector2i(5, 3)) == "grass", "the far corner is grass")
	t.check(w.tile_at(Vector2i(-1, 0)) == "", "off the map is the empty tile")
	t.check(w.tile_at(Vector2i(6, 3)) == "" and w.tile_at(Vector2i(2, 4)) == "", "on every side")
	t.check(w.tile_at(Vector2i(1, 1)) == "tree", "index is y times width plus x")


func test_set_tile() -> void:
	var w := _tiny()
	w.set_tile(Vector2i(3, 3), "clay")
	t.check(w.tile_at(Vector2i(3, 3)) == "clay", "set_tile changes a tile")
	t.check(w.tiles[3 * 6 + 3] == "clay", "in the flat array")
	w.set_tile(Vector2i(6, 0), "clay")
	w.set_tile(Vector2i(-1, -1), "clay")
	t.check(w.tiles.size() == 24 and w.tiles.count("clay") == 1, "off the map it changes nothing")
	w.reset("river")
	t.check(w.tiles.count("river") == 24, "reset remakes the whole map")


func test_touches_is_side_by_side() -> void:
	var w := _tiny()
	t.check(w.touches(Vector2i(1, 0), "tree"), "a tree below")
	t.check(w.touches(Vector2i(0, 1), "tree"), "a tree to the right")
	t.check(w.touches(Vector2i(2, 2), "rock"), "rocks to the left and above")
	t.check(not w.touches(Vector2i(0, 0), "tree"), "a tree only diagonally away doesn't count")
	t.check(not w.touches(Vector2i(1, 1), "tree"), "a tile doesn't touch itself")
	t.check(w.touches(Vector2i(0, 1), "berry"), "the berries above (0, 1)")
	t.check(not w.touches(Vector2i(5, 0), "shard"), "no shard on this map")


func test_touches_river() -> void:
	var w := _tiny()
	t.check(w.touches_river(Vector2i(3, 2)), "the west bank touches the river")
	t.check(w.touches_river(Vector2i(5, 0)), "the east bank does too")
	t.check(not w.touches_river(Vector2i(2, 2)), "two tiles away doesn't")
	t.check(w.touches_river(Vector2i(4, 0)), "a river tile touches the river beside it")
	t.check(w.touches_river(Vector2i(5, 3)), "at the map edge")
	t.check(not w.touches_river(Vector2i(0, 3)), "the far bank of grass")


func test_gather_tiles() -> void:
	var w := _tiny()
	var found := w.gather_tiles(Vector2i(2, 2), 1)
	t.check(found.size() == 3, "a hut at (2, 2) can reach three resource tiles (got %d)" % found.size())
	t.check(found.has(Vector2i(2, 1)) and found.has(Vector2i(1, 2)), "the two rocks")
	t.check(found.has(Vector2i(1, 1)), "and, the radius being a square, the tree on the diagonal")
	t.check(not found.has(Vector2i(3, 2)), "grass yields nothing, so it isn't listed")
	var wet := w.gather_tiles(Vector2i(3, 2), 1)
	t.check(not wet.has(Vector2i(4, 2)), "the river yields nothing either")
	t.check(w.gather_tiles(Vector2i(5, 0), 0).is_empty(), "radius 0 looks at the tile itself: grass")
	w.set_tile(Vector2i(5, 3), "shard")
	t.check(w.gather_tiles(Vector2i(5, 3), 1).is_empty(), "the Strange Stone yields nothing")


func test_gather_tiles_radius() -> void:
	var w := _tiny()
	var near := w.gather_tiles(Vector2i(2, 2), 1)
	var far := w.gather_tiles(Vector2i(2, 2), 2)
	t.check(far.size() == near.size() + 1, "a bigger radius reaches more (the berries at (0, 0))")
	t.check(far.has(Vector2i(0, 0)), "the berry patch is 2 away")
	t.check(not near.has(Vector2i(0, 0)), "and 2 away is out of range for radius 1")
	var corner := w.gather_tiles(Vector2i(0, 0), 2)
	t.check(corner.size() == 4, "a hut in the corner counts only what is on the map (got %d)" % corner.size())
	for p in far:
		t.check(w.in_bounds(p), "every tile it lists is on the map")


func _same_map(a: World, b: World) -> bool:
	return a.tiles == b.tiles and a.camp_pos == b.camp_pos and a.shard_pos == b.shard_pos


func test_generate_is_deterministic() -> void:
	for map_seed in [1, 2, 3, 42, 12345]:
		var a := World.new()
		var b := World.new()
		a.generate(map_seed)
		b.generate(map_seed)
		t.check(_same_map(a, b), "seed %d makes the same map twice" % map_seed)
	var again := World.new()
	again.generate(42)
	again.generate(42)
	var once := World.new()
	once.generate(42)
	t.check(_same_map(again, once), "generating over an old map gives the same result")


func test_generate_differs_by_seed() -> void:
	var a := World.new()
	var b := World.new()
	a.generate(1)
	b.generate(2)
	t.check(a.tiles != b.tiles, "different seeds make different maps")


func test_generated_map_has_a_camp_and_a_shard() -> void:
	for map_seed in [1, 2, 3, 7, 42]:
		var w := World.new()
		w.generate(map_seed)
		# The Hearth's spot comes from the terrain (dry lowland by the river), so it differs by seed.
		t.check(
			w.camp_pos.x >= 5 and w.camp_pos.y >= 5 and w.in_bounds(w.camp_pos + Vector2i(5, 5)),
			"seed %d: camp spot" % map_seed
		)
		t.check(w.tile_at(w.camp_pos) == "grass", "seed %d: the camp stands on grass" % map_seed)
		t.check(w.tile_at(w.shard_pos) == "shard", "seed %d: the shard is on the map" % map_seed)
		t.check(w.tiles.count("shard") == 1, "seed %d: only one" % map_seed)
		t.check(Vector2(w.shard_pos).distance_to(Vector2(w.camp_pos)) > 10.0, "seed %d: far from the camp" % map_seed)
		t.check(w.tiles.has("river"), "seed %d: a river" % map_seed)
		for tile in ["tree", "rock", "berry", "grain", "flax", "gravel"]:
			t.check(w.tiles.has(tile), "seed %d: has %s" % [map_seed, tile])
		for tile in w.tiles:
			t.check(Data.TILES.has(tile), "seed %d: every tile is a known one" % map_seed)


func test_generate_keeps_the_size() -> void:
	var w := World.new(30, 20)
	w.generate(5)
	t.check(w.tiles.size() == 600, "a 30 by 20 world stays 30 by 20")
	t.check(w.in_bounds(w.camp_pos) and w.in_bounds(w.shard_pos), "camp and shard are on it")
	var again := World.new(30, 20)
	again.generate(5)
	t.check(_same_map(w, again), "and is just as repeatable")


func test_roads_bookkeeping() -> void:
	var w := _tiny()
	var p := Vector2i(2, 2)
	w.add_road(p)
	t.check(w.roads.has(p) and w.roads.size() == 1, "a road is recorded")
	t.check(w.tile_at(p) == "grass", "the tile under it is left alone")
	w.add_road(p)
	t.check(w.roads.size() == 1, "a road laid twice is one road")
	w.add_road(Vector2i(4, 2))  # a bridge: a road on a river tile
	t.check(w.roads.has(Vector2i(4, 2)) and w.tile_at(Vector2i(4, 2)) == "river", "a bridge keeps the river tile")
	w.remove_road(p)
	t.check(not w.roads.has(p) and w.roads.size() == 1, "removing one road leaves the other")
	w.remove_road(p)
	t.check(w.roads.size() == 1, "removing a road that isn't there does nothing")


func test_fields_bookkeeping() -> void:
	var w := _tiny()
	var p := Vector2i(3, 3)
	w.add_field(p)
	t.check(w.fields.has(p), "a field is recorded")
	t.check(w.tile_at(p) == "grain", "and the tile becomes grain")
	t.check(not w.roads.has(p), "a field is not a road")
	w.remove_field(p)
	t.check(not w.fields.has(p), "clearing it forgets it")
	t.check(w.tile_at(p) == "grass", "and the tile is grass again")
	w.remove_field(p)
	t.check(w.fields.is_empty() and w.tile_at(p) == "grass", "clearing a field twice does nothing")


## The tiles, the camp and shard, and the roads and fields (in the order laid) survive a dict and a JSON
## round trip, into a world of any size.
func test_to_dict_and_from_dict() -> void:
	var a := _tiny()
	a.camp_pos = Vector2i(2, 3)
	a.shard_pos = Vector2i(3, 0)
	a.add_road(Vector2i(2, 2))
	a.add_road(Vector2i(4, 2))
	a.add_road(Vector2i(0, 3))
	a.add_field(Vector2i(3, 3))
	a.add_field(Vector2i(0, 1))
	var d := a.to_dict()
	var b := World.new()  # the game's size: the dict brings its own
	b.from_dict(d)
	t.check(RunSave.to_json(b.to_dict()) == RunSave.to_json(d), "a World restored from a dict writes the same dict")
	t.check(b.width == 6 and b.height == 4 and b.tiles == a.tiles, "the size and the tiles")
	t.check(b.camp_pos == a.camp_pos and b.shard_pos == a.shard_pos, "the camp and the shard")
	t.check(
		b.roads.keys() == a.roads.keys() and b.fields.keys() == a.fields.keys(), "roads and fields, in the same order"
	)
	var c := World.new(2, 2)
	c.from_dict(RunSave.from_json(RunSave.to_json(d)))
	t.check(RunSave.to_json(c.to_dict()) == RunSave.to_json(d), "the same after a trip through JSON text")
	t.check(
		c.tile_at(Vector2i(5, 3)) == "grass" and c.tile_at(Vector2i(4, 1)) == "river",
		"and it answers like the original"
	)
	c.from_dict({"width": 3, "height": 3, "tiles": ["grass"]})
	t.check(
		c.tiles.size() == 9 and c.tiles.count("grass") == 9 and c.roads.is_empty(),
		"a tile list that doesn't fit leaves open grass"
	)


func test_world_stands_alone() -> void:
	var w := World.new(4, 4)
	t.check(not ("fog" in w), "the fog is its own block: World holds none of it")
	t.check(not ("buildings" in w) and not ("kith" in w) and not ("inv" in w), "no buildings, Kith or stockpile")
	t.check(not ("astar" in w), "and no walking grid: that is Pathing's")


func test_sim_world_and_town_agree() -> void:
	var s := Sim.new()
	s.world.set_tile(Vector2i(3, 3), "clay")
	s.world.add_road(Vector2i(2, 2))
	s.world.add_field(Vector2i(3, 3))
	t.check(
		s.town.built_type(Vector2i(2, 2)) == "road" and s.town.built_type(Vector2i(3, 3)) == "field",
		"roads and fields count as built"
	)
	s.world.set_tile(Vector2i(10, 10), "tree")
	s.world.set_tile(Vector2i(11, 11), "rock")
	t.check(s.town.gather_tiles(Vector2i(10, 11)).size() == 2, "gather_tiles works the hut's radius")
	s.tech_tree.researched["scouting"] = true
	s.world.set_tile(Vector2i(13, 11), "rock")
	t.check(s.town.gather_tiles(Vector2i(10, 11)).size() == 3, "and Scouting widens it")


func test_sim_generate_sets_the_camp_up() -> void:
	var s := Sim.new()
	s.generate(42)
	var w := World.new()
	w.generate(42)
	t.check(s.world.tiles == w.tiles, "Sim.generate makes the World's map")
	t.check(s.world.camp_pos == w.camp_pos and s.world.shard_pos == w.shard_pos, "with the same camp and shard")
	t.check(s.town.building_at.has(s.world.camp_pos) and s.town.buildings.size() == 1, "the Hearth is placed")
	t.check(s.people.kith.size() == Data.KITH_START, "the first Kith are born")
	t.check(s.fog.is_revealed(s.world.camp_pos), "the camp is in view")
