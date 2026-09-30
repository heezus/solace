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
	test_ties_go_to_the_larger_group_then_the_fixed_order()
	test_a_hut_with_nothing_near_has_no_focus()
	test_cycling_and_setting_the_focus()
	test_a_hut_gathers_only_its_focus()
	test_the_berries_goal_needs_a_hut_on_berries()
	test_job_and_bundle_follow_the_focus()
	test_the_panel_line_and_the_range_text()
	test_the_focus_survives_a_save()
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


func test_ties_go_to_the_larger_group_then_the_fixed_order() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	_put(s, p + Vector2i(1, 0), "berry")
	_put(s, p + Vector2i(-1, 0), "tree")
	t.check(s.town.default_focus(p) == "wood", "one of each at the same distance: the first in item order, Wood")
	_put(s, p + Vector2i(0, 1), "berry")
	t.check(s.town.default_focus(p) == "berries", "but two Berry Bushes at that distance beat one tree")
	var again := _arena()
	var s2: Sim = again[0]
	_put(s2, again[1] + Vector2i(1, 0), "berry")
	_put(s2, again[1] + Vector2i(-1, 0), "tree")
	t.check(s2.town.default_focus(again[1]) == "wood", "the same layout always gives the same focus")


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
		String(goal["text"]).contains("Berry Bushes") and String(goal["text"]).contains("one resource"),
		"and the goal says a hut works one resource, and how to switch it"
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
	t.check(line.contains("It works only Berries"), "the hut's range line names what it works: " + line)


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
	t.check(HutFocus.label_text(s, b).contains("click to change"), "and hints that a click changes it")
	var button := HutFocus.new()
	button.setup(s)
	button.show_for(b)
	t.check(
		button.visible and button.text.begins_with("Gathering: Berries") and not button.disabled, "the panel button"
	)
	button.cycle()
	t.check(b["focus"] == "wood", "one click cycles the focus to the next item")
	button.show_for(b)
	t.check(button.text.begins_with("Gathering: Wood"), "and the line follows")
	button.free()
	var hearth := HutFocus.new()
	hearth.setup(s)
	hearth.show_for(s.town.buildings[0])
	t.check(not hearth.visible, "the Hearth has no focus line")
	hearth.free()
	t.check(
		BuildingPanel.gather_text(s, s.town.gather_tiles(p), "berries").ends_with("It works only Berries."),
		"the hover text says what the hut works"
	)


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
