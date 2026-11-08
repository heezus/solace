extends RefCounted
## No silent gates (design-system/25-playtesting.md, "Fun playtest 1"): what stands in the way of a tech or a goal is said, a locked card
## says what it waits on, a refused research or line build says why.
## Registered by AiPlayerTests.run.

const Chain = preload("res://scripts/chain.gd")
const Chores = preload("res://scripts/chores.gd")
const Forage = preload("res://scripts/forage.gd")
const Roads = preload("res://scripts/roads.gd")
const CardText = preload("res://scripts/card_text.gd")
const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Workers = preload("res://scripts/workers.gd")
const Snapshot = preload("res://tests/tools/ai_snapshot.gd")
const AiPost = preload("res://tests/tools/ai_post.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_a_hidden_tech_names_the_good_it_waits_on()
	test_the_goal_and_the_locked_card_walk_back_the_chain()
	test_research_and_line_refusals_say_why()
	test_a_hand_chore_names_the_machine_that_ends_it()
	test_a_status_cannot_contradict_the_stock()
	test_every_refusal_has_a_reason()
	test_a_building_no_road_can_reach_is_warned_about()
	test_every_panel_part_with_buttons_has_a_table_move()
	test_no_goal_text_shows_a_raw_placeholder()
	test_every_still_has_words()
	test_the_table_lists_what_the_build_menu_offers()
	test_the_hauler_hint_gives_the_safe_fix_first()


func _fresh() -> Sim:
	var s := Sim.new()
	s.generate(3)
	return s


## A town that has learned and held everything on the way to Farming but Grain: the one thing out of view is Farming itself.
func _before_grain(s: Sim) -> void:
	for tech in ["gatherers_hut", "stone_axe", "masonry", "cordage", "fire", "knapping", "haulers", "pottery"]:
		s.tech_tree.researched[tech] = true
	for id in Data.ITEM_ORDER:
		s.economy.seen[id] = true
		s.economy.inv[id] = 200
	s.economy.seen.erase("grain")
	s.economy.inv["grain"] = 0


func test_a_hidden_tech_names_the_good_it_waits_on() -> void:
	var s := _fresh()
	_before_grain(s)
	var step := Chain.step(s, "farming")
	t.check(
		step.get("kind", "") == "unseen" and step["tech"] == "farming",
		"Farming waits on a good never held (%s)" % [step]
	)
	t.check(step["line"].contains("Grain"), "and the line names Grain: " + step.get("line", ""))
	t.check(
		Chain.note(s, "grindstone").begins_with("Grindstone needs "),
		"the Grindstone's note walks back: " + Chain.note(s, "grindstone")
	)
	s.economy.add("grain", 3)
	t.check(Chain.step(s, "farming").get("kind", "") != "unseen", "once Grain has been held it is no longer the gate")
	t.check(
		Chain.note(s, "farming") != "" or s.tech_tree.can_research("farming"), "and what is left is a price or nothing"
	)
	s.tech_tree.researched["farming"] = true
	t.check(Chain.note(s, "farming") == "", "a tech learned has no note")


func test_the_goal_and_the_locked_card_walk_back_the_chain() -> void:
	var s := _fresh()
	_before_grain(s)
	for g in Data.GOALS:
		if g["id"] == "grind":
			break
		s.story.goals_done[g["id"]] = true
	t.check(s.story.asked_building() == "grindstone", "the Grindstone goal asks for the Grindstone")
	t.check(CardText.shown(s, "grindstone"), "so its card shows though its tech is out of view")
	var goal: Dictionary = s.story.goal_list()[s.story.current_goal()]
	t.check(
		s.story.gate_note(s, goal).contains("Farming"), "and the goal line names Farming: " + s.story.gate_note(s, goal)
	)
	t.check(
		CardText.locked_reason("grindstone", 0.0, s).begins_with("Blocked by"), "the locked card says what blocks it"
	)
	t.check(Snapshot.text(s, 1, [], []).contains("IN THE WAY:"), "the AI page carries the same line")


func test_research_and_line_refusals_say_why() -> void:
	var s := _fresh()
	_before_grain(s)
	s.fog.reveal_all()
	var refused := Snapshot.apply(s, [{"do": "research", "tech": "farming"}])
	t.check(refused.size() == 1 and refused[0].contains("Grain"), "a refused research gives its reason: %s" % [refused])
	var gravel := Vector2i(-1, -1)
	for y in s.world.height:
		for x in s.world.width:
			if gravel.x < 0 and s.world.tile_at(Vector2i(x, y)) == "gravel":
				gravel = Vector2i(x, y)
	t.check(gravel.x >= 0, "the map has gravel")
	var report := CardText.line_report(s, "road", [gravel + Vector2i(0, 0)])
	t.check(
		report.contains("Stopped at") and report.contains("Riverbed Gravel"),
		"a line over gravel names the tile and the ground: " + report
	)
	var err := s.town.placement_error("road", gravel)
	t.check(err.contains("go around"), "and a road refusal says to go around: " + err)
	t.check(
		Data.BUILDINGS["water_wheel"]["desc"].begins_with("Needs: "),
		"a wheel's requirement is a Needs line, not a status"
	)


## Fun-2: the same good by hand five times in a minute is a chore, and the goal line names the building that would take it over.
func test_a_hand_chore_names_the_machine_that_ends_it() -> void:
	var s := _fresh()
	t.check(Chores.note(s) == "", "no chore, no line")
	for i in Chores.CHORE_REPEATS - 1:
		Chores.record(s, "clay")
	t.check(Chores.note(s) == "", "four harvests are not yet a chore")
	Chores.record(s, "clay")
	var line := Chores.note(s)
	t.check(
		line.contains("Gatherer's Hut") and line.contains("road"),
		"five clay in a minute names the hut and a road: " + line
	)
	t.check(line.begins_with("Discover"), "and says to discover it first when it is not known: " + line)
	s.tech_tree.researched["gatherers_hut"] = true
	t.check(not Chores.note(s).begins_with("Discover"), "known, it only names the hut: " + Chores.note(s))
	var goal: Dictionary = s.story.goal_list()[0]
	t.check(Snapshot.text(s, 1, [], []).contains("A MACHINE FOR IT:"), "the AI page carries it too (%s)" % goal["id"])
	for i in Chores.CHORE_REPEATS:
		Chores.record(s, "rope")
	t.check(
		Chores.repeated(s).has("rope") and Chores.repeated(s).has("clay"),
		"two chores at once: %s" % [Chores.repeated(s)]
	)
	s.seasons.time += Chores.CHORE_WINDOW + 1.0
	t.check(Chores.note(s) == "", "a minute on, the chore is forgotten")
	for i in Chores.CHORE_REPEATS:
		Chores.record(s, "rope")
	t.check(
		Chores.note(s).contains("Twine Post") and Chores.note(s).contains("staffed"),
		"rope names the Twine Post: " + Chores.note(s)
	)
	s.story.events.append("star_falling")
	t.check(Chores.note(s) == "", "later eras assume the player knows: no line")
	for i in Chores.CHORE_REPEATS * 4:
		Chores.record(s, "wood")
	t.check(s.economy.chore_log.size() <= Chores.CHORE_CAP, "the log stays small: %d" % s.economy.chore_log.size())


## Fun-2: "Needs Fiber" with fiber in stock, "Food is short" with a full store, "lasts 60:00" with food falling. One set of numbers.
func test_a_status_cannot_contradict_the_stock() -> void:
	var s := _fresh()
	var p: Vector2i = s.world.camp_pos + Vector2i(3, 3)
	s.town.add_building("twine_post", p)
	var b: Dictionary = s.town.buildings[s.town.building_at[p]]
	var def: Dictionary = Data.BUILDINGS["twine_post"]
	s.economy.inv["fiber"] = 40
	Workers.idle_reason(s, b, def)
	t.check(not b["alert"].contains("Fiber"), "fiber in stock: the pill does not ask for it (%s)" % b["alert"])
	t.check(
		b["status"].contains("in stock") and b["status"].contains("click"),
		"and the status says to click: " + b["status"]
	)
	s.economy.inv["fiber"] = 0
	Workers.idle_reason(s, b, def)
	t.check(b["alert"] == "Needs Fiber", "no fiber in stock: it does ask (%s)" % b["alert"])
	t.check(b["status"].contains("none in stock"), "and says none is in stock: " + b["status"])
	# food: a short store says so, a full one in a lean season says "lean season", and the page shows the readout's own rate
	s.economy.famine = false
	s.economy.forage_told = false
	t.check(not s.economy.food_is_short(), "a fresh town's food is not short")
	var line: String = Forage.LEAN_EVENT if not s.economy.food_is_short() else Data.FORAGE_EVENT
	t.check(not line.begins_with("Food is short"), "so its foraging line does not claim it: " + line)
	var page := Snapshot.text(s, 1, [], [])
	t.check(not page.contains("lasts 60:00"), "the page never says lasts 60:00")
	var rate: float = s.economy.food_rate()
	t.check(
		page.contains("holding or growing") if rate >= -0.005 else page.contains("falling"),
		"the food line follows the readout's rate (%.3f)" % rate
	)


## Fun-2: every move the table refuses comes back with words, never an empty bracket.
func test_every_refusal_has_a_reason() -> void:
	var s := _fresh()
	var moves: Array = [
		{"do": "build", "type": "kiln", "x": 1, "y": 1},
		{"do": "build", "type": "nothing", "x": 1, "y": 1},
		{"do": "line", "type": "road", "from": [1, 1], "to": [1, 1]},
		{"do": "line", "type": "road"},
		{"do": "goal", "tech": "iron_dawn_not_real"},
		{"do": "research", "tech": "falling_star"},
		{"do": "research", "tech": "nope"},
		{"do": "moment", "choice": 0},
		{"do": "season", "choice": 0},
		{"do": "order", "index": 3},
		{"do": "clear_order", "index": 3},
		{"do": "pause", "x": 1, "y": 1},
		{"do": "click", "x": 1, "y": 1},
		{"do": "focus", "x": 1, "y": 1, "item": "wood"},
		{"do": "trade", "x": 1, "y": 1},
		{"do": "fuel", "x": 1, "y": 1},
		{"do": "haulers", "x": 1, "y": 1},
		{"do": "demolish", "x": 1, "y": 1},
		{"do": "gather", "x": 1, "y": 1},
		{"do": "look_east"},
		{"do": "something_else"},
	]
	for refusal in Snapshot.apply(s, moves):
		var open: int = refusal.rfind(" (")
		var reason: String = (
			refusal.substr(open + 2, refusal.length() - open - 3) if open >= 0 and refusal.ends_with(")") else ""
		)
		t.check(reason.strip_edges() != "", "a refusal with words: " + refusal)
		t.check(reason != Snapshot.NO_REASON, "and a real reason, not the fallback: " + refusal)


## Fun-2: a Grindstone put in the middle of the flax could never get a road. The hover and the page's log say so at the build.
func test_a_building_no_road_can_reach_is_warned_about() -> void:
	var s := _fresh()
	s.fog.reveal_all()
	var p: Vector2i = s.world.camp_pos + Vector2i(-7, -7)
	s.world.set_tile(p, "grass")
	for n in Roads.SIDES:
		s.world.set_tile(p + n, "flax")
	t.check(Roads.boxed_in(s, p), "flax on all four sides: no road can touch it")
	t.check(Roads.boxed_by(s, p) == "Wild Flax", "and it names the flax: " + Roads.boxed_by(s, p))
	s.world.set_tile(p + Vector2i(1, 0), "grass")
	t.check(not Roads.boxed_in(s, p), "one open side and a road can reach it")
	s.world.set_tile(p + Vector2i(1, 0), "flax")
	s.tech_tree.researched["pottery"] = true
	for id in Data.ITEM_ORDER:
		s.economy.seen[id] = true
		s.economy.inv[id] = 300
	var before: int = s.events.size()
	t.check(s.place("kiln", p), "the Kiln goes down: it is a warning, not a refusal")
	var said: Array = s.events.slice(before)
	t.check(
		said.any(func(e): return String(e).begins_with("Boxed in by Wild Flax")), "and the game says so: %s" % [said]
	)
	var q: Vector2i = s.world.camp_pos + Vector2i(-6, 4)
	for n in [Vector2i.ZERO] + Roads.SIDES:
		s.world.set_tile(q + n, "grass")
	var again: int = s.events.size()
	var err: String = s.town.placement_error("kiln", q)
	t.check(s.place("kiln", q), "a second Kiln on open ground goes down (%s)" % err)
	t.check(not s.events.slice(again).any(func(e): return String(e).begins_with("Boxed")), "open ground: no warning")


## Fun-3: the Expedition Post's card had no move on the table, so two players stalled for twenty minutes. Every part of a building's
## card that has buttons (it has a `changed` signal) names the table move that presses them, and the page's MOVES help lists the move.
func test_every_panel_part_with_buttons_has_a_table_move() -> void:
	var s := _fresh()
	var panel := BuildingPanel.new()
	panel.setup(s)
	var seen := 0
	for key in panel.parts:
		var part = panel.parts[key]
		if not (part is Container and part.has_signal("changed")):  # a bar (Range) has its own changed
			continue
		seen += 1
		t.check(
			AiPost.PANEL_MOVES.has(key),
			"the card part '%s' has buttons: name its table move in AiPost.PANEL_MOVES" % key
		)
		if AiPost.PANEL_MOVES.has(key):
			var move: String = AiPost.PANEL_MOVES[key]
			t.check(
				Snapshot.HELP.contains('"do":"%s"' % move), "and the help lists the move '%s' for '%s'" % [move, key]
			)
	t.check(seen >= 8, "the test saw the card's parts (%d)" % seen)
	panel.free()


## Fun-3: "{cost}" showed on the Falling Star gate goal. No goal of any era, as the Goals list or the table's page says it, keeps a "{".
func test_no_goal_text_shows_a_raw_placeholder() -> void:
	var s := _fresh()
	for list in [
		Data.GOALS, Data.GOALS_ERA2, Data.GOALS_ERA3, Data.GOALS_ERA4, Data.GOALS_ERA5, Data.SKYREACH["goals"]
	]:
		for g in list:
			t.check(not "{" in s.story.goal_text(g), "goal '%s' says: %s" % [g["id"], s.story.goal_text(g)])
	for event in ["bronze_dawn", "star_falling"]:
		s.story.record(event)
	for g in s.story.goal_list():
		s.story.goals_done[g["id"]] = true
	s.story.goals_done.erase("falling_star")
	var line := ""
	for l in Snapshot.text(s, 1, [], []).split("\n"):
		if l.begins_with("GOAL"):
			line = l
	t.check(line != "" and not "{" in line, "and the table's GOAL line: %s" % line)


## Fun-3: a scene came up as an empty block. Every still of every cutscene, and each variant of it, has words.
func test_every_still_has_words() -> void:
	for id in Data.CUTSCENES:
		for still in Data.CUTSCENES[id]["stills"]:
			t.check(str(still.get("line", "")).strip_edges() != "", "scene '%s' has a still with no words" % id)
			for v in still.get("variants", {}):
				var variant: Dictionary = still["variants"][v]
				t.check(
					str(variant.get("line", still.get("line", ""))).strip_edges() != "",
					"scene '%s' variant '%s' has no words" % [id, v]
				)


## Fun-3: the Glyph Wall, the Lumen Camp and the Expedition Post did not show in BUILDABLE. The page lists what the build menu offers.
func test_the_table_lists_what_the_build_menu_offers() -> void:
	var s := _fresh()
	for e in ["lumen_arrived", "name_read"]:
		s.story.record(e)
	var buildable := ""
	for l in Snapshot.text(s, 1, [], []).split("\n"):
		if l.begins_with("BUILDABLE"):
			buildable = l
	for type in ["glyph_wall", "lumen_camp", "expedition_post"]:
		t.check(s.town.unlocked(type), "%s is offered by the build menu once its event is told" % type)
		t.check(
			buildable.contains(" %s " % type) or buildable.contains(": %s " % type),
			"and the table's BUILDABLE lists it"
		)
	for type in Data.BUILDINGS:
		if type != "camp" and s.town.unlocked(type):
			t.check(buildable.contains("%s " % type), "everything the menu unlocks is listed: %s" % type)


## Fun-3: the held-back workshop's hint led a player to press - and stall the town. The Dwelling comes first; - only when spares stand.
func test_the_hauler_hint_gives_the_safe_fix_first() -> void:
	var text: String = Data.HOLD_BACK_STATUS % [3, 5, Data.PEOPLE["many"]]
	t.check(
		text.contains("Dwelling") and not text.contains("press -") and not text.contains("Press -"),
		"no '-' without spares: " + text
	)
	t.check(text.ends_with("."), "and the sentence ends: " + text)
	t.check(
		Snapshot._note_of({"type": "gatherers_hut", "status": text + " " + text, "alert": ""}).length() > 100,
		"the page keeps a whole hint"
	)
