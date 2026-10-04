extends RefCounted
## What a Field is for, in words (playtest 2026-10-03: "I'm not sure what the purpose of building more fields is"), and how
## close the food is to the next birth. Text from fixture states: no hut in reach, a hut on another resource, a hut with a
## worker, the Calendar's share, the build card's count, and the growth readout through its states. Run from
## tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const FieldText = preload("res://scripts/field_text.gd")
const GrowthNote = preload("res://scripts/growth_note.gd")
const Patch = preload("res://scripts/patch.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_a_field_with_no_hut_says_where_to_put_one()
	test_a_field_names_the_hut_that_reaps_it_and_what_it_brings()
	test_a_hut_on_another_resource_is_named()
	test_what_a_field_pays_over_the_wild_plant()
	test_the_build_card_counts_fields_with_no_hut()
	test_placing_and_dragging_say_whether_a_hut_reaches()
	test_the_growth_readout_walks_through_its_states()
	test_the_readout_stays_quiet_before_a_hut_and_a_dwelling()


## A game with a cleared square of grass (radius 4) away from the Hearth. Returns [game, centre].
func _arena() -> Array:
	var s: Sim = t.fresh()
	t.give(s, 100)
	var c := s.world.camp_pos
	var at := c + Vector2i(9, 0)
	if not s.world.in_bounds(at + Vector2i(5, 5)):
		at = c - Vector2i(9, 0)
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			s.world.set_tile(at + Vector2i(dx, dy), "grass")
	return [s, at]


## A hut at `p` that works grain with a Kith at it, and `n` fields in a row beside it.
func _hut_on_fields(s: Sim, p: Vector2i, n: int) -> Dictionary:
	for i in n:
		s.world.add_field(p + Vector2i(1 + i % 2, -1 + floori(i / 2.0)))
	t.check(t.place_free(s, "gatherers_hut", p), "the hut goes down")
	var b: Dictionary = s.town.buildings[s.town.building_at[p]]
	s.town.set_focus(s.town.building_at[p], "grain")
	b["worker"] = 0
	return b


func test_a_field_with_no_hut_says_where_to_put_one() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	s.world.add_field(p)
	var text := FieldText.tile_text(s, p)
	t.check(text.begins_with("No hut in reach: put a Gatherer's Hut within 2 tiles."), "no hut: " + text)
	t.check(FieldText.tile_text(s, p + Vector2i(1, 0)) == "", "a tile that is not a field says nothing here")
	t.check(Patch.huts_reaching(s, p).is_empty(), "and no hut reaches it")
	t.check(Patch.huts_reaching(s, p + Vector2i(5, 0)).is_empty(), "far from every hut still says none")


func test_a_field_names_the_hut_that_reaps_it_and_what_it_brings() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	var b := _hut_on_fields(s, p, 3)
	var field := p + Vector2i(1, -1)
	var rate := Patch.per_minute(s, b, s.town.focus_tiles(b), "grain")
	t.check(rate > 0.0, "a hut on three grain tiles brings grain (%.1f a minute)" % rate)
	var text := FieldText.hut_line(s, field, "grain")
	t.check(text.begins_with("A hut with a worker reaps it: about "), "line: " + text)
	t.check(text.contains("%s Grain a minute" % FieldText.num(rate)), "it quotes the hut's live rate: " + text)
	t.check(text.contains("from the 3 tiles in its reach"), "and how many tiles it has: " + text)
	b["worker"] = -1
	t.check(
		FieldText.hut_line(s, field, "grain") == Data.FIELD_HUT_EMPTY % Data.PEOPLE["one"],
		"with no worker yet it says so: " + FieldText.hut_line(s, field, "grain")
	)
	var second := p + Vector2i(0, 3)
	t.check(t.place_free(s, "gatherers_hut", second), "a second hut")
	var between := p + Vector2i(1, 2)
	s.world.add_field(between)
	s.town.set_focus(s.town.building_at[second], "grain")
	s.town.buildings[s.town.building_at[second]]["worker"] = 1
	b["worker"] = 0
	var both := Patch.huts_reaching(s, between)
	t.check(both.size() == 2, "two huts reach a field between them (%d)" % both.size())
	t.check(FieldText.hut_line(s, between, "grain").begins_with("2 huts reap it"), "the line counts them")


func test_a_hut_on_another_resource_is_named() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	s.world.set_tile(p + Vector2i(-1, 0), "berry")
	var b := _hut_on_fields(s, p, 1)
	s.town.set_focus(s.town.building_at[p], "berries")
	var text := FieldText.hut_line(s, p + Vector2i(1, -1), "grain")
	t.check(text == Data.FIELD_HUT_OTHER % ["Berries", "Grain"], "the hut works Berries, not Grain: " + text)
	t.check(b["focus"] == "berries", "fixture: the hut is on berries")


func test_what_a_field_pays_over_the_wild_plant() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	s.world.add_field(p)
	var text := FieldText.yield_line(s, p, "grain")
	t.check(text.contains("Calendar") and text.contains("+25%"), "before Calendar: which tech pays more: " + text)
	s.tech_tree.researched["calendar"] = true
	t.check(FieldText.yield_line(s, p, "grain").contains("25% more Grain a harvest"), "Calendar: 25% more")
	s.tech_tree.researched["plough"] = true
	t.check(FieldText.yield_line(s, p, "grain").contains("75% more"), "and the Plough's 50% on top: 75%")
	t.check(
		FieldText.mill_line("grain").contains("Grindstone"), "grain says it is milled: " + FieldText.mill_line("grain")
	)
	t.check(FieldText.mill_line("berries") == "", "berries are eaten raw: nothing to mill")


func test_the_build_card_counts_fields_with_no_hut() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	t.check(FieldText.card_text(s, "grain").begins_with(Data.FIELD_CARD_NONE), "no fields yet says so")
	_hut_on_fields(s, p, 2)
	s.world.add_field(p + Vector2i(4, 4))
	var text := FieldText.card_text(s, "grain")
	t.check(text.begins_with("1 of your 3 fields have no hut within 2 tiles."), "one idle of three: " + text)
	t.check(text.contains("Gatherer's Hut within 2 tiles that works Grain"), "and what a field needs: " + text)
	s.world.remove_field(p + Vector2i(4, 4))
	t.check(FieldText.card_text(s, "grain").begins_with("All 2 of your fields are in reach of a hut."), "all reached")


func test_placing_and_dragging_say_whether_a_hut_reaches() -> void:
	var a := _arena()
	var s: Sim = a[0]
	var p: Vector2i = a[1]
	t.check(
		FieldText.placing_text(s, p) == Data.FIELD_NO_HUT % 2,
		"placing with no hut near: " + FieldText.placing_text(s, p)
	)
	_hut_on_fields(s, p, 1)
	t.check(
		FieldText.placing_text(s, p + Vector2i(0, 2)) == "In reach of 1 hut: a hut works it.", "placing next to a hut"
	)
	s.tech_tree.researched["farming"] = true
	var line: Array = [p + Vector2i(0, 1), p + Vector2i(0, 2), p + Vector2i(0, 4)]
	t.check(FieldText.drag_note(s, line) == "2 in reach of a hut", "a drag counts the tiles a hut reaches")
	t.check(FieldText.drag_note(s, [p + Vector2i(0, 4)]) == Data.FIELD_DRAG_NONE, "and says none when none")


## A camp with a hut and a Dwelling (the readout waits for both), fed by hand second by second.
func _growth_game() -> Sim:
	var s: Sim = t.fresh()
	var camp: Vector2i = s.world.camp_pos
	t.check(t.place_free(s, "gatherers_hut", camp + Vector2i(0, 2)), "a hut goes up")
	t.check(t.place_free(s, "dwelling", camp + Vector2i(2, 2)), "a Dwelling goes up")
	s.economy.inv["berries"] = 60
	return s


func _second(s: Sim, income: float) -> void:
	s.economy.advance(1.0)
	if income > 0.0:
		s.economy.note("berries", income, "gatherers_hut")
		s.economy.add("berries", roundi(income))
	var fed: bool = s.economy.feed(s.people.kith.size(), 1.0)
	s.people.grow(1.0, fed)


func test_the_growth_readout_walks_through_its_states() -> void:
	var s := _growth_game()
	for i in 10:
		_second(s, 0.0)
	t.check(
		GrowthNote.progress_text(s) == "Counting what your huts bring in: 10 of 30 s",
		"counting first: " + GrowthNote.progress_text(s)
	)
	for i in 30:
		_second(s, 0.0)
	var use: float = s.economy.food_use
	var text := GrowthNote.progress_text(s)
	var want := "Needs +%s more food a minute to grow" % str(snappedf(use * 60.0, 0.1))
	t.check(text == want, "no income: say how much is missing (%s): %s" % [want, text])
	t.check(is_equal_approx(use * 60.0, 3.6), "three Kith eat 3.6 food a minute (%.2f)" % (use * 60.0))
	var s2 := _growth_game()
	for i in 45:
		_second(s2, 1.0)  # one berry a second: far more than they eat
	var steady: String = GrowthNote.progress_text(s2)
	var held: int = int(s2.economy.steady_held)
	t.check(held > 0 and held < 35, "the hold is counting up (%d s)" % held)
	var left := ceili(35.0 - s2.economy.steady_held + s2.people.grow_time())
	t.check(
		steady == "Steady food %d of 35 s, then a Kith in about %d s" % [held, left],
		"covered: how far through the hold, and the wait to the birth: " + steady
	)
	s2.economy.steady_held = 35.0
	s2.people.grow_timer = 4.0
	t.check(
		GrowthNote.progress_text(s2) == "Next Kith in about 8 s", "birth counting down: " + GrowthNote.progress_text(s2)
	)
	s2.economy.inv["berries"] = 0
	s2.economy.food_credit = 0.0
	t.check(
		(
			GrowthNote.progress_text(s2).begins_with("Needs ")
			and GrowthNote.progress_text(s2).ends_with("in the stockpile to grow")
		),
		"stockpile too small for a birth: " + GrowthNote.progress_text(s2)
	)
	var tip := GrowthNote.progress_tip(s2)
	t.check(tip.contains("food a minute") and tip.contains("Hands and foraging don't count"), "tooltip: " + tip)
	s2.economy.starving = true
	t.check(GrowthNote.progress_text(s2) == "", "starving: the note beside the count says it")
	s2.economy.starving = false
	while s2.people.kith.size() < s2.town.housing():
		s2.people.add_kith()
	t.check(GrowthNote.progress_text(s2) == "", "no room: the note says so, the readout adds nothing")


func test_the_readout_stays_quiet_before_a_hut_and_a_dwelling() -> void:
	var s: Sim = t.fresh()
	t.check(GrowthNote.progress_text(s) == "", "second one: nothing")
	t.check(GrowthNote.progress_tip(s) == "", "and no tooltip line")
	t.check(t.place_free(s, "gatherers_hut", s.world.camp_pos + Vector2i(0, 2)), "a hut alone")
	t.check(GrowthNote.progress_text(s) == "", "still nothing without a Dwelling")
