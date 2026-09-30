extends SceneTree
## Headless logic tests for the simulation.
## Run: godot --headless --path . -s tests/run_tests.gd

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")
const Main = preload("res://scripts/main.gd")
const TechLayout = preload("res://scripts/tech_layout.gd")
const Ui = preload("res://scripts/ui.gd")
const Goals = preload("res://scripts/goals.gd")
const Rules = preload("res://scripts/rules.gd")
const ConventionTests = preload("res://tests/convention_tests.gd")
const BonusTests = preload("res://tests/bonus_tests.gd")
const Autoplay = preload("res://tests/autoplay.gd")

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
	test_tech_tree_v4()
	test_tech_effects()
	test_requires_any()
	test_star_lore_is_hidden_until_the_shard_is_clicked()
	test_shard_cairn()
	test_smoking_makes_berries_worth_more()
	test_rafts_cross_the_river()
	test_calendar_gates_bronze_dawn()
	test_lore_and_side_branch_effects()
	test_fishing_weir_makes_fish()
	ConventionTests.new().run(self)
	BonusTests.new().run(self)
	test_pacing_bot()
	print("FAILED: %d" % failures if failures > 0 else "ALL TESTS PASSED")
	quit(1 if failures > 0 else 0)


## A headless player (tests/autoplay.gd) plays the stone age on a few maps. It should reach Bronze Dawn
## in 8 to 25 simulated minutes; data.gd is tuned so it takes about 12 to 16.
func test_pacing_bot() -> void:
	for seed in [1, 2, 3]:
		var r: Dictionary = Autoplay.new().play(seed, 30 * 60.0)
		var minutes: float = r["seconds"] / 60.0
		print(
			(
				"Pacing bot, map %d: %s at %.1f simulated minutes"
				% [seed, "Bronze Dawn" if r["won"] else "no win", minutes]
			)
		)
		check(r["won"], "the bot reaches Bronze Dawn on map %d" % seed)
		check(minutes >= 8.0 and minutes <= 25.0, "map %d takes 8 to 25 minutes (%.1f)" % [seed, minutes])
		if not r["won"]:
			for line in r["log"]:
				print("  ", line)


func check(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


## A new camp with the whole map explored, so tests can build anywhere.
func fresh() -> GameState:
	var s := GameState.new()
	s.generate(42)
	s.fog.reveal_all()
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
	var start := GameState.new()
	start.generate(7)
	for t in ["tree", "rock", "berry", "grain", "gravel"]:
		var near := false
		for y in range(-Data.SIGHT_START, Data.SIGHT_START + 1):
			for x in range(-Data.SIGHT_START, Data.SIGHT_START + 1):
				var p: Vector2i = start.camp_pos + Vector2i(x, y)
				near = near or (start.tile_at(p) == t and start.fog.is_revealed(p))
		check(near, t + " is in sight of the Hearth at the start")
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
	check(not s.shard_seen, "the shard starts unseen")
	check(s.gather_by_hand(s.shard_pos) == Data.SHARD_TEXT, "shard shows flavor text")
	check(s.shard_seen, "clicking the shard marks it seen")


func test_tech_requires_its_parents() -> void:
	var s := fresh()
	give(s, 999)
	check(not s.can_research("gatherers_hut"), "hut needs knapping first")
	check(s.research("knapping"), "knapping is a root")
	check(not s.can_research("gatherers_hut"), "the hut needs Foraging too: tools to build it, food to fill it")
	check(s.research("foraging"), "foraging is a root")
	check(s.research("gatherers_hut"), "hut unlocked after knapping and foraging")


func test_every_tech_is_reachable() -> void:
	var s := fresh()
	give(s, 9999)
	s.gather_by_hand(s.shard_pos)  # reveals Star Lore
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
	check(Goals.current_goal(s) == 0, "first goal is gathering")
	s.inv["wood"] = 10
	s.inv["stone"] = 10
	s.inv["flint"] = 5
	s.tick(0.1)
	check(Goals.current_goal(s) == 1, "gathering done, next is knapping")
	s.research("knapping")
	s.tick(0.1)
	check(Goals.current_goal(s) == 2, "knapping done, next is flint tools")
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
	check(
		Ui.shortfall_text(s.inv, {"stone": 10, "clay": 10}) == "need 6 Stone, 10 Clay", "shortfall lists what's missing"
	)
	s.inv["stone"] = 10
	s.inv["clay"] = 10
	check(Ui.shortfall_text(s.inv, {"stone": 10, "clay": 10}) == "", "no shortfall when affordable")


func place_free(s: GameState, type: String, p: Vector2i) -> bool:
	s.add("wood", 100)
	s.add("stone", 100)
	s.add("fiber", 100)
	s.add("grain", 100)
	s.add("rope", 100)
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
	check(Ui.growth_note(s).begins_with("No room"), "says it needs room")
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
	s.fog.setup(GameState.WIDTH, GameState.HEIGHT)
	s.fog.reveal_all()
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


## A Wooden Bridge (Paths & Haulers) spans the river at road speed.
func test_roads_bridge_the_river() -> void:
	var s := fresh()
	var river := find_tile(s, "river")
	var bank := river + Vector2i(-1, 0)
	var far_bank := river + Vector2i(2, 0)
	check(s.walk_cost(bank) >= 1.0, "no road: normal speed")
	check(s.astar.is_point_solid(river), "the river blocks walking")
	check(Data.BUILDINGS["bridge"]["tech"] == "haulers", "bridges come with Paths & Haulers")
	s.researched["haulers"] = true
	s.inv["wood"] = 100
	s.inv["rope"] = 10
	check(s.placement_error("bridge", bank) == "Bridges go on river tiles", "bridges only go on the river")
	var wood: int = s.inv["wood"] + 100
	check(place_free(s, "bridge", river), "a bridge goes on the river")
	check(s.inv["wood"] == wood - 10, "a bridge costs 10 Wood")
	check(place_free(s, "bridge", river + Vector2i(1, 0)), "both river tiles")
	check(not s.astar.is_point_solid(river), "bridged river is walkable")
	check(s.walk_cost(river) < 1.0, "bridges are road speed")
	var path := s.astar.get_id_path(bank, far_bank)
	check(river in path, "the path uses the bridge")
	check(s.built_type(river) == "bridge", "it counts as a bridge")


## Every parent sits left of its child, no two cards overlap, and most techs join two branches.
func test_tech_tree_is_a_web() -> void:
	check(Data.TECHS.size() == 28, "the stone age has 28 techs")
	check(Data.TECH_ORDER.size() == Data.TECHS.size(), "TECH_ORDER lists every tech once")
	var roots := 0
	var multi := 0
	for tech in Data.TECHS:
		var t: Dictionary = Data.TECHS[tech]
		var any: Array = t.get("requires_any", [])
		roots += 1 if t["requires"].is_empty() and any.is_empty() else 0
		multi += 1 if t["requires"].size() + mini(any.size(), 1) >= 2 else 0
		check(any.size() != 1, tech + ": an either-or list needs at least two techs")
		for r in t["requires"] + any:
			check(Data.TECHS.has(r), tech + " requires a real tech")
			check(t["tier"] > Data.TECHS[r]["tier"], tech + " sits right of " + r + " so arrows point forward")
		check(tech in Data.TECH_ORDER, tech + " is listed in TECH_ORDER")
		check(t.has("color") and t.has("abbr") and t.has("desc"), tech + " has a color, badge and text")
		check(
			t.has("unlock") and t.has("icon") and (Data.LANES.has(t["lane"]) or t["lane"] == "gate"),
			tech + " has a card"
		)
	check(roots == 5, "five starting techs, one per lane")
	check(multi >= 15, "most techs join two branches")
	check_cards_dont_overlap()
	var colors := {}
	for tech in Data.TECHS:
		colors[Data.TECHS[tech]["color"].to_html()] = true
	check(colors.size() == Data.TECHS.size(), "every tech has its own color")
	for tech in Data.TECHS:
		check("star_lore" not in Data.TECHS[tech]["requires"], tech + " doesn't strictly need hidden Star Lore")


## Tech tree v4 (mockups/tech-tree-v4.md): each link reads "you need X to invent Y".
func test_tech_tree_v4() -> void:
	check(TechLayout.links().size() == 48, "v4 has 48 links (%d)" % TechLayout.links().size())
	check(Data.LANE_ORDER == ["fiber", "stone", "land", "hearth", "lore"], "lanes run Fiber, Stone, Land, Hearth, Lore")
	check(Data.TECHS["bronze_dawn"]["tier"] == 5, "the gate sits after Tier V")
	check(Data.TIER_NAMES.size() == 6, "every column has a caption")
	var links := {
		"gatherers_hut": ["knapping", "foraging"],
		"stone_axe": ["knapping", "cordage"],
		"shelter": ["cordage", "foraging"],
		"farming": ["gatherers_hut", "stone_axe"],
		"scouting": ["gatherers_hut", "storytelling"],
		"water_wheel": ["stone_axe", "masonry"],
		"rafts": ["nets", "stone_axe"],
		"grindstone": ["water_wheel", "farming"],
		"carrying_poles": ["haulers", "stone_axe"],
		"baking": ["grindstone", "pottery"],
	}
	for tech in links:
		var want: Array = links[tech].duplicate()
		var have: Array = Data.TECHS[tech]["requires"].duplicate()
		want.sort()
		have.sort()
		check(have == want, "%s needs %s (has %s)" % [tech, want, have])
	for tech in ["nets", "smoking", "stone_axe"]:
		check(Data.TECHS[tech]["tier"] == 1, tech + " sits in Tier II")
	for tech in Data.TECHS:
		check(Data.TECHS[tech]["slot"] <= 1, tech + ": each lane has two rows")
	# Side branches are exactly the techs Bronze Dawn can do without.
	var route := Rules.route_to("bronze_dawn", {}, Rules.visible_techs(true))
	check(route.size() == 18, "Bronze Dawn needs 18 techs (%d)" % route.size())
	for tech in Data.TECHS:
		check(
			Data.TECHS[tech].get("side", false) == (tech not in route), tech + " is a side branch only if off the route"
		)


func check_cards_dont_overlap() -> void:
	var lay := TechLayout.build()
	var rects: Dictionary = lay["rects"]
	for a in rects:
		for b in rects:
			if a < b:
				check(not rects[a].intersects(rects[b]), a + " and " + b + " cards don't overlap")


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


## Megaliths needs Masonry and one of Storytelling or Star Lore; either one alone is enough.
func test_requires_any() -> void:
	var s := fresh()
	give(s, 999)
	for t in ["knapping", "fire", "masonry"]:
		check(s.research(t), "research " + t)
	check(not s.requirements_met("megaliths"), "Megaliths needs Storytelling or Star Lore too")
	check(s.missing_requirements("megaliths") == 1, "an either-or counts as one missing tech")
	check(s.research("storytelling"), "research Storytelling")
	check(s.can_research("megaliths"), "Storytelling alone unlocks Megaliths")
	var s2 := fresh()
	give(s2, 999)
	s2.gather_by_hand(s2.shard_pos)
	for t in ["knapping", "fire", "masonry", "star_lore"]:
		s2.researched[t] = true
	check(not s2.researched.has("storytelling"), "no Storytelling in the second camp")
	check(s2.can_research("megaliths"), "Star Lore alone unlocks Megaliths")
	check(s2.research("megaliths"), "research Megaliths through Star Lore")


func test_star_lore_is_hidden_until_the_shard_is_clicked() -> void:
	var s := fresh()
	give(s, 999)
	check(s.research("storytelling"), "research Storytelling")
	check(not s.tech_visible("star_lore"), "Star Lore is hidden at first")
	check(not s.can_research("star_lore"), "hidden Star Lore can't be researched")
	check(s.tech_visible("megaliths"), "other techs are visible")
	s.gather_by_hand(s.shard_pos)
	check(s.tech_visible("star_lore"), "clicking the Strange Stone reveals Star Lore")
	check(s.research("star_lore"), "then it can be researched")
	check(s.building_unlocked("shard_cairn"), "Star Lore unlocks the Shard Cairn")


func test_shard_cairn() -> void:
	var s := fresh()
	give(s, 100)
	s.shard_seen = true
	s.researched["star_lore"] = true
	check(
		s.placement_error("shard_cairn", s.camp_pos + Vector2i(0, 2)) == "Must go next to the Strange Stone",
		"cairn needs the shard"
	)
	for n in GameState.NEIGHBORS:
		var p: Vector2i = s.shard_pos + n
		if s.tile_at(p) == "grass" and not s.building_at.has(p):
			check(s.place("shard_cairn", p), "cairn goes beside the shard")
			s.tick(0.1)
			check(s.buildings[s.building_at[p]]["status"] == "It hums. Nothing more. Yet.", "the cairn only hums")
			return


func test_smoking_makes_berries_worth_more() -> void:
	var s := fresh()
	s.inv["berries"] = 10
	s.inv["flour"] = 0
	check(s.food_value("berries") == 1.0, "berries are worth 1")
	var before := s.food_total()
	s.researched["smoking"] = true
	check(s.food_value("berries") == 2.0, "smoked berries are worth 2")
	check(s.food_total() == before * 2.0, "smoking doubles berry food")


func test_rafts_cross_the_river() -> void:
	var s := fresh()
	give(s, 999)
	var river := find_tile(s, "river")
	check(s.astar.is_point_solid(river), "the river blocks walking")
	for t in ["cordage", "foraging", "knapping", "nets"]:
		s.researched[t] = true
	check(not s.can_research("rafts"), "Rafts need logs: Stone Axe first")
	s.researched["stone_axe"] = true
	check(s.research("rafts"), "research Rafts")
	check(not s.astar.is_point_solid(river), "Rafts make the river walkable")
	check(s.walk_cost(river) == Data.WALK_COST["river"], "rafting is slow")
	check(s.walk_cost(river) > 1.0, "slower than open ground")
	var path := s.astar.get_id_path(river + Vector2i(-1, 0), river + Vector2i(2, 0))
	check(not path.is_empty(), "Kith can cross without a bridge")
	place_free(s, "bridge", river)
	check(s.walk_cost(river) < 1.0, "a bridge is still road speed")


func test_calendar_gates_bronze_dawn() -> void:
	var s := fresh()
	give(s, 999)
	check("calendar" in Data.TECHS["bronze_dawn"]["requires"], "Bronze Dawn requires Calendar")
	for t in Data.TECHS["bronze_dawn"]["requires"]:
		if t != "calendar":
			s.researched[t] = true
	check(not s.can_research("bronze_dawn"), "no Bronze Dawn without Calendar")
	s.researched["farming"] = true
	s.researched["storytelling"] = true
	check(s.research("calendar"), "Calendar through Farming and Storytelling")
	check(s.research("bronze_dawn"), "then Bronze Dawn")
	var ids: Array = Data.GOALS.map(func(g): return g["id"])
	check(ids.find("calendar") == ids.find("bronze") - 1, "the Calendar goal comes right before Bronze Dawn")


func test_lore_and_side_branch_effects() -> void:
	var s := fresh()
	check(s._grow_time() == Data.GROW_TIME, "normal grow time")
	s.researched["storytelling"] = true
	check(s._grow_time() == Data.GROW_TIME * 0.75, "Storytelling: Kith born 25% faster")

	var p := s.camp_pos + Vector2i(-2, 0)
	place_free(s, "gatherers_hut", p)
	var hut: Dictionary = s.buildings[s.building_at[p]]
	var base := s._work_time(hut)
	var clay := find_tile(s, "clay")
	check(s._harvest_amount(hut, clay, "clay") == 1, "one clay per harvest")
	s.researched["ochre"] = true
	check(s._harvest_amount(hut, clay, "clay") == 2, "Ochre: huts bring back twice the Clay")
	check(is_equal_approx(s.work_speed(hut), 1.0), "Ochre doesn't touch speed")
	check(place_free(s, "standing_stone", p + Vector2i(0, 2)), "place a Standing Stone 2 tiles off")
	check(is_equal_approx(s.work_speed(hut), 1.0), "2 tiles off is too far for a Standing Stone")
	check(place_free(s, "standing_stone", p + Vector2i(1, 1)), "place a Standing Stone right next to the hut")
	check(is_equal_approx(s.work_speed(hut), 2.0), "Standing Stone: twice as fast next to it")
	check(is_equal_approx(s._work_time(hut), base / 2.0), "and the cycle takes half as long")

	var tree := find_tile(s, "tree")
	check(s._harvest_amount(hut, tree, "wood") == 1, "one wood per harvest")
	s.researched["stone_axe"] = true
	check(s._harvest_amount(hut, tree, "wood") == 2, "Stone Axe: huts gather Wood twice as fast")

	var field := find_grass(s, true)
	check(place_free(s, "field", field), "sow a field by the river")
	var total := 0
	for i in 4:
		total += s._harvest_amount(hut, field, "grain")
	check(total == 4, "four harvests of a Field give 4 grain")
	s.researched["calendar"] = true
	total = 0
	for i in 4:
		total += s._harvest_amount(hut, field, "grain")
	check(total == 5, "Calendar: Fields yield 25% more")

	var dry := find_grass(s, false)
	place_free(s, "field", dry)
	var t := s._harvest_time(hut, field)
	s.researched["irrigation"] = true
	check(is_equal_approx(s._harvest_time(hut, field), t / 2.0), "Irrigation: river Fields grow twice as fast")
	check(is_equal_approx(s._harvest_time(hut, dry), t), "dry Fields are unchanged")


func test_fishing_weir_makes_fish() -> void:
	var s := fresh()
	s.inv["berries"] = 100
	var bank := Vector2i(-1, -1)
	for y in GameState.HEIGHT:
		for x in GameState.WIDTH:
			var p := Vector2i(x, y)
			if bank.x < 0 and s.tile_at(p) == "grass" and s.tile_at(p + Vector2i(1, 0)) == "river":
				bank = p
	check(s.placement_error("fishing_weir", s.camp_pos + Vector2i(0, 2)) != "", "weir needs Nets and the river")
	s.add("rope", 10)
	check(place_free(s, "fishing_weir", bank), "place a weir on the near bank")
	for i in 200:
		s.tick(0.5)
	var b: Dictionary = s.buildings[s.building_at[bank]]
	check(b["out"].get("fish", 0) > 0, "the weir traps fish")
	check(s.food_value("fish") == 2.0, "fish are worth 2 food")
