extends SceneTree
## Headless logic tests for the simulation.
## Run: godot --headless --path . -s tests/run_tests.gd

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")

var failures := 0


func _init() -> void:
	test_map_has_every_resource_near_camp()
	test_hand_gathering_and_tools()
	test_tech_requires_its_parents()
	test_every_tech_is_reachable()
	test_gatherer_fills_until_hauled()
	test_haulers_automate_a_chain()
	test_grindstone_needs_power()
	test_hungry_buildings_stop()
	test_bronze_dawn_wins()
	test_food_grows_population()
	test_extra_buildings_need_kith()
	test_flour_is_kept_for_research()
	test_gather_summary_and_goals()
	print("FAILED: %d" % failures if failures > 0 else "ALL TESTS PASSED")
	quit(1 if failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


func fresh() -> GameState:
	var s := GameState.new()
	s.generate(42)
	return s


func give(s: GameState, amount: int) -> void:
	for id in Data.ITEM_ORDER:
		s.inv[id] = amount


func find_tile(s: GameState, tile: String) -> Vector2i:
	for y in GameState.HEIGHT:
		for x in GameState.WIDTH:
			if s.tile_at(Vector2i(x, y)) == tile:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func find_grass(s: GameState, near_river: bool) -> Vector2i:
	for y in GameState.HEIGHT:
		for x in GameState.WIDTH:
			var p := Vector2i(x, y)
			if s.tile_at(p) == "grass" and not s.building_at.has(p) and s.touches_river(p) == near_river:
				return p
	return Vector2i(-1, -1)


func test_map_has_every_resource_near_camp() -> void:
	var s := fresh()
	for t in ["tree", "rock", "berry", "grain", "river"]:
		check(find_tile(s, t) != Vector2i(-1, -1), "map has " + t)
	check(s.building_at.has(s.camp_pos), "camp is placed")
	check(s.shard_pos != Vector2i(-1, -1), "star shard is placed")


func test_hand_gathering_and_tools() -> void:
	var s := fresh()
	var tree := find_tile(s, "tree")
	s.gather_by_hand(tree)
	check(s.inv["wood"] == 1, "hand gather gives 1 wood")
	s.researched["knapping"] = true
	s.inv["flint"] = 2
	s.inv["wood"] = 2
	check(s.craft("flint_tools"), "can craft flint tools")
	check(s.inv["wood"] == 0, "crafting spent the wood")
	check(s.inv["flint_tools"] == 1, "have flint tools")
	s.gather_by_hand(tree)
	check(s.inv["wood"] == 2, "flint tools double hand gathering")
	check(s.gather_by_hand(s.shard_pos) == Data.SHARD_TEXT, "shard shows flavor text")


func test_tech_requires_its_parents() -> void:
	var s := fresh()
	give(s, 999)
	check(not s.can_research("gatherers_hut"), "hut needs knapping first")
	check(s.research("knapping"), "knapping is a root")
	check(s.research("gatherers_hut"), "hut unlocked after knapping")


func test_every_tech_is_reachable() -> void:
	var s := fresh()
	give(s, 9999)
	for i in Data.TECH_ORDER.size():
		for tech in Data.TECH_ORDER:
			s.research(tech)
	check(s.researched.size() == Data.TECHS.size(), "all techs reachable")
	check(s.won, "researching Bronze Dawn wins")


func test_gatherer_fills_until_hauled() -> void:
	var s := fresh()
	give(s, 100)
	s.researched["gatherers_hut"] = true
	var p := s.camp_pos + Vector2i(-2, 0)
	check(s.place("gatherers_hut", p), "place hut next to forest")
	for i in 400:
		s.tick(0.5)
	var b: Dictionary = s.buildings[s.building_at[p]]
	check(s.buffered(b["out"]) == Data.BUFFER_CAP, "hut stops when full")
	var before: int = s.inv["wood"]
	s.haul(s.building_at[p])
	check(s.buffered(b["out"]) == 0, "hauling empties the hut")
	check(s.inv["wood"] > before, "hauled wood reaches the stockpile")


func test_haulers_automate_a_chain() -> void:
	var s := fresh()
	give(s, 50)
	s.researched["fire"] = true
	s.researched["haulers"] = true
	var p := find_grass(s, false)
	check(s.place("charcoal_pit", p), "place charcoal pit")
	var charcoal_before: int = s.inv["charcoal"]
	for i in 100:
		s.tick(0.5)
	check(s.inv["charcoal"] > charcoal_before, "haulers deliver charcoal without clicks")


func test_grindstone_needs_power() -> void:
	var s := fresh()
	give(s, 100)
	for t in ["cordage", "knapping", "water_wheel", "fire", "pottery", "grindstone", "haulers"]:
		s.researched[t] = true
	var far := find_grass(s, false)
	var wheel_spot := find_grass(s, true)
	check(s.placement_error("water_wheel", far) == "Must touch the river", "wheel needs river")
	check(s.place("grindstone", far), "place grindstone")
	s.tick(1.0)
	var g: Dictionary = s.buildings[s.building_at[far]]
	if not s.is_powered(far):
		check(g["status"].begins_with("No power"), "unpowered grindstone waits")
	check(s.place("water_wheel", wheel_spot), "place wheel by river")
	check(s.is_powered(wheel_spot), "wheel powers its own tile")


func test_hungry_buildings_stop() -> void:
	var s := fresh()
	s.researched["gatherers_hut"] = true
	s.inv["wood"] = 10
	s.inv["stone"] = 5
	s.inv["berries"] = 0
	s.inv["flour"] = 0
	s.food_credit = 0.0
	var p := s.camp_pos + Vector2i(-2, 0)
	s.place("gatherers_hut", p)
	s.tick(1.0)
	var b: Dictionary = s.buildings[s.building_at[p]]
	check(b["status"].begins_with("Hungry"), "no food means hungry")


func test_bronze_dawn_wins() -> void:
	var s := fresh()
	give(s, 999)
	for t in ["pottery", "grindstone", "haulers"]:
		s.researched[t] = true
	check(s.research("bronze_dawn"), "research bronze dawn")
	check(s.won, "game is won")


func test_food_grows_population() -> void:
	var s := fresh()
	s.inv["berries"] = 100
	for i in 40:
		s.tick(1.0)
	check(s.population > Data.START_POPULATION, "spare food grows the population")
	s.inv["berries"] = 0
	s.food_credit = 0.0
	var before := s.population
	for i in 30:
		s.tick(1.0)
	check(s.population < before, "no food shrinks the population")
	check(s.population >= 1, "never below one Kith")


func test_extra_buildings_need_kith() -> void:
	var s := fresh()
	give(s, 500)
	s.researched["fire"] = true
	var placed := 0
	for y in GameState.HEIGHT:
		for x in GameState.WIDTH:
			if placed < Data.START_POPULATION + 1 and s.place("charcoal_pit", Vector2i(x, y)):
				placed += 1
	for b in s.buildings:
		b["inbuf"]["wood"] = 10  # loaded, so each one wants to work
	s.tick(0.1)
	var unstaffed := 0
	for b in s.buildings:
		if b["status"].begins_with("No worker"):
			unstaffed += 1
	check(unstaffed == 1, "one building more than the Kith has no worker")


func test_flour_is_kept_for_research() -> void:
	var s := fresh()
	s.inv["berries"] = 0
	s.inv["flour"] = 35
	check(s.edible("flour") == 5, "flour beyond the Bronze Dawn cost is edible")
	for i in 400:
		s.tick(1.0)
	check(s.inv["flour"] == 30, "the Kith never eat the flour research needs")
	s.researched["bronze_dawn"] = true
	check(s.edible("flour") == 30, "flour is all food once research is done")


func test_gather_summary_and_goals() -> void:
	var s := fresh()
	var p := s.camp_pos + Vector2i(-2, 0)
	check(s.gather_summary("gatherers_hut", p).contains("Wood"), "hut by the forest will gather wood")
	check(s.current_goal()["kind"] == "items", "first goal is gathering")
	s.inv["wood"] = 10
	s.inv["stone"] = 5
	check(s.current_goal()["id"] == "fire", "goals advance when done")
