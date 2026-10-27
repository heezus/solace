extends RefCounted
## Step 7F, the old marks (scripts/old_ship.gd, Data.ENDINGS["old"], design-system/18-roadmap.md "Old marks as built"): three sets
## beyond the six, found at the first ship's site from the second run on; each shows its lore when read; The First Ship warms every
## later run; The Way Out reads only for friends. A first run has none of it. Run from tests/telling_tests.gd.

const Carry = preload("res://scripts/carry.gd")
const Data = preload("res://scripts/data.gd")
const Expedition = preload("res://scripts/expedition.gd")
const ExpeditionTests = preload("res://tests/expedition_tests.gd")
const GlyphPicker = preload("res://scripts/glyph_picker.gd")
const Land = preload("res://scripts/land.gd")
const OldShip = preload("res://scripts/old_ship.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Sim = preload("res://scripts/sim.gd")
const StarfallTests = preload("res://tests/starfall_tests.gd")

var t  # the runner, tests/run_tests.gd
var _x: ExpeditionTests


func run(runner) -> void:
	t = runner
	_x = ExpeditionTests.new()
	_x.t = runner
	_x._h = StarfallTests.new()
	_x._h.t = runner
	test_the_old_sets_open_by_run()
	test_a_first_run_has_none_of_it()
	test_the_first_ship_lies_where_a_party_can_go()
	test_a_party_brings_the_old_marks_home()
	test_the_old_marks_are_guessed_among_themselves()
	test_the_first_ship_warms_the_next_run()
	test_the_way_out_needs_friends()
	test_the_old_marks_are_well_formed()
	test_the_site_saves()


## A run after `exodus` endings, the star landed and the strangers arrived, a Post standing and the name read.
func _later(exodus := 1, ending := "exodus") -> Sim:
	var s := Sim.new()
	s.generate(2)
	s.carry.exodus = exodus
	s.carry.ending = ending
	s.tech_tree.researched["bronze_dawn"] = true
	Land.grow_if_due(s)
	s.fog.reveal_all()
	t.give(s, 200)
	s.story.record("star_falling")
	for i in int(Data.LANDING_DELAY + Data.ARRIVAL_DELAY):
		s.starfall.tick(1.0)
	s.starfall.locked["name"] = true
	s.story.record("name_read")
	s.town.add_building("expedition_post", _x._h._spot(s, "expedition_post"))
	return s


func _ids(d: Dictionary) -> Array:
	return d.keys()


func _guess(s: Sim, set_n: int) -> void:
	_x._guess_right(s, Data.ENDINGS["old"]["sets"][set_n]["glyphs"])


func test_the_old_sets_open_by_run() -> void:
	var f := Sim.new().starfall
	t.check(OldShip.sets(f).is_empty(), "run 1: no old set")
	f.carry.exodus = 1
	t.check(_ids(OldShip.sets(f)) == [7], "run 2: The First Ship")
	f.carry.exodus = 2
	t.check(_ids(OldShip.sets(f)) == [7, 8], "run 3: and What Broke")
	f.carry.exodus = 3
	t.check(_ids(OldShip.sets(f)) == [7, 8, 9], "run 4: and The Way Out")
	f.carry.exodus = 1
	f.carry.ending = "cataclysm"
	t.check(_ids(OldShip.sets(f)) == [7, 8], "a Cataclysm brings What Broke a run early")
	t.check(OldShip.all_sets(f).size() == 8, "beside the six")
	t.check(Data.GLYPH_SETS.size() == 6, "the six are untouched")


func test_a_first_run_has_none_of_it() -> void:
	var s := Sim.new()
	s.generate(2)
	s.tech_tree.researched["bronze_dawn"] = true
	Land.grow_if_due(s)
	s.story.record("star_falling")
	t.check(s.starfall.old_ship == Vector2i(-1, -1), "no first ship's site in a first run")
	t.check(not Expedition.target_tile(s, "old_ship").x >= 0, "a party has nowhere to go there")
	t.check(not s.starfall.orders["target"] == "old_ship", "the order is the crash site")
	var f := s.starfall
	t.check(OldShip.words_for("g_star") == Data.GLYPH_WORDS, "the words to try are the old list")
	t.check(f.carry.start_trust(Data.TRUST_START_WARY) == Data.TRUST_START_WARY, "and the trust start is as it was")
	t.check(Carry.earned(s)["marks"].is_empty(), "nothing is carried")


func test_the_first_ship_lies_where_a_party_can_go() -> void:
	var s := _later()
	var p: Vector2i = s.starfall.old_ship
	t.check(p.x >= 0, "run 2 has a first ship's site")
	t.check(OldShip.tile(s) == p, "the same tile every time")
	var d := maxi(absi(p.x - s.world.camp_pos.x), absi(p.y - s.world.camp_pos.y))
	t.check(
		d >= Data.ENDINGS["old"]["site_near"] and d <= Data.ENDINGS["old"]["site_far"],
		"a way out from the Hearth (%d tiles)" % d
	)
	t.check(p != s.starfall.wreck, "and not the crash site")
	t.check(Expedition.target_tile(s, "old_ship").x >= 0, "a party can walk to it")
	t.check(Data.TARGET_ORDER.has("old_ship"), "the Post lists it")


func test_a_party_brings_the_old_marks_home() -> void:
	var s := _later()
	s.starfall.orders["target"] = "old_ship"
	var plan := Expedition.plan(s)
	t.check(plan["ok"], "a party can go: " + str(plan["why"]))
	Expedition.send(s)
	_x._run(s, 900.0, func(): return _x._back(s))
	t.check(_x._back(s), "the party came home")
	t.check(
		s.starfall.old_ship_found and s.story.events.has("old_ship_found"), "the first ship is found, a story moment"
	)
	t.check(s.starfall.copied.size() == Data.PACKS["standard"]["finds"], "the pack's finds are on the Wall")
	t.check(
		s.starfall.copied.all(func(g): return g in Data.ENDINGS["old"]["sets"][7]["glyphs"]), "all of The First Ship"
	)
	t.check(s.events.any(func(e): return e.contains("first ship")), "and the log says so")
	for i in 3:
		Expedition.send(s)
		_x._run(s, 900.0, func(): return _x._back(s))
	t.check(
		s.starfall.copied.size() == 3 and not OldShip.has_more(s.starfall),
		"three marks, the whole set, and no more to find"
	)
	t.check(not Expedition.plan(s)["ok"], "a party has nothing more to find")
	t.check(s.starfall.wreck_has_more(), "while the crash site still holds its own")


func test_the_old_marks_are_guessed_among_themselves() -> void:
	var s := _later()
	s.starfall.locked["light"] = true
	s.starfall.locked["body"] = true  # Hurt and Heal are read among the six
	var f := s.starfall
	OldShip.add_finds(f, 3)
	t.check(f.copied.size() == 3, "The First Ship is on the Wall")
	var kin: String = Data.ENDINGS["old"]["sets"][7]["glyphs"][1]
	var tries := 0
	while f.guesses.get(kin, "") != "Kin" and tries < 40:
		f.cycle_guess(kin)
		tries += 1
	t.check(
		f.guesses.get(kin, "") == "Kin", "Kin can be reached though the first set's Kin is read (%d clicks)" % tries
	)
	_guess(s, 7)
	t.check(f.check(), "set 7 is read when all three are right")
	t.check(f.locked.has("ship") and s.story.events.has("ship_read"), "and the story notes it")
	t.check(not f.locked.has("warning"), "the Warning does not wait on it and is not touched")
	t.check(OldShip.words_for("g_star").size() == Data.GLYPH_WORDS.size(), "the six sets keep the 21 words")
	t.check(OldShip.words_for(kin).size() == Data.GLYPH_WORDS.size() + 3, "the old marks add three")


func test_the_first_ship_warms_the_next_run() -> void:
	var s := _later()
	OldShip.add_finds(s.starfall, 3)
	_guess(s, 7)
	s.starfall.check()
	var earned := Carry.earned(s)
	t.check(earned["marks"].has("g_ship"), "the old marks read are carried on")
	var next := Carry.new()
	next.marks = earned["marks"]
	t.check(
		next.start_trust(Data.TRUST_START_WARY) == Data.TRUST_START_WARY + Data.ENDINGS["old"]["warm"],
		"the strangers begin one step warmer"
	)
	next.ending = "cataclysm"
	t.check(next.start_trust(0.0) == Data.ENDINGS["old"]["warm"], "even after a Cataclysm")
	next.ending = "loop"
	next.last_trust = 99.0
	t.check(next.start_trust(0.0) <= Data.TRUST_MAX, "and never above the top")
	t.check(Carry.new().start_trust(20.0) == 20.0, "an empty carry begins as always")


func test_the_way_out_needs_friends() -> void:
	var s := _later(3)
	var f := s.starfall
	OldShip.add_finds(f, 9)
	t.check(f.copied.size() == 9, "all the old marks are on the Wall")
	_guess(s, 9)
	f.trust = 5.0
	t.check(f.lean_now() != "allies", "the strangers are not friends yet")
	f.check()
	t.check(not f.locked.has("way"), "The Way Out waits")
	f.trust = 90.0
	t.check(f.lean_now() == "allies", "now they are")
	f.check()
	t.check(f.locked.has("way") and s.story.events.has("way_read"), "and it is read")


func test_the_old_marks_are_well_formed() -> void:
	var list: Array = Data.GLYPH_WORDS + Data.ENDINGS["old"]["words"]
	var seen := {}
	for n in Data.ENDINGS["old"]["sets"]:
		var gset: Dictionary = Data.ENDINGS["old"]["sets"][n]
		var words := {}
		for g in gset["glyphs"]:
			t.check(Data.GLYPHS.has(g) and not seen.has(g), "%s is one mark" % g)
			seen[g] = true
			words[Data.GLYPHS[g]["word"]] = true
			t.check(Data.GLYPHS[g]["word"] in list, "%s: its word can be guessed" % g)
			t.check(Data.GLYPHS[g]["found"].size() == 3, "%s says where it was found, three ways" % g)
		t.check(words.size() == 3, "%s: three different words" % gset["id"])
		t.check(Data.STORY_EVENTS.has(gset["id"] + "_read"), "%s has a story id" % gset["id"])
	for id in ["kin_reveal", "broken_world", "way_out"]:
		t.check(
			Data.CUTSCENES.has(id) and Data.CUTSCENES[id]["triggers"].size() == 1, "%s plays when its set is read" % id
		)
	t.check(Data.ENDINGS["old"]["words"].size() <= 3, "at most three new words")


func test_the_site_saves() -> void:
	var s := _later()
	s.starfall.old_ship_found = true
	var back := Sim.new()
	back.generate(2)
	t.check(RunSave.restore(back, RunSave.from_json(RunSave.to_json(RunSave.dump(s)))), "the run restores")
	t.check(
		back.starfall.old_ship == s.starfall.old_ship and back.starfall.old_ship_found,
		"the first ship's site is kept in a save"
	)
