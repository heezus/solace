extends RefCounted
## Tests for the genre conventions from Jon's playtests: demolish, pause, the Hearth, bridges,
## fog and rates. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")
const Rules = preload("res://scripts/rules.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_demolish_refunds_half()
	test_pause_frees_the_worker()
	test_dwellings_stay_near_the_hearth()
	test_roads_dont_cross_rivers()
	test_fog_lifts_around_buildings_and_kith()
	test_rates_count_making_and_using()


func test_demolish_refunds_half() -> void:
	var s: GameState = t.fresh()
	s.inv["berries"] = 100
	var near := s.camp_pos + Vector2i(-2, 0)
	var other := s.camp_pos + Vector2i(-2, 1)
	t.place_free(s, "gatherers_hut", near)
	t.place_free(s, "gatherers_hut", other)
	for i in 10:
		s.tick(0.5)
	var first: Dictionary = s.buildings[s.building_at[near]]
	t.check(first["worker"] >= 0, "the hut has a worker")
	var worker: int = first["worker"]
	var wood: int = s.inv["wood"]
	var stone: int = s.inv["stone"]
	var refund := s.demolish(near)
	t.check(
		refund.size() == 2 and refund.get("wood") == 5 and refund.get("stone") == 2,
		"half back, rounded down (%s)" % str(refund)
	)
	t.check(s.inv["wood"] >= wood + 5 and s.inv["stone"] >= stone + 2, "the refund reaches the stockpile")
	t.check(not s.building_at.has(near), "the hut is gone")
	t.check(s.kith[worker]["job"] != "work", "its worker goes idle")
	t.check(s.buildings[s.building_at[other]]["pos"] == other, "the other buildings keep their places")
	var k2: int = s.buildings[s.building_at[other]]["worker"]
	t.check(k2 < 0 or s.kith[k2]["building"] == s.building_at[other], "the other worker still points at its hut")
	t.check(s.demolish(s.camp_pos).is_empty(), "the Hearth can't be torn down")
	var road := s.camp_pos + Vector2i(1, 1)
	t.place_free(s, "road", road)
	s.demolish(road)
	t.check(not s.roads.has(road), "roads can be torn up")
	for i in 20:
		s.tick(0.5)
	t.check(true, "the simulation keeps running after a demolish")


func test_pause_frees_the_worker() -> void:
	var s: GameState = t.fresh()
	s.inv["berries"] = 100
	var p := s.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", p)
	s.tick(0.1)
	var i: int = s.building_at[p]
	t.check(s.buildings[i]["worker"] >= 0, "staffed")
	s.set_paused(i, true)
	s.tick(0.1)
	t.check(s.buildings[i]["worker"] < 0, "a paused building frees its worker")
	t.check(s.buildings[i]["alert"] == "Paused", "and says so")
	s.set_paused(i, false)
	s.tick(0.1)
	t.check(s.buildings[i]["worker"] >= 0, "resumed, it gets a worker back")


func test_dwellings_stay_near_the_hearth() -> void:
	var s: GameState = t.fresh()
	var near := s.camp_pos + Vector2i(0, 2)
	var far := Vector2i(-1, -1)
	for y in GameState.HEIGHT:
		for x in GameState.WIDTH:
			var p := Vector2i(x, y)
			if (
				far.x < 0
				and s.tile_at(p) == "grass"
				and Vector2(p).distance_to(Vector2(s.camp_pos)) > Data.HEARTH_RADIUS
			):
				far = p
	s.inv["wood"] = 100
	s.inv["fiber"] = 100
	t.check(Data.BUILDINGS["camp"]["name"] == "Hearth", "the Camp is the Hearth")
	t.check(
		s.placement_error("dwelling", far) == "Must be within 6 tiles of the Hearth", "no Dwelling far from the Hearth"
	)
	t.check(s.place("dwelling", near), "a Dwelling near the Hearth")
	t.check(
		s.placement_error("storehouse", far) != "Must be within 6 tiles of the Hearth", "other buildings go anywhere"
	)


func test_roads_dont_cross_rivers() -> void:
	var s: GameState = t.fresh()
	var river: Vector2i = t.find_tile(s, "river")
	s.researched["haulers"] = true
	s.inv["stone"] = 10
	t.check(s.placement_error("road", river).begins_with("Roads can't cross the river"), "no roads on the river")
	t.check(not s.place("road", river), "a road won't go down on the river")
	t.check(s.astar.is_point_solid(river), "the river still blocks walking")
	var line := Rules.line_tiles(Vector2i(2, 3), Vector2i(5, 1))
	t.check(line.size() == 6 and line[0] == Vector2i(2, 3) and line[5] == Vector2i(5, 1), "a drag covers an L of tiles")


func test_fog_lifts_around_buildings_and_kith() -> void:
	var s := GameState.new()
	s.generate(42)
	t.check(s.fog.is_revealed(s.camp_pos), "the Hearth is in view")
	t.check(s.fog.is_revealed(s.camp_pos + Vector2i(Data.SIGHT_START, 0)), "6 tiles around it too")
	var far := s.camp_pos + Vector2i(Data.SIGHT_START + 3, 0)
	t.check(not s.fog.is_revealed(far), "farther out is fog")
	t.check(s.gather_by_hand(far) == "", "can't gather in the fog")
	s.inv["wood"] = 100
	s.inv["stone"] = 100
	s.researched["gatherers_hut"] = true
	t.check(s.placement_error("gatherers_hut", far).begins_with("Unexplored"), "can't build in the fog")
	var edge := s.camp_pos + Vector2i(Data.SIGHT_START, 0)
	if s.tile_at(edge) == "grass":
		s.place("gatherers_hut", edge)
		t.check(s.fog.is_revealed(edge + Vector2i(Data.SIGHT_BUILDING, 0)), "a building lifts the fog 3 tiles out")
	var before := s.fog.count()
	s.kith[0]["pos"] = Vector2(s.camp_pos + Vector2i(-Data.SIGHT_START - 1, 0))
	s.inv["berries"] = 50
	s.tick(0.1)
	t.check(s.fog.count() > before, "walking Kith lift the fog around them")
	check(sight_after_a_walk(true) > sight_after_a_walk(false), "Scouting lets the Kith see farther")


## How many tiles are explored after one Kith steps just past the fog's edge.
func sight_after_a_walk(scouting: bool) -> int:
	var s := GameState.new()
	s.generate(42)
	if scouting:
		s.researched["scouting"] = true
	s.kith[0]["pos"] = Vector2(s.camp_pos + Vector2i(-Data.SIGHT_START - 1, 0))
	s.inv["berries"] = 50
	s.tick(0.1)
	return s.fog.count()


func test_rates_count_making_and_using() -> void:
	var s: GameState = t.fresh()
	t.check(s.flows.rate("wood") == 0.0, "no rate before anything happens")
	s.flows.add("wood", 6, "gatherers_hut")
	s.flows.add("wood", -2, "charcoal_pit")
	s.flows.advance(1.0)
	t.check(is_equal_approx(s.flows.rate("wood"), 4.0), "net rate: made minus used, per second")
	var parts := s.flows.parts("wood")
	t.check(is_equal_approx(parts["gatherers_hut"], 6.0) and is_equal_approx(parts["charcoal_pit"], -2.0), "by source")
	for i in Data.RATE_WINDOW + 5:
		s.flows.advance(1.0)
	t.check(s.flows.rate("wood") == 0.0, "old flows drop out of the window")
	var s2: GameState = t.fresh()
	s2.inv["berries"] = 100
	t.place_free(s2, "gatherers_hut", s2.camp_pos + Vector2i(-2, 0))
	for i in 120:
		s2.tick(0.5)
	t.check(s2.flows.rate("wood") > 0.0, "a working hut makes wood (%.2f/s)" % s2.flows.rate("wood"))
	t.check(s2.flows.rate("berries") < 0.0, "the Kith eat berries (%.2f/s)" % s2.flows.rate("berries"))
	t.check(s2.flows.parts("berries").has("kith"), "eating shows up as its own source")
