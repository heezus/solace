extends RefCounted
## Unit testbench for the Pathing block (scripts/pathing.gd): what each tile costs to walk, which tiles
## are solid, and A* over the grid. Pathing is built alone, on a hand-made World and a hand-set set of
## researched techs; no Kith, no buildings and no Sim. The last tests check that the
## Sim builds the grid and that placing a road updates it. Run from tests/run_tests.gd, which owns check().

const Data = preload("res://scripts/data.gd")
const Kith = preload("res://scripts/kith.gd")
const Sim = preload("res://scripts/sim.gd")
const Pathing = preload("res://scripts/pathing.gd")
const World = preload("res://scripts/world.gd")

var t  # the runner, tests/run_tests.gd
var _techs: Dictionary = {}  # stands in for the researched techs


func run(runner) -> void:
	t = runner
	test_walk_cost_per_tile()
	test_roads_are_fast_and_each_tier_is_faster()
	test_a_bridge_costs_a_road_not_a_river()
	test_grid_weights_follow_walk_cost()
	test_rivers_are_solid_without_a_road_or_raft()
	test_a_road_opens_the_river()
	test_rafts_open_the_river_slowly()
	test_update_cell_after_a_road_is_placed()
	test_update_cell_follows_the_tiles()
	test_path_on_open_ground()
	test_path_goes_around_a_river()
	test_no_path_when_walled_off()
	test_a_bridge_opens_a_path()
	test_rafts_open_a_path()
	test_the_start_counts_as_open()
	test_path_prefers_roads_to_forest()
	test_pathing_does_not_write_the_world()
	test_sim_builds_the_walking_grid()
	test_placing_a_road_updates_the_grid()
	test_paving_a_road_refreshes_the_grid()
	test_kith_walk_around_water()


func _has_tech(id: String) -> bool:
	return _techs.has(id)


## A 7 by 5 map of grass with a river down column 3, except a gap of grass at (3, 4).
## A Pathing block is built on it and returned; the World is in `w`.
func _block(w: World, techs: Array = []) -> Pathing:
	_techs = {}
	for id in techs:
		_techs[id] = true
	var p := Pathing.new(w, _has_tech)
	p.build()
	return p


func _river_world(gap: bool = true) -> World:
	var w := World.new(7, 5)
	for y in 4 if gap else 5:
		w.set_tile(Vector2i(3, y), "river")
	return w


func test_walk_cost_per_tile() -> void:
	var w := World.new(7, 5)
	w.set_tile(Vector2i(1, 0), "tree")
	w.set_tile(Vector2i(2, 0), "rock")
	w.set_tile(Vector2i(3, 0), "river")
	w.set_tile(Vector2i(4, 0), "gravel")
	var p := _block(w)
	t.check(is_equal_approx(p.walk_cost(Vector2i(0, 0)), 1.0), "grass costs 1")
	t.check(is_equal_approx(p.walk_cost(Vector2i(1, 0)), Data.WALK_COST["tree"]), "forest is slow")
	t.check(is_equal_approx(p.walk_cost(Vector2i(2, 0)), Data.WALK_COST["rock"]), "so are rocks")
	t.check(is_equal_approx(p.walk_cost(Vector2i(3, 0)), Data.WALK_COST["river"]), "a river is slower still")
	t.check(is_equal_approx(p.walk_cost(Vector2i(4, 0)), 1.0), "gravel is like grass")
	t.check(is_equal_approx(p.walk_cost(Vector2i(-1, 0)), 1.0), "off the map is a plain 1")
	t.check(p.walk_cost(Vector2i(1, 0)) > 1.0 and p.walk_cost(Vector2i(3, 0)) > p.walk_cost(Vector2i(1, 0)), "in order")


func test_roads_are_fast_and_each_tier_is_faster() -> void:
	var w := World.new(7, 5)
	w.set_tile(Vector2i(1, 0), "tree")
	w.add_road(Vector2i(0, 0))
	w.add_road(Vector2i(1, 0))
	var p := _block(w)
	t.check(is_equal_approx(p.walk_cost(Vector2i(0, 0)), Data.WALK_COST["road"]), "a road is fast")
	t.check(p.walk_cost(Vector2i(0, 0)) < 1.0, "faster than open ground")
	t.check(is_equal_approx(p.walk_cost(Vector2i(1, 0)), Data.WALK_COST["road"]), "and a road over forest is a road")
	w.set_road_tier(Vector2i(0, 0), 1)
	t.check(is_equal_approx(p.walk_cost(Vector2i(0, 0)), Data.WALK_COST["road"] / 1.25), "gravel is 25% faster")
	w.set_road_tier(Vector2i(0, 0), 2)
	t.check(is_equal_approx(p.walk_cost(Vector2i(0, 0)), Data.WALK_COST["road"] / 1.5), "paved is 50% faster")
	t.check(is_equal_approx(p.walk_cost(Vector2i(1, 0)), Data.WALK_COST["road"]), "the next tile keeps its own tier")
	t.check(is_equal_approx(p.walk_cost(Vector2i(2, 0)), 1.0), "and the tier does nothing off the road")
	w.set_road_tier(Vector2i(0, 0), 0)
	t.check(is_equal_approx(p.walk_cost(Vector2i(0, 0)), Data.WALK_COST["road"]), "tier 0 is the plain path again")


func test_a_bridge_costs_a_road_not_a_river() -> void:
	var w := _river_world()
	w.add_road(Vector2i(3, 1))
	var p := _block(w)
	t.check(is_equal_approx(p.walk_cost(Vector2i(3, 1)), Data.WALK_COST["road"]), "a bridge is road speed")
	t.check(p.walk_cost(Vector2i(3, 1)) < p.walk_cost(Vector2i(3, 2)), "well under the open river beside it")


func test_grid_weights_follow_walk_cost() -> void:
	var w := _river_world()
	w.set_tile(Vector2i(1, 1), "tree")
	w.add_road(Vector2i(5, 2))
	var p := _block(w)
	t.check(p.astar.region == Rect2i(0, 0, 7, 5), "the grid is as big as the map")
	t.check(p.astar.diagonal_mode == AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES, "diagonals only in the open")
	for y in 5:
		for x in 7:
			var at := Vector2i(x, y)
			t.check(is_equal_approx(p.astar.get_point_weight_scale(at), p.walk_cost(at)), "weight at %s" % at)


func test_rivers_are_solid_without_a_road_or_raft() -> void:
	var p := _block(_river_world())
	t.check(
		p.astar.is_point_solid(Vector2i(3, 0)) and p.astar.is_point_solid(Vector2i(3, 3)), "the river blocks walking"
	)
	t.check(not p.astar.is_point_solid(Vector2i(3, 4)), "the gap does not")
	t.check(
		not p.astar.is_point_solid(Vector2i(2, 2)) and not p.astar.is_point_solid(Vector2i(4, 2)), "nor do the banks"
	)


func test_a_road_opens_the_river() -> void:
	var w := _river_world()
	w.add_road(Vector2i(3, 2))
	var p := _block(w)
	t.check(not p.astar.is_point_solid(Vector2i(3, 2)), "a bridged tile is walkable")
	t.check(p.astar.is_point_solid(Vector2i(3, 1)), "the tile beside it is still water")


func test_rafts_open_the_river_slowly() -> void:
	var w := _river_world()
	var p := _block(w, ["rafts"])
	for y in 4:
		t.check(not p.astar.is_point_solid(Vector2i(3, y)), "with Rafts the river at y=%d is walkable" % y)
	t.check(is_equal_approx(p.astar.get_point_weight_scale(Vector2i(3, 1)), Data.WALK_COST["river"]), "but slow")
	t.check(p.walk_cost(Vector2i(3, 1)) > 1.0, "slower than open ground")


func test_update_cell_after_a_road_is_placed() -> void:
	var w := _river_world()
	var p := _block(w)
	var at := Vector2i(3, 1)
	t.check(p.astar.is_point_solid(at), "water first")
	t.check(is_equal_approx(p.astar.get_point_weight_scale(at), Data.WALK_COST["river"]), "at river cost")
	w.add_road(at)
	t.check(p.astar.is_point_solid(at), "the grid has not looked yet")
	p.update_cell(at)
	t.check(not p.astar.is_point_solid(at), "after update_cell the bridge is walkable")
	t.check(is_equal_approx(p.astar.get_point_weight_scale(at), Data.WALK_COST["road"]), "at road cost")
	t.check(p.astar.is_point_solid(Vector2i(3, 2)), "and only that cell changed")
	w.remove_road(at)
	p.update_cell(at)
	t.check(p.astar.is_point_solid(at), "tearing the bridge up makes it water again")
	t.check(is_equal_approx(p.astar.get_point_weight_scale(at), Data.WALK_COST["river"]), "at river cost")
	var grass := Vector2i(1, 1)
	w.add_road(grass)
	p.update_cell(grass)
	t.check(not p.astar.is_point_solid(grass), "a road on grass stays walkable")
	t.check(is_equal_approx(p.astar.get_point_weight_scale(grass), Data.WALK_COST["road"]), "and gets faster")


func test_update_cell_follows_the_tiles() -> void:
	var w := World.new(7, 5)
	w.set_tile(Vector2i(2, 2), "tree")
	var p := _block(w)
	t.check(is_equal_approx(p.astar.get_point_weight_scale(Vector2i(2, 2)), Data.WALK_COST["tree"]), "forest")
	w.set_tile(Vector2i(2, 2), "grass")  # the trees are felled
	p.update_cell(Vector2i(2, 2))
	t.check(is_equal_approx(p.astar.get_point_weight_scale(Vector2i(2, 2)), 1.0), "felled: open ground")
	p.refresh()
	t.check(is_equal_approx(p.astar.get_point_weight_scale(Vector2i(2, 2)), 1.0), "refresh keeps it so")
	w.set_tile(Vector2i(4, 4), "river")
	p.refresh()
	t.check(p.astar.is_point_solid(Vector2i(4, 4)), "refresh reads every cell")


func test_path_on_open_ground() -> void:
	var p := _block(World.new(7, 5))
	var path := p.path(Vector2i(0, 0), Vector2i(4, 0))
	t.check(path.size() == 5, "a straight walk of four steps has five tiles, both ends in (got %d)" % path.size())
	t.check(path[0] == Vector2i(0, 0) and path[path.size() - 1] == Vector2i(4, 0), "from the start to the goal")
	var diag := p.path(Vector2i(0, 0), Vector2i(3, 3))
	t.check(diag.size() == 4, "open ground allows diagonals (got %d tiles)" % diag.size())
	t.check(p.path(Vector2i(2, 2), Vector2i(2, 2)) == [Vector2i(2, 2)], "walking to where you stand is just that tile")


func test_path_goes_around_a_river() -> void:
	var p := _block(_river_world())
	var path := p.path(Vector2i(1, 0), Vector2i(5, 0))
	t.check(not path.is_empty(), "there is a way round through the gap")
	t.check(path.has(Vector2i(3, 4)), "and it goes through the gap")
	for step in path:
		t.check(not p.astar.is_point_solid(step), "no step in the water: %s" % step)
	t.check(path[path.size() - 1] == Vector2i(5, 0), "and it arrives")


func test_no_path_when_walled_off() -> void:
	var p := _block(_river_world(false))
	t.check(p.path(Vector2i(1, 0), Vector2i(5, 0)).is_empty(), "no way across an unbroken river")
	t.check(p.path(Vector2i(1, 0), Vector2i(3, 2)).is_empty(), "no way onto a river tile either")
	t.check(not p.path(Vector2i(1, 0), Vector2i(2, 4)).is_empty(), "the near bank is still reachable")


func test_a_bridge_opens_a_path() -> void:
	var w := _river_world(false)
	var p := _block(w)
	t.check(p.path(Vector2i(2, 2), Vector2i(4, 2)).is_empty(), "walled off at first")
	w.add_road(Vector2i(3, 2))
	p.update_cell(Vector2i(3, 2))
	var path := p.path(Vector2i(2, 2), Vector2i(4, 2))
	t.check(path == [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)], "one bridge tile, and the path crosses it")


func test_rafts_open_a_path() -> void:
	var p := _block(_river_world(false))
	t.check(p.path(Vector2i(2, 2), Vector2i(4, 2)).is_empty(), "walled off at first")
	_techs["rafts"] = true
	p.refresh()
	t.check(not p.path(Vector2i(2, 2), Vector2i(4, 2)).is_empty(), "Rafts and a refresh open the river")


func test_the_start_counts_as_open() -> void:
	var w := _river_world(false)
	var p := _block(w)
	var water := Vector2i(3, 2)
	var path := p.path(water, Vector2i(2, 2))
	t.check(path == [water, Vector2i(2, 2)], "someone on a blocked tile can step off it")
	t.check(p.astar.is_point_solid(water), "and the tile is blocked again afterwards")
	var open := Vector2i(1, 1)
	p.path(open, Vector2i(0, 0))
	t.check(not p.astar.is_point_solid(open), "an open start stays open")


func test_path_prefers_roads_to_forest() -> void:
	var w := World.new(7, 3)
	for x in range(2, 5):
		w.set_tile(Vector2i(x, 1), "tree")
	for x in range(1, 6):
		w.add_road(Vector2i(x, 0))
	var p := _block(w)
	var path := p.path(Vector2i(0, 1), Vector2i(6, 1))
	t.check(path.has(Vector2i(3, 0)), "the walk takes the road")
	t.check(not path.has(Vector2i(3, 1)), "and not the forest")
	t.check(path[0] == Vector2i(0, 1) and path[path.size() - 1] == Vector2i(6, 1), "between the same two ends")
	for x in range(1, 6):
		w.set_road_tier(Vector2i(x, 0), 2)
	p.refresh()
	t.check(p.path(Vector2i(0, 1), Vector2i(6, 1)).has(Vector2i(3, 0)), "paved, still the road")


func test_pathing_does_not_write_the_world() -> void:
	var w := _river_world()
	w.add_road(Vector2i(3, 1))
	var tiles := w.tiles.duplicate()
	var roads := w.roads.duplicate()
	var p := _block(w, ["rafts", "paved_roads"])
	p.path(Vector2i(0, 0), Vector2i(6, 4))
	p.refresh()
	p.update_cell(Vector2i(2, 2))
	t.check(w.tiles == tiles and w.roads == roads, "tiles and roads are as they were")
	t.check(w.fields.is_empty(), "no fields appeared")
	t.check(not ("tiles" in p) and not ("roads" in p) and not ("researched" in p), "it keeps none of that itself")


func test_sim_builds_the_walking_grid() -> void:
	var s := Sim.new()
	s.generate(42)
	var river: Vector2i = t.find_tile(s, "river")
	t.check(s.pathing.astar.is_point_solid(river), "the river blocks walking")
	t.check(s.pathing.astar.region == Rect2i(0, 0, World.WIDTH, World.HEIGHT), "the grid is the map's size")
	s.tech_tree.researched["rafts"] = true
	s.pathing.refresh()
	t.check(not s.pathing.astar.is_point_solid(river), "Pathing reads the researched techs")
	t.check(s._has_tech("rafts") and not s._has_tech("paved_roads"), "through a read-only view")


func test_placing_a_road_updates_the_grid() -> void:
	var s: Sim = t.fresh()
	var river: Vector2i = t.find_tile(s, "river")
	s.tech_tree.researched["haulers"] = true
	t.check(s.pathing.astar.is_point_solid(river), "water before the bridge")
	t.check(t.place_free(s, "bridge", river), "a bridge goes on the river")
	t.check(not s.pathing.astar.is_point_solid(river), "placing it updates the walking grid")
	t.check(is_equal_approx(s.pathing.astar.get_point_weight_scale(river), Data.WALK_COST["road"]), "to road speed")
	t.check(s.world.roads.has(river) and s.world.roads.has(river), "and the road is in the World")
	s.demolish(river)
	t.check(s.pathing.astar.is_point_solid(river), "demolishing it makes it water again")
	var grass: Vector2i = s.world.camp_pos + Vector2i(0, 2)
	t.check(t.place_free(s, "road", grass), "a road on grass")
	t.check(is_equal_approx(s.pathing.walk_cost(grass), Data.WALK_COST["road"]), "is fast")
	s.demolish(grass)
	t.check(is_equal_approx(s.pathing.walk_cost(grass), 1.0), "and gone again")
	t.check(t.place_free(s, "field", grass), "a field goes on grass")
	t.check(s.world.fields.has(grass) and s.world.tile_at(grass) == "grain", "it is sown")
	s.demolish(grass)
	t.check(s.world.tile_at(grass) == "grass" and not s.world.fields.has(grass), "and clearing it restores the grass")


func test_paving_a_road_refreshes_the_grid() -> void:
	var s: Sim = t.fresh()
	s.tech_tree.researched["haulers"] = true
	var p: Vector2i = s.world.camp_pos + Vector2i(0, 2)
	t.check(t.place_free(s, "road", p), "a road on grass")
	var slow := s.pathing.astar.get_point_weight_scale(p)
	s.tech_tree.researched["paved_roads"] = true
	s.economy.add("brick", 5)
	t.check(s.place("paved_road", p), "a Paved Road laid over it")
	t.check(s.pathing.astar.get_point_weight_scale(p) < slow, "paving it makes the walking cell faster at once")


func test_kith_walk_around_water() -> void:
	var s: Sim = t.fresh()
	var k: Dictionary = s.people.kith[0]
	var river: Vector2i = t.find_tile(s, "river")
	t.check(not s.people.walk_to(k, river), "a Kith can't walk into the river")
	var bank := river + Vector2i(-1, 0)
	t.check(s.people.walk_to(k, bank), "but can walk to its bank")
	t.check(not k["path"].is_empty() and k["path"][k["path"].size() - 1] == bank, "along a path that ends there")
	t.check(not k["path"].has(Kith.tile_of(k)), "which doesn't list the tile they stand on")
	var trip: Dictionary = s.people.trip_info(bank)
	t.check(trip["ok"] and trip["tiles"] > 0 and trip["seconds"] > 0.0, "trip_info walks the same grid")
