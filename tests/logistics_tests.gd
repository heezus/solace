extends RefCounted
## PR 1 of the growth batch (design-system/17-needs-and-upgrades.md): buildings stay off the build bar until the tech
## tree has revealed them, the Jobs line counts places and not buildings, road and bridge tiers, copy cost, the hand
## cart and fog scouting. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const CardText = preload("res://scripts/card_text.gd")
const Ui = preload("res://scripts/ui.gd")
const Rules = preload("res://scripts/rules.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Overlays = preload("res://scripts/overlays.gd")
const HoverText = preload("res://scripts/hover_text.gd")
const BuildBar = preload("res://scripts/build_bar.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Roads = preload("res://scripts/roads.gd")
const Scouting = preload("res://scripts/scouting.gd")
const Kith = preload("res://scripts/kith.gd")
const RoadLayer = preload("res://scripts/road_layer.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_cards_wait_for_the_tech_tree_to_reveal_them()
	test_jobs_filled_never_passes_jobs()
	test_road_tiers_have_their_own_speed_and_price()
	test_dragging_a_higher_tier_over_a_road_upgrades_it_for_the_difference()
	test_the_stone_bridge_upgrades_a_wooden_one_in_place()
	test_tiers_save_and_old_saves_keep_their_pace()
	test_gravel_and_paved_lie_over_the_path_as_tile_nodes()
	test_the_bar_and_the_hover_show_the_real_cost_of_a_tier()
	test_each_copy_of_a_production_building_costs_more()
	test_flat_buildings_never_cost_more()
	test_the_bar_and_hover_show_the_current_copy_price()
	test_a_hand_cart_is_one_kith_carrying_triple()
	test_clicking_fog_sends_the_nearest_idle_kith_to_look()
	test_a_scout_needs_no_road_and_comes_home_a_hauler_again()
	test_a_scout_has_edge_cases_and_survives_a_save()


# --- Hidden until learned ------------------------------------------------------


func test_cards_wait_for_the_tech_tree_to_reveal_them() -> void:
	var s: Sim = t.fresh()
	t.check(CardText.shown(s, "dwelling") and CardText.shown(s, "camp"), "buildings with no tech always show")
	for type in ["cart_shed", "trading_post", "storehouse", "kiln", "road", "water_wheel", "mine"]:
		t.check(not CardText.shown(s, type), "%s stays off the bar before the tree reveals it" % type)
	t.check(not CardText.shown(s, "road"), "the Road waits for Paths & Haulers to show up on the board")
	t.check(not s.tech_tree.tech_visible("haulers"), "(it is not in view at the start)")
	for id in Data.ITEM_ORDER:  # everything has been found: only the research decides what shows
		s.economy.seen[id] = true
	t.check(s.tech_tree.tech_visible("haulers"), "Paths & Haulers is in view once its items were found")
	t.check(CardText.shown(s, "road"), "so the Road card shows, locked")
	t.check(not CardText.shown(s, "cart_shed"), "the Cart Shed still hides: The Wheel needs its own parents in view")
	s.tech_tree.researched["the_wheel"] = true
	t.check(CardText.shown(s, "cart_shed"), "a learned tech always shows its card")


# --- The Jobs line -------------------------------------------------------------


func test_jobs_filled_never_passes_jobs() -> void:
	var s: Sim = t.fresh()
	var camp: Vector2i = s.world.camp_pos
	t.check(Ui.job_slots(s) == 0 and Ui.jobs_filled(s) == 0, "no buildings, no jobs")
	s.town.add_building("mine", camp + Vector2i(3, 0))  # a Mine needs two people
	s.town.add_building("gatherers_hut", camp + Vector2i(3, 2))
	t.check(Ui.job_slots(s) == 3, "a Mine is two jobs and a hut one: 3, not 2 buildings (%d)" % Ui.job_slots(s))
	while s.people.kith.size() < 6:
		s.people.add_kith()
	var mine: Dictionary = s.town.buildings[1]
	var hut: Dictionary = s.town.buildings[2]
	for i in 3:
		s.people.kith[i]["job"] = "work"
	mine["worker"] = 0
	mine["mate"] = 1
	hut["worker"] = 2
	t.check(Ui.jobs_filled(s) == 3, "three Kith hold the three places")
	s.people.kith[3]["job"] = "haul"
	s.people.kith[4]["job"] = "scout"
	t.check(Ui.jobs_filled(s) == 3, "a hauler or a scout holds no place")
	s.people.kith[5]["job"] = "work"  # at work by the Kith list, but no building holds them
	t.check(Ui.jobs_filled(s) == 3, "a Kith no building holds is not counted: never 4 of 3")
	t.check(Ui.idle_kith(s) == 2, "the rest are the other two, with the scout counted apart")
	s.set_paused(2, true)
	t.check(Ui.job_slots(s) == 2 and Ui.jobs_filled(s) == 2, "a paused building is not a job and its worker is off it")
	t.check(Ui.jobs_filled(s) <= Ui.job_slots(s), "filled never passes jobs")


# --- Road and bridge tiers -------------------------------------------------------


## A game with Paths & Haulers, Paved Roads and Causeways known and every good in the stockpile.
func _roads_game() -> Sim:
	var s: Sim = t.fresh()
	for tech in ["haulers", "paved_roads", "causeways"]:
		s.tech_tree.researched[tech] = true
	t.give(s, 50)
	return s


func _grass_row(s: Sim, n: int) -> Array:
	var from: Vector2i = t.find_grass(s, false)
	var row: Array = []
	var p := from
	while row.size() < n and s.world.in_bounds(p):
		if s.world.tile_at(p) == "grass" and not s.town.building_at.has(p) and not s.world.roads.has(p):
			row.append(p)
		p += Vector2i(1, 0)
	return row


func test_road_tiers_have_their_own_speed_and_price() -> void:
	var s := _roads_game()
	var row := _grass_row(s, 3)
	t.check(row.size() == 3, "a row of grass to build on")
	t.check(
		s.place("road", row[0]) and s.place("gravel_road", row[1]) and s.place("paved_road", row[2]), "all three tiers"
	)
	t.check(
		s.world.road_tier(row[0]) == 0 and s.world.road_tier(row[1]) == 1 and s.world.road_tier(row[2]) == 2,
		"tiers 0, 1, 2"
	)
	t.check(not s.world.road_tiers.has(row[0]), "a path keeps no tier entry: it is the default")
	var base: float = Data.WALK_COST["road"]
	t.check(is_equal_approx(s.pathing.walk_cost(row[0]), base), "a path walks at the road pace")
	t.check(is_equal_approx(s.pathing.walk_cost(row[1]), base / 1.25), "gravel 1.25 times as fast")
	t.check(is_equal_approx(s.pathing.walk_cost(row[2]), base / 1.5), "paved 1.5 times as fast")
	t.check(Data.ROAD_SPEEDS == [1.0, 1.25, 1.5], "the speeds the page proposes")
	t.check(
		(
			[s.town.built_type(row[0]), s.town.built_type(row[1]), s.town.built_type(row[2])]
			== ["road", "gravel_road", "paved_road"]
		),
		"each tile says which tier it is"
	)
	var g := _roads_game()
	g.tech_tree.researched.erase("paved_roads")
	var spot: Vector2i = _grass_row(g, 1)[0]
	t.check(g.town.placement_error("paved_road", spot) == "Not discovered yet", "Paved Roads needs its tech")
	t.check(g.town.placement_error("gravel_road", spot) == "", "Gravel needs only Paths & Haulers")
	t.check(Data.BUILDINGS["paved_road"]["tech"] == "paved_roads", "and the tier's tech is Paved Roads")
	# Causeways no longer turns every road stone: a road is wood in any era.
	t.check(Rules.cost_at("road", "grass") == {"wood": 2}, "a plain road costs 2 Wood")
	var inv_before: int = s.economy.inv["stone"]
	var next: Vector2i = _grass_row(s, 6)[5]
	s.place("road", next)
	t.check(s.economy.inv["stone"] == inv_before, "even with Causeways known")
	# A pass through Rocks costs its Stone, plus what the tier adds over a path.
	t.check(Rules.cost_at("road", "rock") == Data.PASS_COST, "a path through Rocks is the pass cost")
	var gravel_pass := Rules.cost_at("gravel_road", "rock")
	t.check(gravel_pass == {"stone": 3, "flint": 2}, "a gravel road through Rocks adds its Flint: %s" % [gravel_pass])


func test_dragging_a_higher_tier_over_a_road_upgrades_it_for_the_difference() -> void:
	var s := _roads_game()
	var row := _grass_row(s, 5)
	s.place_line("road", row)
	var gravel_cost: Dictionary = Data.BUILDINGS["gravel_road"]["cost"]
	var diff := Rules.cost_at("gravel_road", "grass", "road")
	t.check(diff == {"flint": 2}, "path to gravel owes only the Flint: %s" % [diff])
	t.check(s.town.cost_here("gravel_road", row[0]) == diff, "the same price the build bar's hover quotes")
	var flint: int = s.economy.inv["flint"]
	var wood: int = s.economy.inv["wood"]
	t.check(s.town.placement_error("gravel_road", row[0]) == "", "a gravel road may go over a path")
	t.check(s.place_line("gravel_road", row) == 5, "a drag over five path tiles upgrades all five")
	t.check(s.economy.inv["flint"] == flint - 10 and s.economy.inv["wood"] == wood, "paying 2 Flint each and no Wood")
	t.check(s.world.road_tier(row[4]) == 1 and s.world.roads.size() == 5, "in place: the same five tiles, now gravel")
	t.check(
		Overlays.line_text(s, "paved_road", row).contains("5 tiles"), "the drag's pill counts the tiles it will upgrade"
	)
	var again := Overlays.line_text(s, "gravel_road", row)
	t.check(again.contains("nowhere to lay"), "a second drag of gravel has nothing to do: %s" % again)
	t.check(s.town.placement_error("gravel_road", row[0]).begins_with("Already"), "it says it is done")
	t.check(s.town.placement_error("road", row[0]) == "A better road is already here", "a path never replaces gravel")
	var paved_diff := Rules.cost_at("paved_road", "grass", "gravel_road")
	t.check(
		paved_diff == {"stone": 2, "brick": 1},
		"gravel to paved owes Stone and Brick, not the Wood again: %s" % [paved_diff]
	)
	t.check(s.place("paved_road", row[0]) and s.world.road_tier(row[0]) == 2, "gravel goes on to paved")
	var fresh_paved := Rules.cost_at("paved_road", "grass")
	t.check(fresh_paved == Data.BUILDINGS["paved_road"]["cost"], "a paved road on bare grass costs the whole tier")
	t.check(
		Rules.cost_at("paved_road", "grass", "road") == Rules.difference(fresh_paved, {"wood": 2}),
		"from a path: the difference"
	)
	t.check(
		gravel_cost["wood"] == Data.BUILDINGS["road"]["cost"]["wood"],
		"every tier's Wood is the path's, so Wood is never owed twice"
	)
	# Not enough of the difference: refused with the usual words, and nothing is paid.
	s.economy.inv["flint"] = 1
	var other: Vector2i = _grass_row(s, 9)[8]
	s.place("road", other)
	var before := s.economy.inv.duplicate()
	t.check(s.town.placement_error("gravel_road", other) == "Not enough materials", "short of Flint")
	t.check(not s.place("gravel_road", other) and s.economy.inv == before, "so nothing is laid or paid")
	# Demolishing refunds half of the tier's own price.
	s.demolish(row[1])
	t.check(
		not s.world.roads.has(row[1]) and not s.world.road_tiers.has(row[1]), "a demolished gravel tile is bare ground"
	)
	t.check(Rules.refund_of("gravel_road") == {"wood": 1, "flint": 1}, "and refunds half the gravel price")


func test_the_stone_bridge_upgrades_a_wooden_one_in_place() -> void:
	var s := _roads_game()
	var cross: Dictionary = t._find_crossing(s)
	var river: Vector2i = cross["river"]
	t.check(s.place("bridge", river), "a Wooden Bridge")
	t.check(s.town.built_type(river) == "bridge" and s.world.is_wooden_bridge(river), "wooden to begin with")
	t.check(
		Rules.cost_at("stone_bridge", "river", "bridge") == {"stone": 6, "brick": 4},
		"the stone price is all that is owed"
	)
	var stock := s.economy.inv.duplicate()
	t.check(s.town.placement_error("stone_bridge", river) == "", "the Stone Bridge goes over the Wooden Bridge")
	t.check(s.place("stone_bridge", river), "and does it in place, with no demolishing")
	t.check(
		s.economy.inv["stone"] == stock["stone"] - 6 and s.economy.inv["brick"] == stock["brick"] - 4,
		"paying Stone and Brick"
	)
	t.check(
		s.economy.inv["wood"] == stock["wood"] and s.economy.inv["rope"] == stock["rope"],
		"and no refund or second charge in Wood and Rope"
	)
	t.check(s.world.stone_bridges.has(river) and s.world.road_tier(river) == 2, "it is stone now, at the top tier")
	t.check(is_equal_approx(s.pathing.walk_cost(river), Data.WALK_COST["road"] / 1.5), "walking at the paved pace")
	t.check(s.town.placement_error("stone_bridge", river) == "Already a Stone Bridge", "once")
	t.check(s.town.placement_error("bridge", river) == "Already a Stone Bridge", "and wood never goes back over stone")
	var wood_bridge := _roads_game()
	var spot: Vector2i = t._find_crossing(wood_bridge)["river"]
	wood_bridge.place("bridge", spot)
	t.check(
		wood_bridge.town.placement_error("bridge", spot) == "Already a bridge",
		"a Wooden Bridge over a Wooden Bridge is refused"
	)
	t.check(wood_bridge.town.placement_error("road", spot) != "", "and a road can't go over the river")


## Each revealed gravel or paved land tile gets one node carrying its tier and which sides join; a path, a bridge and
## fogged ground get none, and a tile that goes back to a path or is torn up loses its node.
func test_gravel_and_paved_lie_over_the_path_as_tile_nodes() -> void:
	var s: Sim = t.fresh()
	s.fog.reveal_all()
	var c: Vector2i = s.world.camp_pos + Vector2i(0, 3)
	for i in 4:
		s.world.roads[c + Vector2i(i, 0)] = true
	s.world.set_road_tier(c + Vector2i(1, 0), 1)
	s.world.set_road_tier(c + Vector2i(2, 0), 2)
	var host := Node2D.new()
	var layer := RoadLayer.new()
	layer.sync(host, s)
	var holder: Node = host.get_child(0)
	t.check(
		holder.get_child_count() == 2, "one node each for the gravel and paved tiles (%d)" % holder.get_child_count()
	)
	var gravel: ShaderMaterial = layer._tiles[c + Vector2i(1, 0)].material
	t.check(gravel.get_shader_parameter("tier") == 1.0, "the gravel tile carries its tier")
	t.check(gravel.get_shader_parameter("connections") == Vector4(1, 1, 0, 0), "and joins the roads either side of it")
	t.check(not layer._tiles.has(c), "a plain path gets none: the terrain draws it")
	s.world.set_road_tier(c + Vector2i(1, 0), 2)
	s.town.road_rev += 1
	layer.sync(host, s)
	t.check(gravel.get_shader_parameter("tier") == 2.0, "a tier change updates the same node")
	s.world.set_road_tier(c + Vector2i(1, 0), 0)
	s.world.roads.erase(c + Vector2i(2, 0))
	s.world.road_tiers.erase(c + Vector2i(2, 0))
	s.town.road_rev += 1
	layer.sync(host, s)
	t.check(layer._tiles.is_empty(), "a tile back to a path, or torn up, loses its node")
	host.free()


func test_tiers_save_and_old_saves_keep_their_pace() -> void:
	var s := _roads_game()
	var row := _grass_row(s, 3)
	s.place("road", row[0])
	s.place("gravel_road", row[1])
	s.place("paved_road", row[2])
	var d := RunSave.from_json(RunSave.to_json(RunSave.dump(s)))
	var copy := Sim.new()
	t.check(RunSave.restore(copy, d), "a saved game restores")
	t.check(
		copy.world.road_tier(row[0]) == 0 and copy.world.road_tier(row[1]) == 1 and copy.world.road_tier(row[2]) == 2,
		"every tier comes back"
	)
	t.check(is_equal_approx(copy.pathing.walk_cost(row[2]), s.pathing.walk_cost(row[2])), "with the same pace")
	# A save from before tiers has no road_tiers. With Paved Roads known its roads were quick: they stay paved.
	var old: Dictionary = RunSave.from_json(RunSave.to_json(RunSave.dump(s)))
	old["world"].erase("road_tiers")
	var lifted := Sim.new()
	t.check(RunSave.restore(lifted, old), "an old save restores")
	t.check(
		lifted.world.road_tier(row[0]) == 2 and lifted.world.road_tier(row[1]) == 2,
		"its roads are paved, as the tech made them"
	)
	var plain: Dictionary = RunSave.from_json(RunSave.to_json(RunSave.dump(s)))
	plain["world"].erase("road_tiers")
	plain["research"]["researched"] = []
	var path_only := Sim.new()
	t.check(RunSave.restore(path_only, plain), "an old save without the tech restores")
	t.check(path_only.world.road_tier(row[2]) == 0, "and its roads are plain paths")


func test_the_bar_and_the_hover_show_the_real_cost_of_a_tier() -> void:
	var s := _roads_game()
	var row := _grass_row(s, 2)
	for type in ["road", "gravel_road", "paved_road"]:
		t.check(CardText.shown(s, type) and s.town.unlocked(type), "%s has its own card on the bar" % type)
		t.check(Data.BUILD_TABS["Logistics"].has(type), "in the Logistics tab")
	var hover_over_path: String = Overlays.line_text(s, "paved_road", row)
	t.check(hover_over_path.contains("Stone"), "a drag of paved quotes Stone")
	s.place("road", row[0])
	var upgrade_text: String = Overlays.line_text(s, "paved_road", [row[0]])
	t.check(
		upgrade_text.contains("2 Stone") and upgrade_text.contains("1 Brick") and not upgrade_text.contains("Wood"),
		"over a path the quote is the difference: %s" % upgrade_text
	)
	t.check(HoverText.road_name(s, row[0]) == "Road", "the hover names a path")
	s.place("paved_road", row[0])
	t.check(HoverText.road_name(s, row[0]) == "Paved Road", "and a paved tile")


# --- Copy cost -----------------------------------------------------------------


func test_each_copy_of_a_production_building_costs_more() -> void:
	var base: Dictionary = Data.BUILDINGS["kiln"]["cost"]
	t.check(
		Rules.is_production("kiln") and Rules.is_production("smelter") and Rules.is_production("water_wheel"),
		"kilns, smelters and wheels are production"
	)
	t.check(Rules.price("kiln", 0) == base, "the first copy is the listed price")
	t.check(Rules.price("kiln", 1) == {"stone": 12, "clay": 12}, "one standing: 15% more (10 becomes 12 once rounded)")
	t.check(Rules.price("kiln", 2) == {"stone": 13, "clay": 13}, "two standing: 30% more")
	t.check(Rules.price("kiln", 10) == {"stone": 25, "clay": 25}, "ten standing: 2.5 times")
	t.check(Rules.price("kiln", 20) == {"stone": 40, "clay": 40}, "twenty standing: the 4x ceiling")
	t.check(Rules.price("kiln", 60) == {"stone": 40, "clay": 40}, "and no more after it")
	t.check(is_equal_approx(Rules.copy_multiplier("kiln", 100), Data.COPY_COST_CEILING), "the ceiling is 4x")
	var s: Sim = t.fresh()
	t.give(s, 400)
	s.tech_tree.researched["pottery"] = true
	var camp: Vector2i = s.world.camp_pos
	var spots: Array = []
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var p := camp + Vector2i(dx, dy)
			if s.world.tile_at(p) == "grass" and p != camp and spots.size() < 4:
				spots.append(p)
	t.check(s.town.price("kiln") == base and s.town.copies("kiln") == 0, "no kiln stands: the listed price")
	var before: int = s.economy.inv["stone"]
	t.check(s.place("kiln", spots[0]), "the first kiln")
	t.check(s.economy.inv["stone"] == before - 10, "cost the listed 10 Stone")
	t.check(s.town.copies("kiln") == 1 and s.town.price("kiln") == {"stone": 12, "clay": 12}, "the second asks 12")
	before = s.economy.inv["stone"]
	t.check(s.place("kiln", spots[1]), "the second kiln")
	t.check(
		s.economy.inv["stone"] == before - 12 and s.economy.inv["clay"] == 400 - 10 - 12, "and charges 12, as quoted"
	)
	s.economy.inv["stone"] = 12
	s.economy.inv["clay"] = 13
	t.check(
		s.town.placement_error("kiln", spots[2]) == "Not enough materials",
		"13 Stone are asked for the third: 12 are not enough"
	)
	s.economy.inv["stone"] = 13
	t.check(s.town.placement_error("kiln", spots[2]) == "", "13 are")
	s.demolish(spots[1])
	t.check(s.town.price("kiln") == {"stone": 12, "clay": 12}, "tearing one down lowers the price again")
	t.check(Rules.refund_of("kiln") == {"stone": 5, "clay": 5}, "the refund stays half of the listed price")


func test_flat_buildings_never_cost_more() -> void:
	for type in [
		"dwelling",
		"road",
		"gravel_road",
		"paved_road",
		"bridge",
		"stone_bridge",
		"field",
		"flax_field",
		"storehouse",
		"gatherers_hut",
		"cart_shed",
		"watchtower"
	]:
		t.check(not Rules.is_production(type), "%s is not production" % type)
		t.check(
			Rules.price(type, 12) == Data.BUILDINGS[type]["cost"], "so a twelfth copy costs the listed price: %s" % type
		)
	for type in Data.BUILD_TABS["Workshops"] + Data.BUILD_TABS["Metal"]:
		t.check(Rules.is_production(type), "%s is production" % type)
	t.check(Data.COPY_COST_STEP == 0.15 and Data.COPY_COST_CEILING == 4.0, "15% a copy, 4x at most")
	var s: Sim = t.fresh()
	t.give(s, 400)
	s.tech_tree.researched["haulers"] = true
	var spot: Vector2i = s.world.camp_pos + Vector2i(-1, 2)
	for i in 4:
		s.town.add_building("dwelling", spot + Vector2i(i, 0))
	t.check(
		s.town.price("dwelling") == Data.BUILDINGS["dwelling"]["cost"],
		"four Dwellings stand and the next is still flat"
	)


func test_the_bar_and_hover_show_the_current_copy_price() -> void:
	var s: Sim = t.fresh()
	t.give(s, 400)
	s.tech_tree.researched["pottery"] = true
	var camp: Vector2i = s.world.camp_pos
	s.town.add_building("kiln", camp + Vector2i(2, 0))
	s.town.add_building("kiln", camp + Vector2i(3, 0))
	var price: Dictionary = s.town.price("kiln")
	t.check(price == {"stone": 13, "clay": 13}, "two kilns stand: 30% more")
	var bar = BuildBar.new()
	bar.setup(s)
	bar.refresh("", 0)
	var pips: HBoxContainer = bar.build_buttons["kiln"]["pips"]
	t.check(pips.get_child(0).get_child(1).text == "13", "the card's pips say 13, not the listed 10")
	var tip: String = bar.build_buttons["kiln"]["button"].tooltip_text
	t.check(tip.contains("13") and tip.contains(Data.COPY_COST_NOTE % [2, 30]), "and the tooltip says why: %s" % tip)
	s.economy.inv["stone"] = 12
	bar.refresh("", 0)
	t.check(bar.build_buttons["kiln"]["sub"].text == "Need 1 Stone", "a card is short by the real price")
	bar.free()
	var m := _fake_main(s, "kiln", camp + Vector2i(5, 3))
	var hover: String = HoverText.text(m)
	t.check(
		hover.contains(Data.COPY_COST_NOTE % [2, 30]) and hover.contains("13"),
		"the placement hover quotes it too: %s" % hover
	)


## Just enough of the main scene for HoverText: the state, the tile under the mouse and the building being placed.
func _fake_main(s: Sim, placing: String, hover: Vector2i) -> Object:
	var m := FakeMain.new()
	m.state = s
	m.placing = placing
	m.hover = hover
	return m


class FakeMain:
	extends RefCounted
	var state
	var placing := ""
	var hover := Vector2i(-1, -1)
	var pick_focus := ""
	var nudge := 0.0
	var building_panel: Object = null


# --- Hand cart -----------------------------------------------------------------


func test_a_hand_cart_is_one_kith_carrying_triple() -> void:
	t.check(
		int(Data.TECHS["the_wheel"].get("era", 1)) == 2 and Data.BUILDINGS["cart_shed"]["tech"] == "the_wheel",
		"the Cart Shed comes with The Wheel, in Bronze Dawn"
	)
	t.check(Data.CARTS_PER_SHED == 1 and Data.CART_LOAD == 3, "a shed makes one hand cart that carries 3x")
	var s: Sim = t.fresh()
	t.give(s, 400)
	for tech in ["haulers", "the_wheel"]:
		s.tech_tree.researched[tech] = true
	s.people.found(6)
	t.check(s.town.carts_allowed() == 0, "no shed, no hand cart")
	var camp: Vector2i = s.world.camp_pos
	var shed_at: Vector2i = t.find_grass(s, false)
	t.check(s.place("cart_shed", shed_at), "a Cart Shed")
	s.tick(0.1)
	var carts: Array = s.people.kith.filter(func(k): return k["cart"])
	t.check(carts.size() == 1 and s.town.carts_allowed() == 1, "it makes one hand cart: one Kith, not two")
	t.check(Haulers.carry_cap(s, carts[0]) == Data.CARRY * 3, "that carries 3x a hauler's load")
	t.check(Haulers.carry_cap(s, s.people.kith[4]) == Data.CARRY, "and the others carry 1x")
	# Roads only: with no road under it, the cart waits where it stands.
	var cart: Dictionary = carts[0]
	var off: Vector2i = camp + Vector2i(0, 6)
	t.check(not s.world.roads.has(off), "an open tile off the roads")
	cart["pos"] = Vector2(off)
	t.check(not Roads.walk(s, cart, camp), "no road, no way: a hand cart does not cross country")
	cart["cart"] = false
	t.check(s.people.walk_to(cart, camp), "while a hauler on foot would")
	t.check(
		s.town.price("cart_shed") == Data.BUILDINGS["cart_shed"]["cost"],
		"a Cart Shed is a flat price: it is not a production building"
	)


# --- Fog scouting ----------------------------------------------------------------


## A new camp with only the start of the map seen, five Kith at the Hearth and food for the walk.
func _fogged() -> Sim:
	var s := Sim.new()
	s.generate(42)
	s.people.found(5)
	s.economy.inv["berries"] = 200
	return s


## The fogged tile the Kith can walk to that is `dist` tiles from the camp or a little more (the nearest such, east first).
func _fog_tile(s: Sim, dist: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			var d := Vector2(p).distance_to(Vector2(s.world.camp_pos))
			if d < dist or s.fog.is_revealed(p) or s.pathing.astar.is_point_solid(p):
				continue
			var score := d + (0.0 if x > s.world.camp_pos.x else 0.5)
			if score < best_d and not s.pathing.path(s.world.camp_pos, p).is_empty():
				best = p
				best_d = score
	return best


func test_clicking_fog_sends_the_nearest_idle_kith_to_look() -> void:
	var s := _fogged()
	var target := _fog_tile(s, 8)
	t.check(target.x >= 0 and not s.fog.is_revealed(target), "a fogged tile to look at")
	t.check(Scouting.send(s, s.world.camp_pos) == "", "a click on a revealed tile sends nobody")
	for k in s.people.kith:
		k["pos"] = Vector2(s.world.camp_pos)
	s.people.kith[3]["pos"] = Vector2(s.world.camp_pos) + Vector2(5, 0)  # one Kith is already out that way
	var note := Scouting.send(s, target)
	t.check(note == Data.SCOUT_SENT % s.people.kith[3]["name"], "the nearest idle Kith goes: %s" % note)
	t.check(s.people.kith[3]["job"] == "scout" and Scouting.count(s) == 1, "and is a scout now")
	t.check(Data.JOB_SCOUT == "Scout" and s.people.job_of(s.people.kith[3]) == "Scout", "with the job title Scout")
	t.check(s.people.job_counts().contains("1 Scout"), "the job list names it")
	t.check(not s.people.kith[3]["path"].is_empty(), "walking")
	t.check(Ui.idle_kith(s) == 4 and Ui.jobs_filled(s) == 0, "a scout is neither idle nor at a job")
	t.check(
		not s.tech_tree.researched.has("haulers") and s.world.roads.is_empty(), "with no haulers and not one road laid"
	)


func test_a_scout_needs_no_road_and_comes_home_a_hauler_again() -> void:
	var s := _fogged()
	s.tech_tree.researched["haulers"] = true
	s.people.assign_jobs()
	t.check(
		s.people.kith.all(func(k): return k["job"] == "haul"),
		"every Kith hauls with Paths & Haulers: all are idle haulers"
	)
	var target := _fog_tile(s, 9)
	var seen_before := s.fog.count()
	t.check(Scouting.send(s, target) != "", "an idle hauler can be sent")
	var scout: Dictionary = s.people.kith.filter(func(k): return k["job"] == "scout")[0]
	t.check(not scout["cart"], "not a cart: carts keep to the roads")
	var arrived := false
	var home := false
	for i in 2000:
		s.tick(0.1)
		if not arrived and scout["phase"] == "scout_home":
			arrived = true
			t.check(
				Vector2(scout["pos"]).distance_to(Vector2(target)) <= 1.5,
				"it went to the tile (at %s)" % [scout["pos"]]
			)
			t.check(s.fog.is_revealed(target), "the fog is lifted there")
			t.check(s.fog.is_revealed(target + Vector2i(Data.SCOUT_SIGHT - 1, 0)), "out to the scout's radius")
			t.check(s.fog.count() > seen_before, "more of the map is seen")
		if arrived and scout["job"] != "scout":
			home = true
			break
	t.check(arrived and home, "it looked, then walked home")
	t.check(Vector2(scout["pos"]).distance_to(Vector2(s.world.camp_pos)) < 1.5, "to the Hearth")
	s.tick(0.1)
	t.check(scout["job"] == "haul" and Scouting.count(s) == 0, "and hauls again")


func test_a_scout_has_edge_cases_and_survives_a_save() -> void:
	var s := _fogged()
	var target := _fog_tile(s, 8)
	t.check(
		Scouting.send(s, target) != "" and Scouting.send(s, target) == Data.SCOUT_BUSY,
		"a second click on the same fog sends no second scout"
	)
	var far := _fog_tile(s, 14)
	t.check(Scouting.send(s, far) != "" and Scouting.count(s) == 2, "a click elsewhere sends another")
	# Everyone busy: the message says so.
	var busy := _fogged()
	for k in busy.people.kith:
		k["job"] = "work"
	t.check(
		Scouting.send(busy, _fog_tile(busy, 8)) == Data.SCOUT_NOBODY % Data.PEOPLE["many"], "no idle Kith, no scout"
	)
	var carrying := _fogged()
	for k in carrying.people.kith:
		k["job"] = "haul"
		k["carry"] = {"wood": 3}
	t.check(
		Scouting.send(carrying, _fog_tile(carrying, 8)) == Data.SCOUT_NOBODY % Data.PEOPLE["many"],
		"a hauler with a load is busy"
	)
	# A click on fogged river goes to the nearest dry tile.
	var wet := _fogged()
	var river := Vector2i(-1, -1)
	for y in wet.world.height:
		for x in wet.world.width:
			var p := Vector2i(x, y)
			if river.x < 0 and wet.world.tile_at(p) == "river" and not wet.fog.is_revealed(p):
				river = p
	t.check(
		river.x >= 0 and Scouting.goal(wet, river) != Vector2i(-1, -1), "a fogged river tile has dry ground near it"
	)
	t.check(not wet.pathing.astar.is_point_solid(Scouting.goal(wet, river)), "and the scout is sent there")
	# It survives a save mid-trip and goes on.
	var d := RunSave.from_json(RunSave.to_json(RunSave.dump(s)))
	var copy := Sim.new()
	t.check(RunSave.restore(copy, d), "a save with scouts out restores")
	t.check(Scouting.count(copy) == 2, "both are still scouts")
	var one: Dictionary = copy.people.kith.filter(func(k): return k["job"] == "scout")[0]
	t.check(one["task"]["tile"] is Vector2i and one["phase"] == "scout_out", "with their target and phase")
	copy.economy.inv["berries"] = 200
	for i in 3000:
		copy.tick(0.1)
	t.check(Scouting.count(copy) == 0, "and they come home")
