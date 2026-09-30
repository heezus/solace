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
	test_flour_is_kept_for_research()
	test_goals_advance_in_order()
	test_hut_gather_preview_matches_placement()
	test_shortfall_text()
	test_kith_staff_buildings_in_order()
	test_population_grows_with_food_and_room()
	test_starving_kith_leave()
	test_distance_slows_haulers()
	test_roads_bridge_the_river()
	test_tech_tree_is_a_web()
	test_tech_effects()
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
	for t in Data.TECHS["bronze_dawn"]["requires"]:
		s.researched[t] = true
	check(s.research("bronze_dawn"), "research bronze dawn")
	check(s.won, "game is won")


func test_flour_is_kept_for_research() -> void:
	var s := fresh()
	s.inv["berries"] = 0
	var keep := 0
	for tech in Data.TECHS:
		keep += Data.TECHS[tech]["cost"].get("flour", 0)
	s.inv["flour"] = keep
	s.food_credit = 0.0
	check(keep > 0 and s.flour_reserve() == keep, "flour that research needs is reserved")
	check(not s._eat(1.0), "reserved flour is not eaten")
	check(s.inv["flour"] == keep, "flour untouched")
	s.inv["flour"] = keep + 1
	check(s._eat(1.0), "flour above the reserve is eaten")
	check(s.inv["flour"] == keep, "only the spare flour was eaten")
	for tech in Data.TECHS:
		s.researched[tech] = true
	check(s.flour_reserve() == 0, "no reserve once researched")


func test_goals_advance_in_order() -> void:
	var s := fresh()
	check(s.current_goal() == 0, "first goal is gathering")
	s.inv["wood"] = 10
	s.inv["stone"] = 10
	s.inv["flint"] = 5
	s.tick(0.1)
	check(s.current_goal() == 1, "gathering done, next is knapping")
	s.research("knapping")
	s.tick(0.1)
	check(s.current_goal() == 2, "knapping done, next is flint tools")
	check(s.goals_done.has("gather"), "earlier goals stay done after spending")


func test_hut_gather_preview_matches_placement() -> void:
	var s := fresh()
	give(s, 100)
	s.researched["gatherers_hut"] = true
	var p := s.camp_pos + Vector2i(-2, 0)
	var preview := s.gather_tiles(p)
	check(preview.size() > 0, "preview finds the forest next to camp")
	s.place("gatherers_hut", p)
	var b: Dictionary = s.buildings[s.building_at[p]]
	check(b["gather_items"].size() == preview.size(), "hut works exactly the previewed tiles")


func test_shortfall_text() -> void:
	var s := fresh()
	s.inv["stone"] = 4
	s.inv["clay"] = 0
	check(s.shortfall_text({"stone": 10, "clay": 10}) == "need 6 Stone, 10 Clay", "shortfall lists what's missing")
	s.inv["stone"] = 10
	s.inv["clay"] = 10
	check(s.shortfall_text({"stone": 10, "clay": 10}) == "", "no shortfall when affordable")


func place_free(s: GameState, type: String, p: Vector2i) -> bool:
	s.add("wood", 100)
	s.add("stone", 100)
	s.add("fiber", 100)
	s.add("grain", 100)
	s.researched[Data.BUILDINGS[type]["tech"]] = true
	return s.place(type, p)


func test_kith_staff_buildings_in_order() -> void:
	var s := fresh()
	s.inv["berries"] = 100
	check(s.kith.size() == Data.KITH_START, "start with the starting Kith")
	for i in 4:
		place_free(s, "gatherers_hut", s.camp_pos + Vector2i(-2, i - 2))
	s.tick(0.1)
	var staffed := 0
	for b in s.buildings:
		if b["worker"] >= 0:
			staffed += 1
	check(staffed == Data.KITH_START, "one worker per building, as many as there are Kith")
	var last: Dictionary = s.buildings[s.buildings.size() - 1]
	check(last["worker"] == -1 and last["status"].begins_with("No worker"), "the newest building waits for a worker")


func test_population_grows_with_food_and_room() -> void:
	var s := fresh()
	s.inv["berries"] = 200
	for i in int(Data.GROW_TIME * 2 + 2):
		s.tick(1.0)
	check(s.kith.size() == s.housing(), "grows until the Camp is full")
	check(s.growth_note().begins_with("No room"), "says it needs room")
	place_free(s, "dwelling", s.camp_pos + Vector2i(0, 2))
	for i in int(Data.GROW_TIME + 2):
		s.tick(1.0)
	check(s.kith.size() == s.housing() - 2, "a Dwelling makes room for more")


func test_starving_kith_leave() -> void:
	var s := fresh()
	s.inv["berries"] = 0
	s.food_credit = 0.0
	for i in int(Data.STARVE_TIME + 1):
		s.tick(1.0)
	check(s.kith.size() == Data.KITH_START - 1, "a Kith leaves after starving")


## Two identical charcoal pits, one next to the Camp and one far away: the near one delivers more.
func haul_rate(dist_x: int) -> int:
	var s := GameState.new()
	s.tiles.resize(GameState.WIDTH * GameState.HEIGHT)
	s.tiles.fill("grass")
	s.camp_pos = Vector2i(1, 10)
	s._place_building("camp", s.camp_pos)
	s._build_walk_grid()
	for i in Data.KITH_START:
		s._add_kith()
	s.inv["berries"] = 500
	s.inv["wood"] = 500
	s.researched["haulers"] = true
	place_free(s, "charcoal_pit", s.camp_pos + Vector2i(dist_x, 0))
	s.inv["charcoal"] = 0
	for i in 600:
		s.tick(0.25)
	return s.inv["charcoal"]


func test_distance_slows_haulers() -> void:
	var near := haul_rate(2)
	var far := haul_rate(30)
	check(near > 0 and far > 0, "both pits deliver charcoal (near %d, far %d)" % [near, far])
	check(near > far, "distance matters: near pit delivers more (near %d, far %d)" % [near, far])


func test_roads_bridge_the_river() -> void:
	var s := fresh()
	var river := find_tile(s, "river")
	var bank := river + Vector2i(-1, 0)
	var far_bank := river + Vector2i(2, 0)
	check(s.walk_cost(bank) >= 1.0, "no road: normal speed")
	check(s.astar.is_point_solid(river), "the river blocks walking")
	check(place_free(s, "road", river), "a road can cross the river")
	check(place_free(s, "road", river + Vector2i(1, 0)), "both river tiles")
	check(not s.astar.is_point_solid(river), "bridged river is walkable")
	check(s.walk_cost(river) < 1.0, "roads are fast")
	var path := s.astar.get_id_path(bank, far_bank)
	check(river in path, "the path uses the bridge")


func test_tech_tree_is_a_web() -> void:
	var roots := 0
	var multi := 0
	var positions := {}
	for tech in Data.TECHS:
		var t: Dictionary = Data.TECHS[tech]
		roots += 1 if t["requires"].is_empty() else 0
		multi += 1 if t["requires"].size() >= 2 else 0
		for r in t["requires"]:
			check(Data.TECHS.has(r), tech + " requires a real tech")
			check(t["pos"].x > Data.TECHS[r]["pos"].x, tech + " sits right of " + r + " so arrows point forward")
		check(not positions.has(t["pos"]), tech + " has its own spot in the tree")
		positions[t["pos"]] = true
		check(tech in Data.TECH_ORDER, tech + " is listed in TECH_ORDER")
	check(roots >= 3, "several starting techs")
	check(multi >= 6, "many techs join two branches")


func test_tech_effects() -> void:
	var s := fresh()
	var r := s.hut_radius()
	s.researched["scouting"] = true
	check(s.hut_radius() == r + 1, "scouting widens hut reach")
	var berry := find_tile(s, "berry")
	s.inv["berries"] = 0
	s.researched["foraging"] = true
	s.gather_by_hand(berry)
	check(s.inv["berries"] == 2, "foraging doubles berries")
	check(s.carry_cap() == Data.CARRY, "normal carry")
	s.researched["carrying_poles"] = true
	check(s.carry_cap() == Data.CARRY * 2, "carrying poles double carry")
	s.researched["baking"] = true
	check(s.food_value("flour") == 5.0, "baking makes flour worth 5")
	var h := s.housing()
	place_free(s, "dwelling", s.camp_pos + Vector2i(0, 2))
	s.researched["shelter"] = true
	check(s.housing() == h + 5, "thatched dwellings house 5")
	var road := s.camp_pos + Vector2i(1, 1)
	place_free(s, "road", road)
	var slow := s.walk_cost(road)
	s.research("paved_roads")
	s.researched["paved_roads"] = true
	s._update_walk_cell(road)
	check(s.walk_cost(road) < slow, "paved roads are faster")
	var grass := find_grass(s, false)
	check(place_free(s, "field", grass), "sow a field")
	check(s.tile_at(grass) == "grain", "field grows grain")
