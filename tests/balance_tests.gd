extends RefCounted
## The balance plan (design-system/24-balance.md): what the top bar's chips say when a good is running out, and the one
## famine card. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Economy = preload("res://scripts/economy.gd")
const Runway = preload("res://scripts/runway.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Storage = preload("res://scripts/storage.gd")

## The goods the land gives. A price over RAW_PRICE_CAP of one of these says nothing about the world: ask for made goods.
const RAW_GOODS := [
	"wood",
	"stone",
	"flint",
	"fiber",
	"clay",
	"berries",
	"grain",
	"fish",
	"copper_ore",
	"tin",
	"coal",
	"iron_ore",
	"shard",
	"copper"
]
const RAW_PRICE_CAP := 60

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_runway_of_a_falling_good()
	test_the_runway_has_two_tones_and_a_clock_face()
	test_the_famine_card_comes_once_and_not_in_the_opening()
	test_the_famine_card_is_remembered_by_a_save()
	test_no_price_asks_for_a_pile_of_a_raw_good()
	test_the_stockpile_has_a_cap_that_grows()
	test_a_full_stockpile_spills_and_a_refund_does_not()
	test_food_spoils_above_the_floor_and_preservation_halves_it()
	test_a_price_can_always_be_saved_for()
	test_the_bloom_leaves_the_stores_alone()


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


func test_no_price_asks_for_a_pile_of_a_raw_good() -> void:
	var over: Array = []
	for source in [Data.TECHS, Data.BUILDINGS]:
		for id in source:
			var cost: Dictionary = source[id].get("cost", {})
			for item in cost:
				if item in RAW_GOODS and cost[item] > RAW_PRICE_CAP:
					over.append("%s asks %d %s" % [id, cost[item], item])
	t.check(over.is_empty(), "no tech or building asks over %d of a raw good: %s" % [RAW_PRICE_CAP, ", ".join(over)])


func test_the_stockpile_has_a_cap_that_grows() -> void:
	var researched := {}
	t.check(
		Storage.capacity("tin", 0, researched) == Data.STORAGE_BASE,
		"the Hearth holds the base of a good with a small price"
	)
	t.check(
		Storage.capacity("tin", 2, researched) == Data.STORAGE_BASE + 2 * Data.STORAGE_PER_STOREHOUSE,
		"each Storehouse adds its share"
	)
	var many := Storage.capacity("tin", 20, researched)
	t.check(many == Data.STORAGE_BASE + Data.STORAGE_STOREHOUSE_MAX * Data.STORAGE_PER_STOREHOUSE, "up to six count")
	researched["granaries"] = true
	t.check(
		Storage.capacity("tin", 20, researched) == many + Data.STORAGE_TECHS["granaries"], "and a tech adds its own"
	)
	var s: Sim = t.fresh()
	s.tick(0.1)
	t.check(s.economy.caps["tin"] == Data.STORAGE_BASE, "a new game's stockpile is capped from its first tick")
	var storehouse: Vector2i = s.world.camp_pos + Vector2i(3, 0)
	t.give(s, 500)
	t.place_free(s, "storehouse", storehouse)
	s.tick(0.1)
	t.check(
		s.economy.caps["tin"] == Data.STORAGE_BASE + Data.STORAGE_PER_STOREHOUSE, "a built Storehouse raises the cap"
	)


func test_a_full_stockpile_spills_and_a_refund_does_not() -> void:
	var e := Economy.new()
	e.caps = {"wood": 100}
	e.add("wood", 80)
	e.add("wood", 50)
	t.check(e.inv["wood"] == 100 and e.spilled == 30, "what comes in over the cap is lost and counted")
	t.check(e.is_full("wood"), "the chip says full at the cap")
	e.give_back("wood", 40)
	t.check(e.inv["wood"] == 140, "a refund is the player's own and never spills")
	e.add("wood", 10)
	t.check(e.inv["wood"] == 140, "a stock over the cap is never taken down, and gains nothing")
	t.check(Economy.new().caps.is_empty(), "a bare Economy has no limit")


func test_food_spoils_above_the_floor_and_preservation_halves_it() -> void:
	var e := Economy.new()
	e.inv["berries"] = Data.SPOIL_FLOOR
	e.spoil(600.0)
	t.check(e.inv["berries"] == Data.SPOIL_FLOOR, "the small stock the people live on is never taxed")
	e.inv["berries"] = Data.SPOIL_FLOOR + 1000
	e.spoil(60.0)
	t.check(e.inv["berries"] == Data.SPOIL_FLOOR + 1000 - 20, "2% of the stock above the floor goes in a minute")
	t.check(e.flows.now.get("berries|spoil", 0.0) == -20.0, "and shows in the flows as spoilage")
	var kept := Economy.new({"preservation": true})
	kept.inv["berries"] = Data.SPOIL_FLOOR + 1000
	kept.spoil(60.0)
	t.check(kept.inv["berries"] == Data.SPOIL_FLOOR + 1000 - 10, "Preservation halves it")
	var other := Economy.new()
	other.inv["stone"] = 1000
	other.spoil(600.0)
	t.check(other.inv["stone"] == 1000, "stone does not spoil")


func test_a_price_can_always_be_saved_for() -> void:
	var s: Sim = t.fresh()
	s.tick(0.1)
	for source in [Data.TECHS, Data.BUILDINGS]:
		for id in source:
			var cost: Dictionary = source[id].get("cost", {})
			for item in cost:
				t.check(s.economy.caps[item] >= cost[item], "%s: the cap on %s fits its price" % [id, item])


func test_the_bloom_leaves_the_stores_alone() -> void:
	var s: Sim = t.fresh()
	t.give(s, 100)
	var at: Vector2i = s.world.camp_pos + Vector2i(3, 0)
	t.place_free(s, "storehouse", at)
	s.tide.begun = true
	s.tide.grown[at] = true
	s.tide.hit[at] = 0.0
	var before := s.economy.inv.duplicate()
	for i in 121:
		s.tide.tick(s, 1.0)
	t.check(s.tide.hit.has(at), "the building stands overgrown, not yet lost")
	t.check(s.economy.inv == before, "and the Bloom has taken nothing from the stores")
	var copy := Sim.new()
	copy.generate(42)
	copy.tide.from_dict(s.tide.to_dict())
	t.check(not copy.tide.to_dict().has("eaten"), "and there is no tally of goods eaten to save")
