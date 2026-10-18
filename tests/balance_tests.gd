extends RefCounted
## The balance plan (design-system/24-balance.md): what the top bar's chips say when a good is running out, and the one
## famine card. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Economy = preload("res://scripts/economy.gd")
const Runway = preload("res://scripts/runway.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_runway_of_a_falling_good()
	test_the_runway_has_two_tones_and_a_clock_face()
	test_the_famine_card_comes_once_and_not_in_the_opening()
	test_the_famine_card_is_remembered_by_a_save()


func test_the_runway_of_a_falling_good() -> void:
	t.check(is_equal_approx(Runway.seconds(100, -0.5), 200.0), "100 at -0.5 a second lasts 200 seconds")
	t.check(Runway.seconds(100, 0.4) == INF, "a rising good never runs out")
	t.check(Runway.seconds(100, 0.0) == INF, "nor a steady one")
	t.check(Runway.seconds(100, -0.001) == INF, "a rate lost in the noise is steady")
	t.check(Runway.seconds(0, -0.5) == INF, "none is nothing to run out of: its chip is already dim")


func test_the_runway_has_two_tones_and_a_clock_face() -> void:
	t.check(Runway.tone(Data.RUNWAY_AMBER_SECONDS + 1.0) == Runway.Tone.NONE, "over five minutes is quiet")
	t.check(Runway.tone(Data.RUNWAY_AMBER_SECONDS - 1.0) == Runway.Tone.AMBER, "under five minutes is amber")
	t.check(Runway.tone(Data.RUNWAY_RED_SECONDS - 1.0) == Runway.Tone.RED, "under two minutes is red")
	t.check(Runway.text(250.0) == "4:10", "250 seconds reads 4:10")
	t.check(Runway.text(45.0) == "0:45", "45 seconds reads 0:45")
	t.check(Runway.text(600.0) == "" and Runway.text(INF) == "", "a good that is not running out says nothing")


func _short_of_food(clock: float) -> Economy:
	var e := Economy.new()
	e.flows.clock = clock
	e.inv["berries"] = 10
	e.food_credit = 0.0
	e.feed(4, 0.1)  # four mouths on 10 berries: well inside the famine point
	return e


func test_the_famine_card_comes_once_and_not_in_the_opening() -> void:
	var early := _short_of_food(Data.FORAGE_OPENING_SECONDS - 10.0)
	t.check(not early.take_famine_card(), "the opening is the player's: no card in it")
	var e := _short_of_food(Data.FORAGE_OPENING_SECONDS + 10.0)
	t.check(e.famine, "the test's food is short enough for a famine")
	t.check(e.take_famine_card(), "the first real famine puts the card up")
	t.check(not e.take_famine_card(), "and only once")
	e.inv["berries"] = 5000
	e.feed(4, 0.1)
	e.inv["berries"] = 10
	e.feed(4, 0.1)
	t.check(not e.take_famine_card(), "a second famine in the same run gets no card")
	t.check(not Economy.new().take_famine_card(), "no famine, no card")


func test_the_famine_card_is_remembered_by_a_save() -> void:
	var s: Sim = t.fresh()
	s.economy.famine_card_shown = true
	var copy := Sim.new()
	copy.generate(42)
	RunSave.restore(copy, RunSave.from_json(RunSave.to_json(RunSave.dump(s))))
	t.check(copy.economy.famine_card_shown, "a loaded run has had its famine card")
	var old: Dictionary = s.economy.to_dict()
	old.erase("famine_card_shown")
	var plain := Economy.new()
	plain.from_dict(old)
	t.check(not plain.famine_card_shown, "a save from before the card has not had one")
