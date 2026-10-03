extends RefCounted
## A Gatherer's Hut works one resource, its focus (found by the newcomer playtest of 2026-09-30: a hut placed
## "near Berry Bushes" gathered Wood x13, Berries x3 in turns, so the food hut made no food). The focus starts
## as the resource nearest the hut, one click moves it on, and the hut gathers only that item. Run from
## tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const HutFocus = preload("res://scripts/hut_focus.gd")
const Workers = preload("res://scripts/workers.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_a_new_hut_works_the_nearest_resource()
	test_ties_go_to_food_when_it_is_short_else_the_fixed_order()
	test_a_hut_beside_a_few_bushes_beats_many_trees()
	test_a_hut_with_nothing_near_has_no_focus()
	test_cycling_and_setting_the_focus()
	test_a_hut_gathers_only_its_focus()
	test_the_berries_goal_needs_a_hut_on_berries()
	test_job_and_bundle_follow_the_focus()
	test_the_panel_line_and_the_range_text()
	test_an_unlinked_hut_waiting_for_a_click_says_so()
	test_the_click_bubble_stops_nagging_while_the_food_is_comfortable()
	test_a_food_hut_with_a_foraging_worker_shows_no_bubble()
	test_the_focus_survives_a_save()
	test_a_hut_goes_down_working_the_resource_picked()
	test_a_pick_at_placement_is_for_that_hut_only()
	test_tab_steps_through_the_resources_in_reach()
	test_a_hut_left_unchosen_says_so_once()
	test_the_placement_picker_sits_by_the_ghost()
	test_the_panel_picker_sets_the_focus_and_the_save_keeps_it()
	test_an_old_save_gets_a_default_focus()


## A game on the standard test map with a cleared square of grass (radius 4) around a spot away from the Hearth,
## Gatherer's Hut unlocked and a full stockpile. Returns [game, centre].
func _arena() -> Array:
	var s: Sim = t.fresh()
	s.tech_set["gatherers_hut"] = true
	t.give(s, 100)
	var c := s.world.camp_pos
	var at := Vector2i(-1, -1)
	for off in [Vector2i(9, 0), Vector2i(-9, 0), Vector2i(0, 8), Vector2i(0, -8)]:
		var p: Vector2i = c + off
		if s.world.in_bounds(p - Vector2i(5, 5)) and s.world.in_bounds(p + Vector2i(5, 5)):
			at = p
			break
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			s.world.set_tile(at + Vector2i(dx, dy), "grass")
	return [s, at]


func _put(s: Sim, p: Vector2i, tile: String) -> void:
	s.world.set_tile(p, tile)


func test_a_new_hut_works_the_nearest_resource() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	for off in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(-2, 0), Vector2i(-2, 1)]:
		_put(s, p + off, "tree")  # four trees in reach
	_put(s, p + Vector2i(0, 1), "berry")  # one berry bush, right beside it
	t.check(s.town.default_focus(p) == "berries", "the one bush beside the hut beats four trees further away")
	t.check(s.place("gatherers_hut", p), "the hut goes down")
	t.check(s.town.buildings[s.town.building_at[p]]["focus"] == "berries", "and starts on Berries")
	_put(s, p + Vector2i(0, 1), "grass")
	_put(s, p + Vector2i(0, -2), "rock")
	t.check(s.town.default_focus(p) == "wood", "with the bush gone the nearest are the trees, two away")
	_put(s, p + Vector2i(1, 0), "rock")
	t.check(s.town.default_focus(p) == "stone", "and a Rock beside it wins again")


func test_ties_go_to_food_when_it_is_short_else_the_fixed_order() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_put(s, p + Vector2i(1, 0), "berry")
	_put(s, p + Vector2i(-1, 0), "tree")
	_put(s, p + Vector2i(0, -1), "tree")
	t.check(
		s.town.default_focus(p) == "wood", "food in stock, one bush and two trees alike near: the first in item order"
	)
	for food in Data.FOOD_VALUE:
		s.economy.inv[food] = 0
	t.check(s.town.default_focus(p) == "berries", "with the food short the tie goes to the berries")
	s.economy.inv["berries"] = 100
	s.economy.low = true
	t.check(s.town.default_focus(p) == "berries", "and so it does while the food warning is up")
	_put(s, p + Vector2i(-1, 0), "grass")
	_put(s, p + Vector2i(0, -1), "grass")
	_put(s, p + Vector2i(0, 2), "tree")
	t.check(
		s.town.default_focus(p) == "berries", "a nearer bush still wins with food in stock: " + s.town.default_focus(p)
	)
	s.economy.low = false
	var again := _arena()
	var s2: Sim = again[0]
	_put(s2, again[1] + Vector2i(1, 0), "berry")
	_put(s2, again[1] + Vector2i(-1, 0), "tree")
	t.check(s2.town.default_focus(again[1]) == "wood", "the same layout always gives the same focus")


## Playtest 3: a hut put right beside three bushes, with 13 trees in reach, started on Wood.
func test_a_hut_beside_a_few_bushes_beats_many_trees() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	for off in [Vector2i(1, 1), Vector2i(-2, 0), Vector2i(0, -2)]:
		_put(s, p + off, "berry")  # bushes one to two tiles away
	var trees := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var off := Vector2i(dx, dy)
			if maxi(absi(dx), absi(dy)) == 2 and trees < 13 and s.world.tile_at(p + off) == "grass":
				_put(s, p + off, "tree")
				trees += 1
	t.check(trees == 13 and s.town.gather_tiles(p).size() >= 14, "set up: 13 trees and the bushes in reach")
	t.check(s.town.default_focus(p) == "berries", "the hut starts on the berries it was put beside")
	t.check(s.place("gatherers_hut", p), "placed")
	t.check(s.town.buildings[s.town.building_at[p]]["focus"] == "berries", "and its focus is Berries")


func test_a_hut_with_nothing_near_has_no_focus() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	t.check(s.town.default_focus(p) == "", "bare grass has nothing to work")
	t.check(s.place("gatherers_hut", p), "the hut still goes down")
	var i: int = s.town.building_at[p]
	t.check(s.town.buildings[i]["focus"] == "" and s.town.focus_options(p).is_empty(), "with no focus and no choice")
	t.check(s.town.cycle_focus(i) == "", "a click has nothing to move on to")
	t.check(HutFocus.label_text(s, s.town.buildings[i]) == "Gathering: nothing in reach", "and the line says so")


func test_cycling_and_setting_the_focus() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_put(s, p + Vector2i(1, 0), "tree")
	_put(s, p + Vector2i(0, 1), "berry")
	_put(s, p + Vector2i(-2, 0), "clay")
	t.check(s.place("gatherers_hut", p), "a hut with three resources in reach")
	var i: int = s.town.building_at[p]
	t.check(s.town.focus_options(p) == ["wood", "clay", "berries"], "the choices are in the fixed item order")
	t.check(s.town.buildings[i]["focus"] == "wood", "it starts on the tie-broken nearest, Wood")
	t.check(s.town.cycle_focus(i) == "clay", "one click: Clay")
	t.check(s.town.cycle_focus(i) == "berries", "the next: Berries")
	t.check(s.town.cycle_focus(i) == "wood", "and around again to Wood")
	t.check(s.town.set_focus(i, "berries") and s.town.buildings[i]["focus"] == "berries", "a focus can be set outright")
	t.check(not s.town.set_focus(i, "stone"), "but not to something out of reach")
	t.check(s.town.buildings[i]["focus"] == "berries", "and a refusal changes nothing")
	t.check(not s.town.set_focus(0, "berries"), "and the Hearth takes no focus")
	_put(s, p + Vector2i(-2, 0), "grass")
	t.check(s.town.focus_options(p) == ["wood", "berries"], "a resource that leaves the range leaves the choices")


## Play the hut at `p` for `seconds` with a trip always queued (as a player clicking it would keep it busy) and
## count what its worker brought out, item by item (each bundle counted once, when they pick it up).
func _run_hut(s: Sim, p: Vector2i, seconds: float) -> Dictionary:
	var i: int = s.town.building_at[p]
	var got := {}
	var had := false
	for _n in int(seconds * 10.0):
		s.town.buildings[i]["trips"] = 3
		s.tick(0.1)
		var w: int = s.town.buildings[i]["worker"]
		if w < 0:
			continue
		var carry: Dictionary = s.people.kith[w]["carry"]
		if not carry.is_empty() and not had:
			for id in carry:
				got[id] = got.get(id, 0) + carry[id]
		had = not carry.is_empty()
	return got


func test_a_hut_gathers_only_its_focus() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	for off in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 0), Vector2i(-2, 1), Vector2i(-2, -1)]:
		_put(s, p + off, "tree")
	_put(s, p + Vector2i(0, 1), "berry")
	_put(s, p + Vector2i(1, 1), "berry")
	s.pathing.build()
	for id in ["wood", "berries"]:
		s.people.learned_by[id] = "Aro"
	t.check(s.place("gatherers_hut", p), "a hut between six trees and two berry bushes")
	var i: int = s.town.building_at[p]
	t.check(s.town.buildings[i]["focus"] == "berries", "it was put next to the berries")
	var got := _run_hut(s, p, 120.0)
	print("Hut on berries, two minutes: %s" % got)
	t.check(got.get("berries", 0) >= 20, "two minutes bring a good haul of berries (%d)" % got.get("berries", 0))
	t.check(not got.has("wood"), "and not one Wood, though six trees stand in reach")
	t.check(s.town.set_focus(i, "wood"), "switch it to Wood")
	got = _run_hut(s, p, 60.0)
	t.check(got.get("wood", 0) >= 10 and not got.has("berries"), "now it brings Wood and no berries: %s" % got)
	var k: Dictionary = s.people.kith[s.town.buildings[i]["worker"]]
	t.check(k["task"].is_empty() or s.world.tile_at(k["task"]["tile"]) == "tree", "and walks out only to trees")
	# A focus the Kith have not learned keeps the hut waiting, whatever else they know.
	s.people.learned_by.erase("wood")
	s.town.buildings[i]["trips"] = 3
	t.check(not s.people.knows_focus(s.town.buildings[i]), "a hut whose focus is not learned cannot work it")
	t.check(Workers.dispatch(s, i).begins_with("Nothing learned"), "and a click on it says so")


func test_the_berries_goal_needs_a_hut_on_berries() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_put(s, p + Vector2i(1, 0), "tree")
	_put(s, p + Vector2i(0, 2), "berry")
	var goal: Dictionary = {}
	for g in Data.GOALS:
		if g["id"] == "berries":
			goal = g
	t.check(s.place("gatherers_hut", p), "a hut with a tree beside it and berries two away")
	t.check(not s.story.goal_met(s, goal), "set on the tree it does not meet the berries goal")
	s.town.set_focus(s.town.building_at[p], "berries")
	t.check(s.story.goal_met(s, goal), "set on the berries it does")
	t.check(
		String(goal["text"]).contains("Berry Bushes") and String(goal["text"]).contains("only works when you click it"),
		"and the goal says a hut works only when you click it"
	)


func test_job_and_bundle_follow_the_focus() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_put(s, p + Vector2i(1, 0), "tree")
	_put(s, p + Vector2i(0, 2), "berry")
	_put(s, p + Vector2i(-2, -2), "berry")
	s.place("gatherers_hut", p)
	var b: Dictionary = s.town.buildings[s.town.building_at[p]]
	s.people.learned_by["wood"] = "Aro"
	s.people.learned_by["berries"] = "Aro"
	t.check(s.people.building_job(b) == Data.HUT_JOBS["wood"]["title"], "on Wood its worker is a Woodcutter")
	s.town.set_focus(s.town.building_at[p], "berries")
	t.check(s.people.building_job(b) == Data.HUT_JOBS["berries"]["title"], "on Berries a Forager, though two are near")
	var line := BuildingPanel.recipe_text(s, b)
	t.check(
		line.contains("Berries x2") and not line.contains("Wood"), "the range line names only what it works: " + line
	)
	t.check(
		BuildingPanel.pace_text(s, b).contains("brings back 3 Berries."),
		"and so does the trip line: " + BuildingPanel.pace_text(s, b)
	)
	t.check(not BuildingPanel.pace_text(s, b).contains("Wood"), "with no word of Wood")


func test_the_panel_line_and_the_range_text() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_put(s, p + Vector2i(0, 1), "berry")
	s.place("gatherers_hut", p)
	var b: Dictionary = s.town.buildings[s.town.building_at[p]]
	t.check(HutFocus.label_text(s, b) == "Gathering: Berries", "a hut with one choice reads 'Gathering: Berries'")
	_put(s, p + Vector2i(2, 2), "tree")
	t.check(
		HutFocus.label_text(s, b).begins_with("Gathering: Berries"), "with a second choice it still leads with that"
	)
	t.check(HutFocus.label_text(s, b).contains("pick another below"), "and points at the buttons under it")
	var button := HutFocus.new()
	button.setup(s)
	button.show_for(b)
	t.check(button.visible and button.line.text.begins_with("Gathering: Berries"), "the panel line")
	t.check(button.row.visible and button.row.get_child_count() == 2, "with a row of two buttons: one per resource")
	var names: Array = button.row.get_children().map(func(c): return c.text)
	t.check(names == ["Wood", "Berries"], "named in plain words: %s" % [names])
	t.check(button.row.get_child(1).button_pressed and not button.row.get_child(0).button_pressed, "Berries is pressed")
	t.check(String(button.row.get_child(0).tooltip_text).contains("Wood"), "and each says in a tooltip what it does")
	button.cycle()
	t.check(b["focus"] == "wood", "Tab or R (cycle) moves the focus to the next item")
	button.show_for(b)
	t.check(button.line.text.begins_with("Gathering: Wood"), "and the line follows")
	t.check(
		button.row.get_child(0).button_pressed and not button.row.get_child(1).button_pressed, "and the pressed button"
	)
	button.row.get_child(1).pressed.emit()
	t.check(b["focus"] == "berries", "one click on a button picks that resource")
	button.row.get_child(1).pressed.emit()
	t.check(b["focus"] == "berries", "and a second click on it keeps it")
	button.free()
	var hearth := HutFocus.new()
	hearth.setup(s)
	hearth.show_for(s.town.buildings[0])
	t.check(not hearth.visible, "the Hearth has no focus line")
	var lone := HutFocus.new()
	lone.setup(s)
	lone.show_for(b)
	_put(s, p + Vector2i(2, 2), "grass")
	lone.show_for(b)
	t.check(not lone.row.visible and lone.line.text == "Gathering: Berries", "one resource in reach: just the line")
	lone.free()
	_put(s, p + Vector2i(2, 2), "tree")
	hearth.free()
	s.town.set_focus(s.town.building_at[p], "berries")
	var tiles := s.town.tiles_of(p, "berries")
	t.check(BuildingPanel.gather_text(s, tiles).contains("Berries x1"), "the hover text lists the focus tiles only")
	t.check(s.town.tiles_of(p, s.town.focus_at(p)) == tiles, "and the map highlights those same tiles")
	t.check(
		s.town.focus_at(p + Vector2i(1, 1)) == s.town.default_focus(p + Vector2i(1, 1)),
		"a spot with no hut shows the default"
	)


## Found by playtest 3: a newcomer clicked hut 1 and never hut 2, because nothing said an unlinked hut only works
## when clicked. A hut that waits for a click shows a badge, and the goals, hut card and food warning say so.
func test_an_unlinked_hut_waiting_for_a_click_says_so() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_put(s, p + Vector2i(0, 1), "berry")
	s.people.learned_by["berries"] = "Aro"
	s.place("gatherers_hut", p)
	s.tick(0.1)
	var i: int = s.town.building_at[p]
	var b: Dictionary = s.town.buildings[i]
	t.check(b["worker"] >= 0 and b["trips"] == 0, "a new hut has its Kith and no trip waiting")
	t.check(HutFocus.wants_click(s, b), "so it asks for a click")
	t.check(not HutFocus.wants_click(s, s.town.buildings[0]), "and the Hearth does not")
	b["trips"] = 2
	t.check(not HutFocus.wants_click(s, b), "a hut with trips queued does not")
	b["trips"] = 0
	b["paused"] = true
	t.check(not HutFocus.wants_click(s, b), "nor does a paused hut")
	b["paused"] = false
	b["out"] = {"berries": Data.BUFFER_CAP}
	t.check(not HutFocus.wants_click(s, b), "nor a hut whose output is full")
	b["out"] = {}
	s.people.learned_by.erase("berries")
	t.check(not HutFocus.wants_click(s, b), "nor one whose focus its Kith have not learned")
	var goal_text := ""
	for g in Data.GOALS:
		if g["id"] in ["hut", "trip", "berries"]:
			t.check(String(g["text"]).to_lower().contains("click"), "the %s goal says to click the hut" % g["id"])
			goal_text += String(g["text"])
	t.check(not goal_text.contains("keeps coming"), "and none of them promises it keeps working")
	t.check(Data.FOOD_LOW_EVENT.contains("Click your berry hut to send a trip"), "the food warning names the click")
	t.check(Data.TRIPS_HINT.contains("only when you click it"), "the hut card says it works only when clicked")
	t.check(Data.BUILDINGS["gatherers_hut"]["desc"].contains("only when you click it"), "as does its description")


## Playtest 5: the yellow "click" bubbles stayed on after the Kith began foraging by themselves, looking like a to-do the
## game handles. A food hut shows it before the first trip, and once the food is short (warning or famine); while the
## food is comfortable it hides, and the card says clicking is optional. A wood hut always asks: only a click brings wood.
func test_the_click_bubble_stops_nagging_while_the_food_is_comfortable() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_put(s, p + Vector2i(0, 1), "berry")
	_put(s, p + Vector2i(-2, 0), "tree")
	s.people.learned_by["berries"] = "Aro"
	s.people.learned_by["wood"] = "Aro"
	s.place("gatherers_hut", p)
	s.tick(0.1)
	var b: Dictionary = s.town.buildings[s.town.building_at[p]]
	s.economy.inv["berries"] = 200
	t.check(b["focus"] == "berries" and HutFocus.wants_click(s, b), "before any trip was sent, the food hut asks")
	s.story.record("first_trip")
	t.check(not HutFocus.wants_click(s, b), "after a first trip, with comfortable food, it does not")
	t.check(HutFocus.click_can_wait(s, b), "its click can wait")
	var card := BuildingPanel.click_text(s, b)
	t.check(card.begins_with("Your Kith are fed; click to send more anyway."), "the card says so: " + card)
	s.economy.low = true
	t.check(
		HutFocus.wants_click(s, b) and not BuildingPanel.click_text(s, b).contains("are fed"),
		"with the warning up it asks again"
	)
	s.economy.low = false
	s.economy.famine = true
	t.check(HutFocus.wants_click(s, b), "and in a famine, while nobody is out foraging")
	var worker: Dictionary = s.people.kith[b["worker"]]
	worker["phase"] = "forage_pick"
	t.check(not HutFocus.wants_click(s, b), "but not while its worker is foraging for the Hearth on their own")
	worker["phase"] = "forage_back"
	t.check(not HutFocus.wants_click(s, b), "on the way back with the berries either")
	worker["phase"] = "home"
	t.check(HutFocus.wants_click(s, b), "and it asks again once they stop")
	s.economy.famine = false
	b["trips"] = 2
	t.check(not HutFocus.wants_click(s, b), "never with trips waiting")
	b["trips"] = 0
	s.town.set_focus(s.town.building_at[p], "wood")
	t.check(HutFocus.wants_click(s, b), "a wood hut always asks, whatever the food")
	s.economy.famine = true
	worker["phase"] = "forage_out"
	t.check(HutFocus.wants_click(s, b), "even in a famine with its worker foraging: its wood only comes by click")
	s.economy.famine = false
	worker["phase"] = "home"
	t.check(not BuildingPanel.click_text(s, b).contains("are fed"), "and its card does not say the Kith are fed")


## Playtest 6: a berry hut still showed "click" at 5:40 while its Kith was out foraging for the Hearth on their own.
func test_a_food_hut_with_a_foraging_worker_shows_no_bubble() -> void:
	var s: Sim = t.fresh()
	s.tech_set["gatherers_hut"] = true
	t.give(s, 100)
	var camp := s.world.camp_pos
	for dx in range(-1, 5):
		for dy in range(-2, 3):
			s.world.set_tile(camp + Vector2i(dx, dy), "grass")  # a short walk from the Hearth
	var p := camp + Vector2i(3, 0)
	_put(s, p + Vector2i(0, 1), "berry")
	s.people.learned_by["berries"] = "Aro"
	t.check(s.place("gatherers_hut", p), "the hut goes down")
	s.story.record("first_trip")
	var b: Dictionary = s.town.buildings[s.town.building_at[p]]
	for food in Data.FOOD_VALUE:
		s.economy.inv[food] = 0
	s.economy.inv["berries"] = 8  # a couple of minutes for three Kith: the famine fallback starts soon
	var seen_forager := false
	var asked_while_foraging := false
	for i in 1500:
		s.tick(0.1)
		if b["worker"] < 0:
			continue
		var phase := String(s.people.kith[b["worker"]]["phase"])
		if s.economy.famine and phase.begins_with("forage"):
			seen_forager = true
			asked_while_foraging = asked_while_foraging or HutFocus.wants_click(s, b)
	t.check(seen_forager, "set up: the hut's worker went foraging in the famine")
	t.check(not asked_while_foraging, "and the hut never asked for a click while they did")


func test_the_focus_survives_a_save() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_put(s, p + Vector2i(1, 0), "tree")
	_put(s, p + Vector2i(0, 2), "berry")
	s.place("gatherers_hut", p)
	s.town.set_focus(s.town.building_at[p], "berries")
	var d := RunSave.dump(s)
	var copy := Sim.new()
	t.check(RunSave.restore(copy, RunSave.from_json(RunSave.to_json(d))), "a save with a hut loads")
	t.check(copy.town.buildings[copy.town.building_at[p]]["focus"] == "berries", "the hut is still on Berries")
	t.check(RunSave.to_json(RunSave.dump(copy)) == RunSave.to_json(d), "and it writes back the same")
	t.check(copy.town.buildings[0]["focus"] == "", "the Hearth's focus stays empty")


func test_an_old_save_gets_a_default_focus() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_put(s, p + Vector2i(1, 0), "tree")
	_put(s, p + Vector2i(0, 2), "berry")
	s.place("gatherers_hut", p)
	var d := RunSave.from_json(RunSave.to_json(RunSave.dump(s)))
	for saved in d["buildings"]["buildings"]:
		saved.erase("focus")  # a save from before huts had a focus
	var copy := Sim.new()
	t.check(RunSave.restore(copy, d), "a save with no focus field still loads")
	t.check(copy.town.buildings[copy.town.building_at[p]]["focus"] == "wood", "the hut takes what a new hut would")


## A spot with flint-like choice: Wood, Clay and Berries all in reach of the arena's centre, Wood nearest.
func _three(s: Sim, p: Vector2i) -> void:
	_put(s, p + Vector2i(1, 0), "tree")
	_put(s, p + Vector2i(-2, 0), "clay")
	_put(s, p + Vector2i(0, 2), "berry")


func test_a_hut_goes_down_working_the_resource_picked() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_three(s, p)
	t.check(s.town.default_focus(p) == "wood", "set up: the default is the nearest, Wood")
	t.check(s.place("gatherers_hut", p, "clay"), "a hut placed with Clay picked")
	t.check(s.town.buildings[s.town.building_at[p]]["focus"] == "clay", "starts on Clay, with no extra click")
	t.check(
		s.town.focus_tiles(s.town.buildings[s.town.building_at[p]]).size() == 1, "and its range holds the clay tile"
	)
	var q: Vector2i = p + Vector2i(3, 3)
	_put(s, q + Vector2i(0, 1), "tree")
	_put(s, q + Vector2i(1, 1), "clay")
	t.check(s.place("gatherers_hut", q, "stone"), "a pick that is not in reach...")
	t.check(s.town.buildings[s.town.building_at[q]]["focus"] == "wood", "...is ignored: the default stands")


func test_a_pick_at_placement_is_for_that_hut_only() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_three(s, p)
	var q: Vector2i = p + Vector2i(-3, -3)
	_put(s, q + Vector2i(1, 0), "tree")
	_put(s, q + Vector2i(-2, 0), "clay")
	var before: String = s.town.default_focus(q)
	s.place("gatherers_hut", p, "berries")
	t.check(s.town.default_focus(q) == before, "choosing for one hut does not move another spot's default")
	s.place("gatherers_hut", q)
	t.check(s.town.buildings[s.town.building_at[q]]["focus"] == before, "the next hut, placed with no pick, takes it")
	t.check(s.town.buildings[s.town.building_at[p]]["focus"] == "berries", "and the first keeps its pick")


func test_tab_steps_through_the_resources_in_reach() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	t.check(HutFocus.pick_options(s, p).is_empty(), "bare ground: no choice to offer")
	t.check(HutFocus.pick_next(s, p, "") == "", "and Tab changes nothing")
	_put(s, p + Vector2i(1, 0), "tree")
	t.check(HutFocus.pick_options(s, p).is_empty(), "one resource: still no choice")
	_put(s, p + Vector2i(-2, 0), "clay")
	_put(s, p + Vector2i(0, 2), "berry")
	t.check(HutFocus.pick_options(s, p) == ["wood", "clay", "berries"], "three in reach: all offered, in item order")
	var pick := ""
	t.check(HutFocus.pick_chosen(s, p, pick) == "wood", "nothing picked: the default, Wood")
	pick = HutFocus.pick_next(s, p, pick)
	t.check(pick == "clay", "Tab: Clay")
	pick = HutFocus.pick_next(s, p, pick)
	t.check(pick == "berries", "Tab: Berries")
	pick = HutFocus.pick_next(s, p, pick)
	t.check(pick == "wood", "Tab: around to Wood")
	t.check(HutFocus.pick_chosen(s, p, "stone") == "wood", "a pick that is out of reach here shows the default")
	t.check(
		s.town.tiles_of(p, HutFocus.pick_chosen(s, p, "clay")).size() == 1, "and the range overlay follows the pick"
	)


func test_a_hut_left_unchosen_says_so_once() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_put(s, p + Vector2i(1, 0), "tree")
	_put(s, p + Vector2i(-2, 0), "clay")
	s.place("gatherers_hut", p)
	var note := HutFocus.pick_note(s, p, "")
	t.check(
		note == "This hut works Wood. Clay is in reach too: pick it in the hut panel.", "the toast names both: " + note
	)
	t.check(HutFocus.pick_note(s, p, "wood") == "", "no toast when the player picked")
	_put(s, p + Vector2i(0, 2), "berry")
	note = HutFocus.pick_note(s, p, "")
	t.check(note.contains("Clay and Berries are in reach too: pick one"), "with two others it lists them: " + note)
	var b := _arena()
	var s2: Sim = b[0]
	_put(s2, b[1] + Vector2i(1, 0), "tree")
	s2.place("gatherers_hut", b[1])
	t.check(HutFocus.pick_note(s2, b[1], "") == "", "and none when there was nothing else to pick")


func test_the_placement_picker_sits_by_the_ghost() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_three(s, p)
	var bounds := Rect2(Vector2.ZERO, Vector2(4000, 4000))
	var rects := HutFocus.pick_rects(s, p, bounds)
	t.check(rects["rows"].size() == 3 and bounds.encloses(rects["panel"]), "three rows, inside the map view")
	var ghost := Rect2(Vector2(p) * 48.0, Vector2(48, 48))
	t.check(rects["panel"].end.y <= ghost.position.y, "above the ghost, not over it")
	var wood: Rect2 = rects["rows"]["wood"]
	t.check(HutFocus.pick_at(s, p, bounds, wood.get_center()) == "wood", "a click on a row finds its resource")
	t.check(HutFocus.pick_at(s, p, bounds, ghost.get_center()) == "", "and one on the ghost finds none")
	t.check(
		HutFocus.pick_over(s, p, bounds, wood.get_center()), "the panel holds the ghost still while the mouse is on it"
	)
	t.check(not HutFocus.pick_over(s, p, bounds, ghost.get_center()), "the ghost tile is not the panel")
	var top := Rect2(Vector2(0, ghost.position.y - 10.0), Vector2(4000, 4000))
	t.check(
		HutFocus.pick_rects(s, p, top)["panel"].position.y >= ghost.end.y, "with no room above it goes below the ghost"
	)
	t.check(HutFocus.pick_rects(s, p, top)["panel"].end.y <= top.end.y, "and stays in the view")
	s.place("gatherers_hut", p)
	t.check(HutFocus.pick_rects(s, p, bounds).is_empty(), "a spot that is taken has no picker")


func test_the_panel_picker_sets_the_focus_and_the_save_keeps_it() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_three(s, p)
	s.place("gatherers_hut", p)
	var i: int = s.town.building_at[p]
	var b: Dictionary = s.town.buildings[i]
	var panel := HutFocus.new()
	panel.setup(s)
	panel.show_for(b)
	panel.pick("clay")
	t.check(b["focus"] == "clay" and b["gather_index"] == 0, "the panel picker sets Clay")
	t.check(HutFocus.pick_at(s, p, Rect2(0, 0, 4000, 4000), Vector2.ZERO) == "", "set_focus leaves no picker behind")
	var d := RunSave.dump(s)
	var copy := Sim.new()
	t.check(RunSave.restore(copy, RunSave.from_json(RunSave.to_json(d))), "a save with the picked hut loads")
	t.check(copy.town.buildings[copy.town.building_at[p]]["focus"] == "clay", "the hut is still on Clay")
	var again := HutFocus.new()
	again.setup(copy)
	again.show_for(copy.town.buildings[copy.town.building_at[p]])
	t.check(again.row.get_child(1).button_pressed, "and its button shows it pressed")
	again.free()
	panel.free()
