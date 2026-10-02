extends SceneTree
## Headless logic tests for the simulation.
## Run: godot --headless --path . -s tests/run_tests.gd

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Main = preload("res://scripts/main.gd")
const TechLayout = preload("res://scripts/tech_layout.gd")
const Ui = preload("res://scripts/ui.gd")
const Rules = preload("res://scripts/rules.gd")
const Hands = preload("res://scripts/hands.gd")
const Haulers = preload("res://scripts/haulers.gd")
const ConventionTests = preload("res://tests/convention_tests.gd")
const BonusTests = preload("res://tests/bonus_tests.gd")
const EconomyTests = preload("res://tests/economy_tests.gd")
const ResearchTests = preload("res://tests/research_tests.gd")
const WorldTests = preload("res://tests/world_tests.gd")
const MapgenTests = preload("res://tests/mapgen_tests.gd")
const PathingTests = preload("res://tests/pathing_tests.gd")
const BuildingsTests = preload("res://tests/buildings_tests.gd")
const KithTests = preload("res://tests/kith_tests.gd")
const ArcTests = preload("res://tests/arc_tests.gd")
const StoryTests = preload("res://tests/story_tests.gd")
const SaveTests = preload("res://tests/save_tests.gd")
const EraTests = preload("res://tests/era_tests.gd")
const Stage2Tests = preload("res://tests/stage2_tests.gd")
const SkyTests = preload("res://tests/sky_tests.gd")
const Autoplay = preload("res://tests/autoplay.gd")
const AutoplayBronze = preload("res://tests/autoplay_bronze.gd")
const GoldenTests = preload("res://tests/golden_tests.gd")
const NewcomerTests = preload("res://tests/newcomer_tests.gd")
const UiTests = preload("res://tests/ui_tests.gd")
const HutFocusTests = preload("res://tests/hut_focus_tests.gd")
const GrowthTests = preload("res://tests/growth_tests.gd")
const ForageTests = preload("res://tests/forage_tests.gd")
const HaulerTests = preload("res://tests/hauler_tests.gd")
const World = preload("res://scripts/world.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Work = preload("res://scripts/work.gd")

var failures := 0


func _init() -> void:
	if "stage2" in OS.get_cmdline_user_args():  # `-- stage2` runs only the second stage's tests while iterating
		Stage2Tests.new().run(self)
		SkyTests.new().run(self)
		print("FAILED: %d" % failures if failures > 0 else "STAGE 2 TESTS PASSED")
		quit(1 if failures > 0 else 0)
		return
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
	EconomyTests.new().run(self)
	ResearchTests.new().run(self)
	WorldTests.new().run(self)
	MapgenTests.new().run(self)
	PathingTests.new().run(self)
	BuildingsTests.new().run(self)
	KithTests.new().run(self)
	StoryTests.new().run(self)
	ArcTests.new().run(self)
	SaveTests.new().run(self)
	EraTests.new().run(self)
	Stage2Tests.new().run(self)
	SkyTests.new().run(self)
	HutFocusTests.new().run(self)
	GrowthTests.new().run(self)
	ForageTests.new().run(self)
	HaulerTests.new().run(self)
	NewcomerTests.new().run(self)
	UiTests.new().run(self)
	if not "fast" in OS.get_cmdline_user_args():  # `-- fast` skips the bot's slow runs while iterating
		test_pacing_bot()
		SaveTests.new().run_system(self)
	print("FAILED: %d" % failures if failures > 0 else "ALL TESTS PASSED")
	quit(1 if failures > 0 else 0)


## A headless player (tests/autoplay_bronze.gd) plays the stone age on a few maps. It should reach Bronze Dawn
## in 8 to 25 simulated minutes; data.gd is tuned so it takes about 12 to 16. The game at that moment must match
## tests/golden.json. It then plays on to its first Bronze, which should come 7 to 14 minutes later (the target is about
## 8 to 12), and the game at that moment must match tests/golden_bronze.json.
func test_pacing_bot() -> void:
	var golden := GoldenTests.new()
	var have_golden := golden.load_golden(self)
	for map_seed in [1, 2, 3]:
		var bot := AutoplayBronze.new()
		if have_golden:
			bot.on_dawn = golden.check_dawn.bind(map_seed)  # win time and state at Bronze Dawn: tests/golden.json
		var r: Dictionary = bot.play_bronze(map_seed, 50 * 60.0)
		if have_golden:
			golden.check_bronze(map_seed, bot)  # and at the first Bronze: tests/golden_bronze.json
		var minutes: float = r["seconds"] / 60.0
		print(
			(
				"Pacing bot, map %d: %s at %.1f simulated minutes, first Bronze %.1f minutes later"
				% [map_seed, "Bronze Dawn" if r["won"] else "no win", minutes, r["minutes"]]
			)
		)
		check(r["won"], "the bot reaches Bronze Dawn on map %d" % map_seed)
		check(minutes >= 8.0 and minutes <= 25.0, "map %d takes 8 to 25 minutes (%.1f)" % [map_seed, minutes])
		check(
			r["minutes"] >= 7.0 and r["minutes"] <= 14.0,
			"map %d: the first Bronze takes 7 to 14 minutes more (%.1f)" % [map_seed, r["minutes"]]
		)
		if not r["won"] or r["minutes"] < 0.0:
			for line in r["log"]:
				print("  ", line)


func check(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


## A new camp with the whole map explored, so tests can build anywhere.
func fresh() -> Sim:
	var s := Sim.new()
	s.generate(42)
	s.fog.reveal_all()
	return s


## Stock the stockpile with `amount` of every good, except Bronze Tools: a worker who takes one works twice as fast, so a
## test that wants them sets them itself.
func give(s: Sim, amount: int) -> void:
	for id in Data.ITEM_ORDER:
		s.economy.inv[id] = 0 if id == "bronze_tools" else amount


## A spot where the river is 2 tiles wide between two open banks: {"river": its first tile, "side": the
## step across it (east or south)}. The bridge tests build on it.
func _find_crossing(s: Sim) -> Dictionary:
	for y in s.world.height:
		for x in s.world.width:
			for side in [Vector2i(1, 0), Vector2i(0, 1)]:
				var p := Vector2i(x, y)
				var open := func(q: Vector2i) -> bool: return s.world.tile_at(q) in ["grass", "tree", "clay", "gravel"]
				var wet := func(q: Vector2i) -> bool: return s.world.tile_at(q) == "river"
				if open.call(p - side) and wet.call(p) and wet.call(p + side) and open.call(p + side * 2):
					return {"river": p, "side": side}
	return {"river": find_tile(s, "river"), "side": Vector2i(1, 0)}


func find_tile(s: Sim, tile: String) -> Vector2i:
	for y in s.world.height:
		for x in s.world.width:
			if s.world.tile_at(Vector2i(x, y)) == tile:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Link the building at p to the Hearth with road (test setup, not the placement rules): the shortest
## side-by-side path over tiles with no building on them, the ends left off.
func road_link(s: Sim, p: Vector2i) -> void:
	var from := {}
	var todo: Array = [p]
	from[p] = p
	var found := false
	while not todo.is_empty() and not found:
		var q: Vector2i = todo.pop_front()
		for n in World.NEIGHBORS:
			var r: Vector2i = q + n
			if from.has(r) or not s.world.in_bounds(r) or s.world.tile_at(r) == "river":
				continue
			if r == s.world.camp_pos:
				from[r] = q
				found = true
				break
			if s.town.building_at.has(r):
				continue
			from[r] = q
			todo.append(r)
	var at: Vector2i = from.get(s.world.camp_pos, p)
	while at != p:
		s.world.roads[at] = true
		s.pathing.update_cell(at)
		at = from[at]
	s.town.road_rev += 1


func find_grass(s: Sim, near_river: bool) -> Vector2i:
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			if (
				s.world.tile_at(p) == "grass"
				and not s.town.building_at.has(p)
				and s.world.touches_river(p) == near_river
			):
				return p
	return Vector2i(-1, -1)


func test_map_has_every_resource_near_camp() -> void:
	var s := fresh()
	for t in ["tree", "rock", "berry", "grain", "river"]:
		check(find_tile(s, t) != Vector2i(-1, -1), "map has " + t)
	var start := Sim.new()
	start.generate(7)
	for t in ["tree", "rock", "berry", "grain", "gravel"]:
		var near := false
		for y in range(-Data.SIGHT_START, Data.SIGHT_START + 1):
			for x in range(-Data.SIGHT_START, Data.SIGHT_START + 1):
				var p: Vector2i = start.world.camp_pos + Vector2i(x, y)
				near = near or (start.world.tile_at(p) == t and start.fog.is_revealed(p))
		check(near, t + " is in sight of the Hearth at the start")
	check(s.town.building_at.has(s.world.camp_pos), "camp is placed")
	check(s.world.shard_pos != Vector2i(-1, -1), "star shard is placed")


func test_hand_gathering_and_tools() -> void:
	var s := fresh()
	var tree := find_tile(s, "tree")
	s.gather_by_hand(tree)
	check(s.economy.inv["wood"] == 1, "hand gather gives 1 wood")
	check(is_equal_approx(Hands.hold_time(s, "wood"), Data.HOLD_TIME), "a 1 s hold with bare hands")
	s.tech_tree.researched["knapping"] = true
	s.economy.inv["flint"] = 2
	s.economy.inv["wood"] = 2
	check(Hands.craft(s, "flint_tools"), "can craft flint tools")
	check(s.economy.inv["wood"] == 0, "crafting spent the wood")
	check(s.economy.inv["flint_tools"] == 1, "have flint tools")
	s.gather_by_hand(tree)
	check(s.economy.inv["wood"] == 1, "flint tools don't change the yield by hand")
	check(is_equal_approx(Hands.hold_time(s, "wood"), 0.7), "they shorten the hold to 0.7 s")
	check(not s.shard_seen, "the shard starts unseen")
	check(s.gather_by_hand(s.world.shard_pos) == Data.SHARD_TEXT, "shard shows flavor text")
	check(s.shard_seen, "clicking the shard marks it seen")


func test_tech_requires_its_parents() -> void:
	var s := fresh()
	give(s, 999)
	check(not s.tech_tree.can_research("gatherers_hut"), "hut needs knapping first")
	check(s.research("knapping"), "knapping is a root")
	check(
		not s.tech_tree.can_research("gatherers_hut"), "the hut needs Foraging too: tools to build it, food to fill it"
	)
	check(s.research("foraging"), "foraging is a root")
	check(s.research("gatherers_hut"), "hut unlocked after knapping and foraging")


func test_every_tech_is_reachable() -> void:
	var s := fresh()
	give(s, 9999)
	s.gather_by_hand(s.world.shard_pos)  # reveals Star Lore
	for i in Data.TECH_ORDER.size():
		for tech in Data.TECH_ORDER:
			s.research(tech)
	var built := Data.TECH_ORDER.filter(Rules.tech_enabled)
	check(s.tech_tree.researched.size() == built.size(), "every tech is reachable")
	check(built.size() == Data.TECHS.size(), "and none waits for a later update")
	check(s.won, "researching Bronze Dawn wins")


func test_gatherer_fills_until_hauled() -> void:
	var s := fresh()
	give(s, 100)
	s.people.learned_by["wood"] = "Aro"
	s.tech_tree.researched["gatherers_hut"] = true
	s.tech_tree.researched["haulers"] = true
	var p := s.world.camp_pos + Vector2i(-2, 0)
	check(s.place("gatherers_hut", p), "place hut next to forest")
	road_link(s, p)
	for i in 400:
		s.tick(0.5)
		for k in s.people.kith:
			if k["job"] == "haul":
				k["job"] = "idle"  # nobody free to haul, so the hut fills up
	var b: Dictionary = s.town.buildings[s.town.building_at[p]]
	check(Buildings.buffered(b["out"]) >= Data.BUFFER_CAP, "hut stops when full")
	check(Buildings.buffered(b["out"]) < Data.BUFFER_CAP + Data.BUNDLE, "and brings back no more after that")
	var before: int = s.economy.inv["wood"]
	s.town.haul(s.town.building_at[p])
	check(Buildings.buffered(b["out"]) == 0, "hauling empties the hut")
	check(s.economy.inv["wood"] > before, "hauled wood reaches the stockpile")


func test_haulers_automate_a_chain() -> void:
	var s := fresh()
	give(s, 50)
	s.tech_tree.researched["fire"] = true
	s.tech_tree.researched["haulers"] = true
	var p := find_grass(s, false)
	check(s.place("charcoal_pit", p), "place charcoal pit")
	road_link(s, p)
	var charcoal_before: int = s.economy.inv["charcoal"]
	for i in 100:
		s.tick(0.5)
	check(s.economy.inv["charcoal"] > charcoal_before, "haulers deliver charcoal without clicks")


func test_grindstone_needs_power() -> void:
	var s := fresh()
	give(s, 100)
	for t in ["cordage", "knapping", "water_wheel", "fire", "pottery", "grindstone", "haulers"]:
		s.tech_tree.researched[t] = true
	var far := find_grass(s, false)
	var wheel_spot := find_grass(s, true)
	check(s.town.placement_error("water_wheel", far) == "Must touch the river", "wheel needs river")
	check(s.place("grindstone", far), "place grindstone")
	s.tick(1.0)
	var g: Dictionary = s.town.buildings[s.town.building_at[far]]
	if not s.town.is_powered(far):
		check(g["status"].begins_with("No power"), "unpowered grindstone waits")
	check(s.place("water_wheel", wheel_spot), "place wheel by river")
	check(s.town.is_powered(wheel_spot), "wheel powers its own tile")


func test_hungry_buildings_stop() -> void:
	var s := fresh()
	s.tech_tree.researched["gatherers_hut"] = true
	s.economy.inv["wood"] = 10
	s.economy.inv["stone"] = 5
	s.economy.inv["berries"] = 0
	s.economy.inv["flour"] = 0
	s.economy.food_credit = 0.0
	var p := s.world.camp_pos + Vector2i(-2, 0)
	s.place("gatherers_hut", p)
	s.tick(1.0)
	var b: Dictionary = s.town.buildings[s.town.building_at[p]]
	check(b["status"].begins_with("Hungry"), "no food means hungry")


func test_bronze_dawn_wins() -> void:
	var s := fresh()
	give(s, 999)
	for t in Data.TECHS["bronze_dawn"]["requires"]:
		s.tech_tree.researched[t] = true
	check(s.research("bronze_dawn"), "research bronze dawn")
	check(s.won, "game is won")


func test_flour_is_kept_for_research() -> void:
	var s := fresh()
	s.economy.inv["berries"] = 0
	var keep := 0
	for tech in Rules.era_techs(1):  # a later era's techs keep nothing back until that era begins
		if Rules.tech_enabled(tech):
			keep += Data.TECHS[tech]["cost"].get("flour", 0)
	s.economy.inv["flour"] = keep
	s.economy.food_credit = 0.0
	check(keep > 0 and s.economy.flour_reserve() == keep, "flour that research needs is reserved")
	check(not s.economy.eat(1.0), "reserved flour is not eaten")
	check(s.economy.inv["flour"] == keep, "flour untouched")
	s.economy.inv["flour"] = keep + 1
	check(s.economy.eat(1.0), "flour above the reserve is eaten")
	check(s.economy.inv["flour"] == keep, "only the spare flour was eaten")
	for tech in Data.TECHS:
		s.tech_tree.researched[tech] = true
	check(s.economy.flour_reserve() == 0, "no reserve once researched")


func test_goals_advance_in_order() -> void:
	var s := fresh()
	check(s.story.current_goal() == 0, "first goal is learning Wood by hand")
	for i in Data.LEARN_CLICKS:
		s.gather_by_hand(find_tile(s, "tree"))
	s.tick(0.1)
	check(s.story.current_goal() == 1, "Wood learned, next the Berry Bushes: the Kith eat")
	for i in Data.LEARN_CLICKS:
		s.gather_by_hand(find_tile(s, "berry"))
	s.tick(0.1)
	check(s.story.current_goal() == 2, "Berries learned, next Stone and Flint")
	for tile in ["rock", "gravel"]:
		for i in Data.LEARN_CLICKS:
			s.gather_by_hand(find_tile(s, tile))
	s.tick(0.1)
	check(s.story.current_goal() == 3, "then find the flax")
	s.gather_by_hand(find_tile(s, "flax"))
	s.tick(0.1)
	check(s.story.current_goal() == 4, "then Knapping")
	s.economy.inv["flint"] = 5
	s.economy.inv["stone"] = 10
	s.research("knapping")
	s.tick(0.1)
	check(s.story.current_goal() == 5, "knapping done, next is flint tools")
	check(s.story.goals_done.has("learn_wood"), "earlier goals stay done")
	var ids: Array = Data.GOALS.map(func(g): return g["id"])
	check(
		ids.find("trip") > ids.find("hut") and ids.find("trip") < ids.find("haulers"),
		"a trip comes between hut and Haulers"
	)
	check(ids.find("rush") > ids.find("haulers"), "and rushing after Haulers")


func test_hut_gather_preview_matches_placement() -> void:
	var s := fresh()
	give(s, 100)
	s.tech_tree.researched["gatherers_hut"] = true
	var p := s.world.camp_pos + Vector2i(-2, 0)
	var preview := s.town.gather_tiles(p)
	check(preview.size() > 0, "preview finds the forest next to camp")
	s.place("gatherers_hut", p)
	var b: Dictionary = s.town.buildings[s.town.building_at[p]]
	check(b["gather_items"].size() == preview.size(), "hut works exactly the previewed tiles")


func test_shortfall_text() -> void:
	var s := fresh()
	s.economy.inv["stone"] = 4
	s.economy.inv["clay"] = 0
	check(
		Ui.shortfall_text(s.economy.inv, {"stone": 10, "clay": 10}) == "need 6 Stone, 10 Clay",
		"shortfall lists what's missing"
	)
	s.economy.inv["stone"] = 10
	s.economy.inv["clay"] = 10
	check(Ui.shortfall_text(s.economy.inv, {"stone": 10, "clay": 10}) == "", "no shortfall when affordable")


## Food coming in steadily: a full window of berries from a hut, more than any camp of ours eats.
func steady_income(s: Sim) -> void:
	s.economy.flows.hist = []
	for _n in Data.RATE_WINDOW:
		s.economy.flows.hist.append({"berries|gatherers_hut": 1.0})
	s.economy.steady_held = Data.STEADY_SECONDS


func place_free(s: Sim, type: String, p: Vector2i) -> bool:
	s.economy.add("wood", 100)
	s.economy.add("stone", 100)
	s.economy.add("fiber", 100)
	s.economy.add("grain", 100)
	s.economy.add("rope", 100)
	s.tech_tree.researched[Data.BUILDINGS[type]["tech"]] = true
	return s.place(type, p)


func test_kith_staff_buildings_in_order() -> void:
	var s := fresh()
	s.economy.inv["berries"] = 100
	check(s.people.kith.size() == Data.KITH_START, "start with the starting Kith")
	for i in 4:
		place_free(s, "gatherers_hut", s.world.camp_pos + Vector2i(-2, i - 2))
	s.tick(0.1)
	var staffed := 0
	for b in s.town.buildings:
		if b["worker"] >= 0:
			staffed += 1
	check(staffed == Data.KITH_START, "one worker per building, as many as there are Kith")
	var last: Dictionary = s.town.buildings[s.town.buildings.size() - 1]
	check(
		last["worker"] == -1 and last["status"].begins_with("No Woodcutter yet"),
		"the newest building waits for a worker"
	)


func test_population_grows_with_food_and_room() -> void:
	var s := fresh()
	s.economy.inv["berries"] = 200
	for i in int(Data.GROW_TIME * 2 + 2):
		steady_income(s)
		s.tick(1.0)
	check(s.people.kith.size() == s.town.housing(), "grows until the Camp is full")
	check(Ui.growth_note(s).begins_with("No room"), "says it needs room")
	place_free(s, "dwelling", s.world.camp_pos + Vector2i(0, 2))
	for i in int(Data.GROW_TIME + 2):
		steady_income(s)
		s.tick(1.0)
	check(s.people.kith.size() == s.town.housing() - 2, "a Dwelling makes room for more")


func test_starving_kith_leave() -> void:
	var s := fresh()
	s.economy.inv["berries"] = 0
	s.economy.food_credit = 0.0
	for i in int(Data.STARVE_TIME + 1):
		s.tick(1.0)
	check(s.people.kith.size() == Data.KITH_START - 1, "a Kith leaves after starving")


## Two identical charcoal pits, one next to the Camp and one far away: the near one delivers more.
func haul_rate(dist_x: int) -> int:
	var s := Sim.new()
	s.world.tiles.resize(World.WIDTH * World.HEIGHT)
	s.world.tiles.fill("grass")
	s.world.camp_pos = Vector2i(1, 10)
	s.town.add_building("camp", s.world.camp_pos)
	s.pathing.build()
	s.fog.setup(World.WIDTH, World.HEIGHT)
	s.fog.reveal_all()
	for i in Data.KITH_START:
		s.people.add_kith()
	s.economy.inv["berries"] = 500
	s.economy.inv["wood"] = 500
	s.tech_tree.researched["haulers"] = true
	place_free(s, "charcoal_pit", s.world.camp_pos + Vector2i(dist_x, 0))
	road_link(s, s.world.camp_pos + Vector2i(dist_x, 0))
	s.economy.inv["charcoal"] = 0
	for i in 600:
		s.tick(0.25)
	return s.economy.inv["charcoal"]


func test_distance_slows_haulers() -> void:
	var near := haul_rate(2)
	var far := haul_rate(30)
	check(near > 0 and far > 0, "both pits deliver charcoal (near %d, far %d)" % [near, far])
	check(near > far, "distance matters: near pit delivers more (near %d, far %d)" % [near, far])


## A Wooden Bridge (Paths & Haulers) spans the river at road speed.
func test_roads_bridge_the_river() -> void:
	var s := fresh()
	var cross := _find_crossing(s)
	var river: Vector2i = cross["river"]
	var side: Vector2i = cross["side"]
	var bank := river - side
	var far_bank := river + side * 2
	check(s.pathing.walk_cost(bank) >= 1.0, "no road: normal speed")
	check(s.pathing.astar.is_point_solid(river), "the river blocks walking")
	check(Data.BUILDINGS["bridge"]["tech"] == "haulers", "bridges come with Paths & Haulers")
	s.tech_tree.researched["haulers"] = true
	s.economy.inv["wood"] = 100
	s.economy.inv["rope"] = 10
	check(s.town.placement_error("bridge", bank) == "Bridges go on river tiles", "bridges only go on the river")
	var wood: int = s.economy.inv["wood"] + 100
	check(place_free(s, "bridge", river), "a bridge goes on the river")
	check(s.economy.inv["wood"] == wood - 10, "a bridge costs 10 Wood")
	check(place_free(s, "bridge", river + side), "both river tiles")
	check(not s.pathing.astar.is_point_solid(river), "bridged river is walkable")
	check(s.pathing.walk_cost(river) < 1.0, "bridges are road speed")
	var path := s.pathing.astar.get_id_path(bank, far_bank)
	check(river in path, "the path uses the bridge")
	check(s.town.built_type(river) == "bridge", "it counts as a bridge")


## Every parent sits left of its child, no two cards overlap, and most techs join two branches.
func test_tech_tree_is_a_web() -> void:
	var stone := Rules.era_techs(1)
	check(stone.size() == 29, "the stone age has 29 techs")
	check(Data.TECH_ORDER.size() == Data.TECHS.size(), "TECH_ORDER lists every tech once")
	var roots := 0
	var multi := 0
	for tech in stone:
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
	for tech in stone:
		colors[Data.TECHS[tech]["color"].to_html()] = true
	check(colors.size() == stone.size(), "every stone-age tech has its own color")
	for tech in Data.TECHS:
		check("star_lore" not in Data.TECHS[tech]["requires"], tech + " doesn't strictly need hidden Star Lore")


## Tech tree v4 (mockups/tech-tree-v4.md): each link reads "you need X to invent Y".
func test_tech_tree_v4() -> void:
	check(TechLayout.links(1).size() == 51, "v4 plus the Storehouse has 51 links (%d)" % TechLayout.links(1).size())
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
	check(route.size() == 19, "Bronze Dawn needs 19 techs (%d)" % route.size())
	for tech in Rules.era_techs(1):
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
	var r := s.town.hut_radius()
	s.tech_tree.researched["scouting"] = true
	check(s.town.hut_radius() == r + 1, "scouting widens hut reach")
	var berry := find_tile(s, "berry")
	s.economy.inv["berries"] = 0
	s.tech_tree.researched["foraging"] = true
	s.gather_by_hand(berry)
	check(s.economy.inv["berries"] == 2, "foraging doubles berries")
	check(Haulers.carry_cap(s) == Data.CARRY, "normal carry")
	s.tech_tree.researched["carrying_poles"] = true
	check(Haulers.carry_cap(s) == Data.CARRY * 2, "carrying poles double carry")
	s.tech_tree.researched["baking"] = true
	check(s.economy.food_value("flour") == 5.0, "baking makes flour worth 5")
	var h := s.town.housing()
	place_free(s, "dwelling", s.world.camp_pos + Vector2i(0, 2))
	s.tech_tree.researched["shelter"] = true
	check(s.town.housing() == h + 5, "thatched dwellings house 5")
	var road := s.world.camp_pos + Vector2i(1, 1)
	place_free(s, "road", road)
	var slow := s.pathing.walk_cost(road)
	s.research("paved_roads")
	s.tech_tree.researched["paved_roads"] = true
	s.pathing.update_cell(road)
	check(s.pathing.walk_cost(road) < slow, "paved roads are faster")
	var grass := find_grass(s, false)
	check(place_free(s, "field", grass), "sow a field")
	check(s.world.tile_at(grass) == "grain", "field grows grain")


## Megaliths needs Masonry and one of Storytelling or Star Lore; either one alone is enough.
func test_requires_any() -> void:
	var s := fresh()
	give(s, 999)
	for t in ["knapping", "fire", "masonry"]:
		check(s.research(t), "research " + t)
	check(not s.tech_tree.requirements_met("megaliths"), "Megaliths needs Storytelling or Star Lore too")
	check(s.tech_tree.missing_requirements("megaliths") == 1, "an either-or counts as one missing tech")
	check(s.research("storytelling"), "research Storytelling")
	check(s.tech_tree.can_research("megaliths"), "Storytelling alone unlocks Megaliths")
	var s2 := fresh()
	give(s2, 999)
	s2.gather_by_hand(s2.world.shard_pos)
	for t in ["knapping", "fire", "masonry", "star_lore"]:
		s2.tech_tree.researched[t] = true
	check(not s2.tech_tree.researched.has("storytelling"), "no Storytelling in the second camp")
	check(s2.tech_tree.can_research("megaliths"), "Star Lore alone unlocks Megaliths")
	check(s2.research("megaliths"), "research Megaliths through Star Lore")


func test_star_lore_is_hidden_until_the_shard_is_clicked() -> void:
	var s := fresh()
	give(s, 999)
	check(s.research("storytelling"), "research Storytelling")
	check(not s.tech_tree.tech_visible("star_lore"), "Star Lore is hidden at first")
	check(not s.tech_tree.can_research("star_lore"), "hidden Star Lore can't be researched")
	check(s.tech_tree.tech_visible("megaliths"), "other techs are visible")
	s.gather_by_hand(s.world.shard_pos)
	check(s.tech_tree.tech_visible("star_lore"), "clicking the Strange Stone reveals Star Lore")
	check(s.research("star_lore"), "then it can be researched")
	check(s.town.unlocked("shard_cairn"), "Star Lore unlocks the Shard Cairn")


func test_shard_cairn() -> void:
	var s := fresh()
	give(s, 100)
	s.shard_seen = true
	s.tech_tree.researched["star_lore"] = true
	check(
		s.town.placement_error("shard_cairn", s.world.camp_pos + Vector2i(0, 2)) == "Must go next to the Strange Stone",
		"cairn needs the shard"
	)
	for n in World.NEIGHBORS:
		var p: Vector2i = s.world.shard_pos + n
		if s.world.tile_at(p) == "grass" and not s.town.building_at.has(p):
			check(s.place("shard_cairn", p), "cairn goes beside the shard")
			s.tick(0.1)
			check(
				s.town.buildings[s.town.building_at[p]]["status"] == "It hums. Nothing more. Yet.",
				"the cairn only hums"
			)
			return


func test_smoking_makes_berries_worth_more() -> void:
	var s := fresh()
	s.economy.inv["berries"] = 10
	s.economy.inv["flour"] = 0
	check(s.economy.food_value("berries") == 1.0, "berries are worth 1")
	var before := s.economy.food_total()
	s.tech_tree.researched["smoking"] = true
	check(s.economy.food_value("berries") == 2.0, "smoked berries are worth 2")
	check(s.economy.food_total() == before * 2.0, "smoking doubles berry food")


func test_rafts_cross_the_river() -> void:
	var s := fresh()
	give(s, 999)
	var river := find_tile(s, "river")
	check(s.pathing.astar.is_point_solid(river), "the river blocks walking")
	for t in ["cordage", "foraging", "knapping", "nets"]:
		s.tech_tree.researched[t] = true
	check(not s.tech_tree.can_research("rafts"), "Rafts need logs: Stone Axe first")
	s.tech_tree.researched["stone_axe"] = true
	check(s.research("rafts"), "research Rafts")
	check(not s.pathing.astar.is_point_solid(river), "Rafts make the river walkable")
	check(s.pathing.walk_cost(river) == Data.WALK_COST["river"], "rafting is slow")
	check(s.pathing.walk_cost(river) > 1.0, "slower than open ground")
	var path := s.pathing.astar.get_id_path(river + Vector2i(-1, 0), river + Vector2i(2, 0))
	check(not path.is_empty(), "Kith can cross without a bridge")
	place_free(s, "bridge", river)
	check(s.pathing.walk_cost(river) < 1.0, "a bridge is still road speed")


func test_calendar_gates_bronze_dawn() -> void:
	var s := fresh()
	give(s, 999)
	check("calendar" in Data.TECHS["bronze_dawn"]["requires"], "Bronze Dawn requires Calendar")
	for t in Data.TECHS["bronze_dawn"]["requires"]:
		if t != "calendar":
			s.tech_tree.researched[t] = true
	check(not s.tech_tree.can_research("bronze_dawn"), "no Bronze Dawn without Calendar")
	s.tech_tree.researched["farming"] = true
	s.tech_tree.researched["storytelling"] = true
	check(s.research("calendar"), "Calendar through Farming and Storytelling")
	check(s.research("bronze_dawn"), "then Bronze Dawn")
	var ids: Array = Data.GOALS.map(func(g): return g["id"])
	check(ids.find("calendar") == ids.find("bronze") - 1, "the Calendar goal comes right before Bronze Dawn")


func test_lore_and_side_branch_effects() -> void:
	var s := fresh()
	check(s.people.grow_time() == Data.GROW_TIME, "normal grow time")
	s.tech_tree.researched["storytelling"] = true
	check(s.people.grow_time() == Data.GROW_TIME * 0.75, "Storytelling: Kith born 25% faster")

	var p := s.world.camp_pos + Vector2i(-2, 0)
	place_free(s, "gatherers_hut", p)
	var hut: Dictionary = s.town.buildings[s.town.building_at[p]]
	var base := Work.time(s, hut)
	var clay := find_tile(s, "clay")
	check(Work.harvest_amount(s, hut, clay, "clay") == Data.BUNDLE, "a bundle of clay per harvest")
	s.tech_tree.researched["ochre"] = true
	check(Work.harvest_amount(s, hut, clay, "clay") == Data.BUNDLE * 2, "Ochre: huts bring back twice the Clay")
	check(is_equal_approx(Bonuses.speed(s, hut), 1.0), "Ochre doesn't touch speed")
	check(place_free(s, "standing_stone", p + Vector2i(0, 2)), "place a Standing Stone 2 tiles off")
	check(is_equal_approx(Bonuses.speed(s, hut), 1.0), "2 tiles off is too far for a Standing Stone")
	check(place_free(s, "standing_stone", p + Vector2i(1, 1)), "place a Standing Stone right next to the hut")
	check(is_equal_approx(Bonuses.speed(s, hut), 2.0), "Standing Stone: twice as fast next to it")
	check(is_equal_approx(Work.time(s, hut), base / 2.0), "and the cycle takes half as long")

	var tree := find_tile(s, "tree")
	check(Work.harvest_amount(s, hut, tree, "wood") == Data.BUNDLE, "a bundle of wood per harvest")
	s.tech_tree.researched["stone_axe"] = true
	check(
		Work.harvest_amount(s, hut, tree, "wood") == Data.BUNDLE * 3, "Stone Axe: huts bring back three times the Wood"
	)

	var field := find_grass(s, true)
	check(place_free(s, "field", field), "sow a field by the river")
	var total := 0
	for i in 4:
		total += Work.harvest_amount(s, hut, field, "grain")
	check(total == 4 * Data.BUNDLE, "four harvests of a Field give four bundles")
	s.tech_tree.researched["calendar"] = true
	total = 0
	for i in 4:
		total += Work.harvest_amount(s, hut, field, "grain")
	check(total == 5 * Data.BUNDLE, "Calendar: Fields yield 25% more")

	var dry := find_grass(s, false)
	place_free(s, "field", dry)
	var t := Work.harvest_time(s, hut, field)
	s.tech_tree.researched["irrigation"] = true
	check(is_equal_approx(Work.harvest_time(s, hut, field), t / 2.0), "Irrigation: river Fields grow twice as fast")
	check(is_equal_approx(Work.harvest_time(s, hut, dry), t), "dry Fields are unchanged")


func test_fishing_weir_makes_fish() -> void:
	var s := fresh()
	s.economy.inv["berries"] = 100
	var bank := Vector2i(-1, -1)
	for y in World.HEIGHT:
		for x in World.WIDTH:
			var p := Vector2i(x, y)
			if bank.x < 0 and s.world.tile_at(p) == "grass" and s.world.tile_at(p + Vector2i(1, 0)) == "river":
				bank = p
	check(
		s.town.placement_error("fishing_weir", s.world.camp_pos + Vector2i(0, 2)) != "", "weir needs Nets and the river"
	)
	s.economy.add("rope", 10)
	check(place_free(s, "fishing_weir", bank), "place a weir on the near bank")
	for i in 200:
		s.tick(0.5)
	var b: Dictionary = s.town.buildings[s.town.building_at[bank]]
	check(b["out"].get("fish", 0) > 0, "the weir traps fish")
	check(s.economy.food_value("fish") == 2.0, "fish are worth 2 food")
