extends RefCounted
## Starfall stage 3 (design-system/16-starfall.md): the three moments the strangers ask, the sixth set (the Warning) that
## ends the era, the lean it records and the first Bloom sign. Run from tests/run_tests.gd, which owns check().

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const MomentCard = preload("res://scripts/moment_card.gd")
const StarfallTests = preload("res://tests/starfall_tests.gd")

var t  # the runner, tests/run_tests.gd
var _h  # the stage 1 tests, for their town helpers


func run(runner) -> void:
	t = runner
	_h = StarfallTests.new()
	_h.t = runner
	test_the_moments_are_well_formed()
	test_a_moment_is_asked_after_its_set_is_read()
	test_the_hunger_costs_food_and_moves_trust()
	test_the_shards_lend_the_cairns_light_away()
	test_going_dark_slows_the_workshops()
	test_the_warning_waits_for_the_questions()
	test_the_warning_ends_the_era()
	test_the_lean_follows_trust()
	test_the_moment_card_has_a_button_per_choice()
	test_the_ending_saves()


## Stand every set before the Warning as read and every question answered but `leave`; the Warning's marks are on the Wall
## and guessed right.
func _at_the_end(leave := "") -> Sim:
	var s: Sim = _h._arrived()
	for n in [1, 2, 3, 4, 5]:
		s.starfall.locked[Data.GLYPH_SETS[n]["id"]] = true
	for id in Data.MOMENT_ORDER:
		if id != leave:
			s.starfall.answered[id] = 0
	for g in Data.GLYPH_SETS[6]["glyphs"]:
		s.starfall.copied.append(g)
		s.starfall.guesses[g] = Data.GLYPHS[g]["word"]
	return s


## Ask moment `id` now (as if its wait had run out).
func _ask(s: Sim, id: String) -> void:
	s.starfall.locked[Data.MOMENTS[id]["after"]] = true
	s.starfall.wait_clock = Data.MOMENTS[id]["wait"] - 0.5
	s.starfall.tick(1.0)


func test_the_moments_are_well_formed() -> void:
	var ids := []
	for n in Data.GLYPH_SETS:
		ids.append(Data.GLYPH_SETS[n]["id"])
	t.check(Data.ENDING_SET in ids and Data.GLYPH_SETS[6]["id"] == Data.ENDING_SET, "the Warning is the sixth set")
	t.check(Data.MOMENT_ORDER.size() == 3, "three moments")
	for id in Data.MOMENT_ORDER:
		var m: Dictionary = Data.MOMENTS[id]
		t.check(m["after"] in ids and m["wait"] > 0.0, "%s follows a real set" % id)
		t.check(m["options"].size() >= 2 and m["title"] != "" and m["text"] != "", "%s has a choice" % id)
		for opt in m["options"]:
			t.check(Data.STORY_EVENTS.has(opt["story"]), "%s is a story id" % opt["story"])
			t.check(
				opt["label"] != "" and opt["line"] != "" and opt["note"] != "", "%s says what it does" % opt["story"]
			)
			t.check(absf(opt["trust"]) <= 20.0, "%s moves trust by a step, not the whole meter" % opt["story"])
	for lean in Data.LEANS:
		t.check(Data.STORY_EVENTS.has(Data.LEANS[lean]), "%s is a story id" % Data.LEANS[lean])
	t.check(Data.STORY_EVENTS.has("bloom_seen") and Data.STORY_EVENTS.has("warning_read"), "the ending has its ids")
	t.check("Spread" in Data.GLYPH_WORDS, "the Warning's word can be guessed")
	t.check(
		Data.BONUSES.has("lights_out") and Data.BONUSES["lights_out"]["add"] < 0.0, "going dark slows the workshops"
	)


func test_a_moment_is_asked_after_its_set_is_read() -> void:
	var s: Sim = _h._arrived()
	t.check(
		s.starfall.pending == "" and s.starfall.next_moment() == "hunger", "nothing is asked before the name is read"
	)
	s.starfall.tick(Data.MOMENTS["hunger"]["wait"] + 5.0)
	t.check(s.starfall.pending == "", "and the wait does not run before then")
	s.starfall.locked["name"] = true
	s.starfall.tick(Data.MOMENTS["hunger"]["wait"] - 1.0)
	t.check(s.starfall.pending == "", "just short of the wait, nothing")
	s.starfall.tick(2.0)
	t.check(s.starfall.pending == "hunger", "then the Hunger is asked")
	s.starfall.locked["light"] = true
	s.starfall.tick(Data.MOMENTS["shards"]["wait"] + 5.0)
	t.check(s.starfall.pending == "hunger", "a second question waits for the first answer")
	t.check(not s.starfall.choose(9) and s.starfall.pending == "hunger", "a wrong index changes nothing")
	t.check(
		s.starfall.choose(0) and s.starfall.pending == "" and s.starfall.next_moment() == "shards",
		"answered, the next is the Shards"
	)
	t.check(not s.starfall.choose(0), "nothing waits to be answered")


func test_the_hunger_costs_food_and_moves_trust() -> void:
	var s: Sim = _h._arrived()
	s.economy.inv["berries"] = 100
	var before: float = s.starfall.trust
	_ask(s, "hunger")
	t.check(s.starfall.pending == "hunger", "the Hunger is up")
	s.starfall.choose(0)
	t.check(
		s.economy.inv["berries"] <= 62 and s.economy.inv["berries"] >= 58,
		"sharing takes about 40 food: %d" % s.economy.inv["berries"]
	)
	t.check(is_equal_approx(s.starfall.trust, before + 14.0), "and trust steps up")
	t.check(s.story.has_event("hunger_shared"), "the Chronicle keeps it")
	var h: Sim = _h._arrived()
	h.economy.inv["berries"] = 100
	h.starfall.trust = 50.0
	var h_before: float = h.starfall.trust
	_ask(h, "hunger")
	h.starfall.choose(1)
	t.check(
		h.economy.inv["berries"] == 100 and is_equal_approx(h.starfall.trust, h_before - 12.0),
		"holding back costs trust, not food"
	)
	t.check(h.story.has_event("hunger_held"), "and is kept too")
	var poor: Sim = _h._arrived()
	poor.economy.inv = {"berries": 5}
	_ask(poor, "hunger")
	poor.starfall.choose(0)
	t.check(poor.economy.inv["berries"] == 0, "short stores give what they have and no more")
	var low: Sim = _h._arrived()
	low.starfall.trust = 3.0
	_ask(low, "hunger")
	low.starfall.choose(1)
	t.check(low.starfall.trust == 0.0, "trust never goes below nothing")


func test_the_shards_lend_the_cairns_light_away() -> void:
	var s: Sim = _h._arrived()
	s.town.add_building("gatherers_hut", _h._spot(s, "gatherers_hut"))
	var hut: Dictionary = s.town.buildings[s.town.buildings.size() - 1]
	s.town.add_building("shard_cairn", hut["pos"] + Vector2i(2, 0))
	s.starfall.locked["light"] = true
	var lit := Bonuses.speed(s, hut)
	t.check(lit > 1.0, "the Cairn lights the hut")
	s.starfall.answered["hunger"] = 0
	_ask(s, "shards")
	t.check(s.starfall.pending == "shards", "the Shards are up")
	s.starfall.choose(0)
	t.check(
		s.starfall.dimmed() and is_equal_approx(Bonuses.speed(s, hut), lit - 0.25), "giving them dims the shardlight"
	)
	s.starfall.tick(Data.MOMENTS["shards"]["options"][0]["dim"] + 1.0)
	t.check(not s.starfall.dimmed() and is_equal_approx(Bonuses.speed(s, hut), lit), "and it comes back")
	var r: Sim = _h._arrived()
	r.starfall.trust = 50.0
	r.starfall.answered["hunger"] = 0
	_ask(r, "shards")
	var trust: float = r.starfall.trust
	r.starfall.choose(2)
	t.check(
		not r.starfall.dimmed() and is_equal_approx(r.starfall.trust, trust - 10.0),
		"refusing keeps the light and costs trust"
	)
	var traded: Sim = _h._arrived()
	traded.starfall.answered["hunger"] = 0
	_ask(traded, "shards")
	traded.starfall.choose(1)
	t.check(traded.starfall.dim_left < 61.0 and traded.starfall.dim_left > 0.0, "trading dims it only a little")


func test_going_dark_slows_the_workshops() -> void:
	var s: Sim = _h._arrived()
	s.town.add_building("kiln", _h._spot(s, "kiln"))
	var kiln: Dictionary = s.town.buildings[s.town.buildings.size() - 1]
	var plain := Bonuses.speed(s, kiln)
	s.starfall.answered["hunger"] = 0
	s.starfall.answered["shards"] = 0
	_ask(s, "warning")
	t.check(s.starfall.pending == "warning", "the Warning is up")
	s.starfall.choose(0)
	t.check(
		s.starfall.dark() and is_equal_approx(Bonuses.speed(s, kiln), plain - 0.5),
		"going dark halves a workshop's pace"
	)
	s.town.add_building("gatherers_hut", _h._spot(s, "gatherers_hut"))
	var hut: Dictionary = s.town.buildings[s.town.buildings.size() - 1]
	t.check(is_equal_approx(Bonuses.speed(s, hut), 1.0), "but gatherers work as before")
	s.starfall.tick(Data.MOMENTS["warning"]["options"][0]["dark"] + 1.0)
	t.check(not s.starfall.dark() and is_equal_approx(Bonuses.speed(s, kiln), plain), "and the fires come back")
	var k: Sim = _h._arrived()
	k.starfall.answered["hunger"] = 0
	k.starfall.answered["shards"] = 0
	_ask(k, "warning")
	k.starfall.choose(1)
	t.check(not k.starfall.dark(), "keeping the fires lit changes nothing but trust")


func test_the_warning_waits_for_the_questions() -> void:
	var s := _at_the_end("warning")
	t.check(
		not s.starfall.check() and not s.starfall.locked.has("warning"), "the Warning is not read with a question open"
	)
	_ask(s, "warning")
	t.check(not s.starfall.check() and s.starfall.pending == "warning", "nor while it waits for an answer")
	s.starfall.choose(0)
	t.check(s.starfall.check() and s.starfall.locked.has("warning"), "answered, it reads")
	t.check(s.starfall.ended and s.starfall.next_moment() == "", "and the era is over")


func test_the_warning_ends_the_era() -> void:
	var s := _at_the_end()
	s.starfall.wreck = Vector2i(s.world.width - 5, roundi(s.world.height / 2.0))
	s.starfall.trust = 50.0
	t.check(s.starfall.check(), "the Warning is read")
	t.check(s.starfall.pending == "ending", "the ending card is up")
	t.check(s.story.has_event("warning_read") and s.story.has_event("bloom_seen"), "the Chronicle has the end")
	t.check(s.starfall.bloom.x >= 0 and s.starfall.bloom != s.starfall.wreck, "a Bloom sign stands near the Wreck")
	t.check(s.fog.is_revealed(s.starfall.bloom), "and the fog is lifted round it")
	t.check(s.starfall.choose(0) and s.starfall.pending == "", "the one button puts the card away")
	t.check(s.starfall.check() == false and s.starfall.ended, "the era stays over")
	var no_wreck := _at_the_end()
	no_wreck.starfall.wreck = Vector2i(-1, -1)
	no_wreck.starfall.check()
	t.check(no_wreck.starfall.bloom.x < 0, "with no Wreck there is no place to put the sign")


func test_the_lean_follows_trust() -> void:
	for pair in [[90.0, "allies"], [70.0, "allies"], [50.0, "neighbours"], [35.0, "neighbours"], [10.0, "enemies"]]:
		var s := _at_the_end()
		s.starfall.trust = pair[0] - Data.TRUST_SET  # reading the set is worth a step
		s.starfall.check()
		t.check(s.starfall.lean == pair[1], "trust %d leans %s, not %s" % [pair[0], pair[1], s.starfall.lean])
		t.check(s.story.has_event(Data.LEANS[pair[1]]), "%s is recorded" % pair[1])


func test_the_moment_card_has_a_button_per_choice() -> void:
	var s: Sim = _h._arrived()
	var card := MomentCard.new()
	card.setup()
	card.open(s.starfall)
	t.check(not card.visible, "nothing is shown while nothing is asked")
	s.starfall.answered["hunger"] = 0
	_ask(s, "shards")
	card.open(s.starfall)
	t.check(
		card.visible and _buttons(card).size() == Data.MOMENTS["shards"]["options"].size(), "a button for each choice"
	)
	var got := []
	card.chose.connect(func(i): got.append(i))
	_buttons(card)[1].pressed.emit()
	t.check(got == [1] and not card.visible, "pressing one says which and puts the card away")
	var e := _at_the_end()
	e.starfall.check()
	card.open(e.starfall)
	t.check(card.visible and _buttons(card).size() == 1, "the ending has one button")
	card.free()


func _buttons(node: Node) -> Array:
	var out := []
	for c in node.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_buttons(c))
	return out


func test_the_ending_saves() -> void:
	var s := _at_the_end()
	s.starfall.wreck = Vector2i(s.world.width - 5, roundi(s.world.height / 2.0))
	s.starfall.check()
	s.starfall.dim_left = 12.0
	s.starfall.dark_left = 7.0
	var s2 := Sim.new()
	t.check(RunSave.restore(s2, RunSave.from_json(RunSave.to_json(RunSave.dump(s)))), "a save at the ending loads")
	t.check(s2.starfall.to_dict() == s.starfall.to_dict(), "the moments, the lean and the Bloom sign read back")
	t.check(
		s2.starfall.pending == "ending" and s2.starfall.ended and s2.starfall.lean == s.starfall.lean,
		"the card is still waiting"
	)
	var old := RunSave.dump(s)
	for key in ["pending", "answered", "wait_clock", "dim_left", "dark_left", "ended", "lean", "bloom"]:
		old["game"]["starfall"].erase(key)
	var s3 := Sim.new()
	t.check(RunSave.restore(s3, old) and s3.starfall.pending == "" and not s3.starfall.ended, "an older save loads")
