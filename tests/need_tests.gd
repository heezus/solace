extends RefCounted
## Fun playtest 3 (design-system/25-playtesting.md): every "Needs X" names where X comes from, a goal that asks for a building says what
## shuts it or what its price waits on, no choice shuts a goal for good, the Bloom cannot take every way back to a good, and a pause or
## a road message says how to undo it. Registered by AiPlayerTests.run.

const Data = preload("res://scripts/data.gd")
const Needs = preload("res://scripts/needs.gd")
const Roads = preload("res://scripts/roads.gd")
const Sim = preload("res://scripts/sim.gd")
const StartTidy = preload("res://scripts/start_tidy.gd")
const Workers = preload("res://scripts/workers.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_every_good_a_building_wants_says_where_it_comes_from()
	test_shardlight_names_its_source_by_what_is_open()
	test_a_building_goal_names_what_shuts_it_or_what_it_waits_on()
	test_every_goal_can_name_its_next_step()
	test_no_gift_choice_shuts_a_goal()
	test_the_bloom_cannot_take_every_way_back_to_clay()
	test_every_good_has_a_way_back_in_a_market_town()
	test_a_pause_says_how_to_undo_it_and_a_start_keeps_the_goals_makers_working()
	test_a_road_that_reaches_no_depot_says_so()
	test_the_cards_show_what_each_choice_gives_and_costs()


func _fresh() -> Sim:
	var s := Sim.new()
	s.generate(3)
	return s


func test_every_good_a_building_wants_says_where_it_comes_from() -> void:
	var seen := {}
	for type in Data.BUILDINGS:
		var def: Dictionary = Data.BUILDINGS[type]
		for id in def["cost"].keys() + def.get("in", {}).keys():
			if seen.has(id):
				continue
			seen[id] = true
			t.check(
				Needs.provider(id) != "", "%s: %s is made or gathered somewhere, and the game says where" % [type, id]
			)


func test_shardlight_names_its_source_by_what_is_open() -> void:
	var s := _fresh()
	t.check(
		Needs.shardlight(s).contains("Cairn") and Needs.shardlight(s).contains("Light marks"),
		"before the Light set: the Cairn, or read the marks"
	)
	s.starfall.locked["light"] = true
	t.check(
		Needs.shardlight(s).contains("Shard Lantern"),
		"with the Lantern open it names the Lantern: " + Needs.shardlight(s)
	)
	var s2 := _fresh()
	s2.starfall.locked["light"] = true
	s2.starfall.roads["light"] = "refuse"  # Cairnfire taken
	t.check(
		s2.starfall.opens("light"),
		"refusing the Light gift (Cairnfire) leaves the Lantern open: the Kith light their own"
	)
	t.check(Needs.shardlight(s2).contains("Shard Lantern"), "and the line names it")
	# a Shardwright far from any light says so in its status
	s.town.add_building("shardwright", s.world.camp_pos + Vector2i(6, 6))
	s.starfall.locked["craft"] = true
	var b: Dictionary = s.town.buildings[-1]
	Workers.tick_building(s, b, 0.5, true)
	t.check(b["alert"] == Data.LUMEN["needs_light"], "it waits on shardlight")
	t.check(
		b["status"].contains("Shard Lantern") and b["status"].begins_with(b["alert"] + ":"),
		"and the status names the Lantern: " + b["status"]
	)


func test_a_building_goal_names_what_shuts_it_or_what_it_waits_on() -> void:
	var s := _fresh()
	for e in ["bronze_dawn", "star_falling", "lumen_arrived", "name_read"]:
		s.story.record(e)
	var ward := {"id": "lumen_ward", "building": "lumen_ward"}
	var note: String = s.story.gate_note(s, ward)
	t.check(note.contains("Craft marks"), "the Ward is shut until the Craft set is read, and says so: " + note)
	s.starfall.locked["craft"] = true
	s.economy.inv["shardwork"] = 0
	note = s.story.gate_note(s, ward)
	t.check(
		note.contains("Shardwork") and note.contains("Shardwright"),
		"then it names the Shardwork and where it is made: " + note
	)
	s.town.add_building("shardwright", s.world.camp_pos + Vector2i(6, 6))
	s.town.buildings[-1]["alert"] = Data.LUMEN["needs_light"]
	s.town.buildings[-1]["status"] = Needs.shardlight(s)
	note = s.story.gate_note(s, ward)
	t.check(
		note.contains("dark") and note.contains("Cairn"),
		"and with a Shardwright in the dark, that it needs light: " + note
	)


## Every goal that asks for a building or a tech has an IN THE WAY line in an empty town, unless all it wants is gathered by hand.
func test_every_goal_can_name_its_next_step() -> void:
	var s := _fresh()
	for list in [
		Data.GOALS, Data.GOALS_ERA2, Data.GOALS_ERA3, Data.GOALS_ERA4, Data.GOALS_ERA5, Data.SKYREACH["goals"]
	]:
		for g in list:
			if not (g.has("tech") or g.has("building")):
				continue
			var cost: Dictionary = (
				Data.BUILDINGS[g["building"]]["cost"] if g.has("building") else s.tech_tree.cost_of(g["tech"])
			)
			var made := cost.keys().any(func(id): return not Needs.makers_of(id).is_empty())
			if g.has("building") and not made and Data.BUILDINGS[g["building"]]["tech"] != "":
				continue  # raw goods and a tech: Chain names the tech when it stands in the way
			if made or g.has("tech"):
				t.check(
					s.story.gate_note(s, g) != "", "goal '%s' names what stands in its way in an empty town" % g["id"]
				)


## A gift refused for the Kith's twin must not shut a goal: every building a goal asks for that a Lumen set opens, opens either way.
func test_no_gift_choice_shuts_a_goal() -> void:
	for id in Data.ROAD_ORDER:
		for choice in ["accept", "refuse"]:
			var s := _fresh()
			s.starfall.locked[id] = true
			s.starfall.roads[id] = choice
			for list in [Data.GOALS_ERA3, Data.GOALS_ERA4, Data.GOALS_ERA5]:
				for g in list:
					var def: Dictionary = Data.BUILDINGS.get(g.get("building", ""), {})
					if def.has("lumen") and def["lumen"] == id:
						t.check(
							s.starfall.opens(id),
							"goal '%s': the %s set %s leaves its building open" % [g["id"], id, choice]
						)
	# a goal's building also needs shardlight to work: both roads must leave a way to light
	for choice in ["accept", "refuse"]:
		var s := _fresh()
		s.starfall.locked["light"] = true
		s.starfall.roads["light"] = choice
		t.check(s.starfall.opens("light"), "the Light set %s leaves the Shard Lantern open" % choice)


## The Bloom wears the clay banks' colour but leaves them: a town with no Kiln, Bloomery or clay hut can still dig clay by hand.
func test_the_bloom_cannot_take_every_way_back_to_clay() -> void:
	var s := _fresh()
	s.tech_tree.researched["bronze_dawn"] = true
	var p := Vector2i(-1, -1)
	for y in s.world.height:
		for x in s.world.width:
			if p.x < 0 and s.world.tile_at(Vector2i(x, y)) == "clay":
				p = Vector2i(x, y)
	t.check(p.x >= 0, "the map has a clay bank")
	s.fog.reveal_all()
	s.tide._grow(s, p)
	t.check(s.world.tile_at(p) == "clay", "the tide does not turn a clay bank into Bloom ground")
	var before: int = s.economy.inv.get("clay", 0)
	t.check(s.gather_by_hand(p) != "" and s.economy.inv.get("clay", 0) > before, "and it can still be dug by hand")
	t.check("clay" in Data.TIDE_KEEPS, "(clay is on the list of ground the tide keeps)")


## Remove every producer: a town with only the ground the Bloom leaves still has a way back to every good any building costs.
func test_every_good_has_a_way_back_in_a_market_town() -> void:
	var s := _fresh()
	s.tech_tree.researched["markets"] = true
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			if not s.world.tile_at(p) in Data.TIDE_KEEPS and s.world.tile_at(p) != "":
				s.world.set_tile(p, Data.TILE_BLOOM_TIDE)
	s.town.buildings.clear()
	var checked := {}
	for type in Data.BUILDINGS:
		for id in Data.BUILDINGS[type]["cost"].keys() + Data.BUILDINGS[type].get("in", {}).keys():
			if not checked.has(id):
				checked[id] = true
				t.check(Needs.way_back(s, id), "after the Bloom took the producers, %s can still be had" % id)
	s.tech_tree.researched.erase("markets")
	t.check(Needs.way_back(s, "clay"), "even with no market, clay can be dug")


func test_a_pause_says_how_to_undo_it_and_a_start_keeps_the_goals_makers_working() -> void:
	var s := _fresh()
	s.tech_tree.researched["pottery"] = true
	s.town.add_building("kiln", s.world.camp_pos + Vector2i(3, 3))
	var b: Dictionary = s.town.buildings[-1]
	s.town.set_paused(s.town.buildings.size() - 1, true)
	Workers.tick_building(s, b, 0.5, true)
	t.check(
		b["status"].begins_with("Paused: ") and b["status"].contains("Resume") and b["status"].contains("Brick"),
		b["status"]
	)
	# a start does not idle a maker of what the goal in front of the player is made of
	t.check(
		StartTidy._makes({"type": "kiln", "focus": ""}, {"brick": true}),
		"a Kiln makes brick, which a goal can be made of"
	)
	t.check(not StartTidy._makes({"type": "kiln", "focus": ""}, {"iron": true}), "and not iron")


func test_a_road_that_reaches_no_depot_says_so() -> void:
	var s := _fresh()
	s.tech_tree.researched["haulers"] = true
	var p: Vector2i = s.world.camp_pos + Vector2i(9, 9)
	s.world.roads[p + Vector2i(1, 0)] = "road"  # a road tile beside the spot that joins nothing
	t.check(Roads.touched(s, p), "a road touches the spot")
	t.check(
		Workers.road_hint(s, p).contains("reaches no Hearth or Storehouse"),
		"and the hint says it goes nowhere: " + Workers.road_hint(s, p)
	)
	t.check(
		not Workers.road_hint(s, p + Vector2i(0, 5)).contains("reaches no"), "a spot with no road near says to lay one"
	)


func test_the_cards_show_what_each_choice_gives_and_costs() -> void:
	var s := _fresh()
	for id in Data.MOMENTS:
		s.starfall.pending = id
		for opt in s.starfall.pending_options():
			t.check(
				opt["note"].contains("Trust ") and opt["note"].contains("Costs:"), "moment %s: %s" % [id, opt["note"]]
			)
	for id in Data.ROAD_ORDER:
		s.starfall.pending = "road_" + id
		var opts: Array = s.starfall.pending_options()
		t.check(
			opts[0]["note"].contains("Costs:") and opts[1]["note"].contains("Costs:"),
			"gift %s: both buttons say what they cost" % id
		)
		t.check(
			opts[1]["note"].contains("Trust -4"), "and keeping to the Kith way says it loses trust: " + opts[1]["note"]
		)
