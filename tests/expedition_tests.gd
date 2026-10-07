extends RefCounted
## Starfall stage 2 (design-system/16-starfall.md): the Expedition Post, parties, the Wreck, the marks of sets 2 to 5 and the
## gifts of reading them. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const CardText = preload("res://scripts/card_text.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Land = preload("res://scripts/land.gd")
const Expedition = preload("res://scripts/expedition.gd")
const ExpeditionPicker = preload("res://scripts/expedition_picker.gd")
const GlyphPicker = preload("res://scripts/glyph_picker.gd")
const StarfallTests = preload("res://tests/starfall_tests.gd")

var t  # the runner, tests/run_tests.gd
var _h  # the stage 1 tests, for their town helpers


func run(runner) -> void:
	t = runner
	_h = StarfallTests.new()
	_h.t = runner
	test_sets_two_to_five_are_well_formed()
	test_the_post_opens_with_the_name_and_the_wall_copies_only_survivor_marks()
	test_finds_come_in_set_order()
	test_guesses_skip_words_already_read()
	test_a_party_goes_to_the_wreck_and_brings_marks_home()
	test_a_late_party_brings_less()
	test_the_plan_says_why_not()
	test_keep_sending_sends_again()
	test_the_fog_trip_gives_a_wide_look()
	test_the_gifts_work()
	test_the_post_and_wall_panels_say_things()
	test_the_expedition_saves()


## The east half of the map, grown as at Bronze Dawn, on a seed whose Wreck can be walked to (the river is crossable on it).
func _grown(fogged := false) -> Sim:
	var s := Sim.new()
	s.generate(2)
	s.tech_tree.researched["bronze_dawn"] = true
	Land.grow_if_due(s)
	if not fogged:
		s.fog.reveal_all()
	t.give(s, 200)
	s.story.record("star_falling")
	for i in int(Data.LANDING_DELAY + Data.ARRIVAL_DELAY):
		s.starfall.tick(1.0)
	return s


## A grown town after the strangers arrived, a stocked stockpile, the name read and a Post standing.
func _ready_town() -> Sim:
	var s := _grown()
	s.starfall.locked["name"] = true
	s.story.record("name_read")
	s.town.add_building("expedition_post", _h._spot(s, "expedition_post"))
	return s


## Run the whole game `seconds` forward in half-second steps, until `done` is true.
func _run(s: Sim, seconds: float, done: Callable) -> void:
	for i in int(seconds * 2.0):
		s.tick(0.5)
		if done.call():
			return


func _back(s: Sim) -> bool:
	return Expedition.count(s) == 0


func _guess_right(s: Sim, ids: Array) -> void:
	for g in ids:
		while s.starfall.guesses.get(g, "") != Data.GLYPHS[g]["word"]:
			s.starfall.cycle_guess(g)


func test_sets_two_to_five_are_well_formed() -> void:
	t.check(Data.GLYPH_SETS.size() == 6, "six sets")
	var seen := {}
	for n in Data.GLYPH_SETS:
		var gset: Dictionary = Data.GLYPH_SETS[n]
		t.check(gset["source"] in ["survivors", "wreck"], "%s has a source" % gset["id"])
		t.check(gset["glyphs"].size() == 3, "%s has three marks" % gset["id"])
		t.check(
			n == 1 or gset["id"] == Data.ENDING_SET or Data.LUMEN_GIFTS.has(gset["id"]), "%s has a gift" % gset["id"]
		)
		for g in gset["glyphs"]:
			t.check(Data.GLYPHS.has(g) and not seen.has(g), "%s is one mark, in one set" % g)
			seen[g] = true
			var word: String = Data.GLYPHS[g]["word"]
			t.check(word in Data.GLYPH_WORDS, "%s: the word %s can be guessed" % [g, word])
			t.check(Data.GLYPHS[g]["found"].size() == 3, "%s says where it was found, three ways" % g)
			t.check(Data.GLYPHS[g]["strokes"].size() >= 1, "%s can be drawn" % g)
	t.check(Data.GLYPH_SETS[1]["source"] == "survivors", "the first set comes from the strangers")
	for id in Data.PACK_ORDER:
		t.check(Data.PACKS.has(id) and Data.PACKS[id]["finds"] >= 1, "%s is a pack" % id)
		for item in Data.PACKS[id]["cost"]:
			t.check(Data.ITEMS.has(item), "%s costs a real good" % id)
	for id in Data.BONUSES:
		t.check(
			not Data.BONUSES[id].has("gift") or Data.LUMEN_GIFTS.has(Data.BONUSES[id]["gift"]),
			"%s names a real gift" % id
		)


func test_the_post_opens_with_the_name_and_the_wall_copies_only_survivor_marks() -> void:
	var s: Sim = _h._arrived()
	t.check(not CardText.shown(s, "expedition_post"), "no Post card before the name is read")
	s.starfall.locked["name"] = true
	s.story.record("name_read")
	t.check(CardText.shown(s, "expedition_post"), "the Post opens once the name is read")
	s.starfall.copied = ["g_star", "g_come", "g_kin"]
	_h._wall(s)
	_h._wait(s, Data.COPY_SECONDS * 3)
	t.check(s.starfall.copied.size() == 3, "the Wall copies nothing of the Wreck's sets itself")


func test_finds_come_in_set_order() -> void:
	var s: Sim = _h._arrived()
	t.check(s.starfall.wreck_has_more(), "the Wreck holds marks")
	t.check(
		s.starfall.add_finds(2) == 2 and s.starfall.copied == ["g_light", "g_fire"],
		"two finds are the first two of set 2"
	)
	t.check(
		s.starfall.add_finds(2) == 2 and s.starfall.copied.has("g_bright") and s.starfall.copied.has("g_hurt"),
		"then on"
	)
	s.starfall.copied = []
	for n in [2, 3, 4, 5, 6]:
		s.starfall.locked[Data.GLYPH_SETS[n]["id"]] = true
	t.check(not s.starfall.wreck_has_more() and s.starfall.add_finds(3) == 0, "nothing left once every set is read")


func test_guesses_skip_words_already_read() -> void:
	var s: Sim = _h._arrived()
	s.starfall.add_finds(3)
	s.starfall.locked["name"] = true
	var seen := {}
	for i in Data.GLYPH_WORDS.size():
		seen[s.starfall.cycle_guess("g_light")] = true
	t.check(
		not seen.has("Star") and not seen.has("Come") and not seen.has("Kin"), "the words of a read set are skipped"
	)
	t.check(seen.has("Light") and seen.has("Fire"), "the rest can all be reached")


func test_a_party_goes_to_the_wreck_and_brings_marks_home() -> void:
	var s := _ready_town()
	t.check(s.starfall.wreck.x >= 0, "the star landed somewhere")
	var plan := Expedition.plan(s)
	t.check(plan["ok"] and plan["seconds"] > 0.0, "a party can go: " + str(plan["why"]))
	var berries: int = s.economy.inv["berries"]
	var told := Expedition.send(s)
	t.check(told.contains("set out"), "the Post says who went: " + told)
	t.check(Expedition.count(s) == Data.PARTY_SIZE, "two Kith are out")
	t.check(
		s.economy.inv["berries"] == berries - Data.PACKS["standard"]["cost"]["berries"],
		"the pack was taken from the stockpile"
	)
	t.check(not Expedition.plan(s)["ok"], "and a second party cannot leave from one Post")
	t.check(
		s.people.job_of(s.people.kith[0]) == Data.JOB_PARTY or s.people.job_of(s.people.kith[1]) == Data.JOB_PARTY,
		"titled"
	)
	_run(s, 900.0, func(): return _back(s))
	t.check(_back(s), "the party came home")
	t.check(s.starfall.wreck_found and s.story.events.has("wreck_found"), "the Wreck is found, a story moment")
	t.check(s.fog.is_revealed(s.starfall.wreck), "the fog is up at the Wreck")
	t.check(s.starfall.copied.size() == Data.PACKS["standard"]["finds"], "the pack's finds are on the Wall")
	t.check(s.events.any(func(e): return e.contains("crash site")), "and the event log says so")
	for k in s.people.kith:
		t.check(k["job"] != "expedition", "nobody is left out")


func test_a_late_party_brings_less() -> void:
	var s := _ready_town()
	s.starfall.orders["pack"] = "heavy"
	Expedition.send(s)
	for k in s.people.kith:
		if Expedition.is_party(k):
			k["timer"] = Data.DAYLIGHT_SECONDS + 1.0
	_run(s, 900.0, func(): return _back(s))
	t.check(_back(s), "they got home")
	t.check(s.starfall.copied.size() == ceili(Data.PACKS["heavy"]["finds"] / 2.0), "half the pack, rounded up")
	t.check(s.events.any(func(e): return e == Data.LATE_LINE), "and the log says dusk caught them")


func test_the_plan_says_why_not() -> void:
	var s := _grown()
	t.check(Expedition.plan(s)["why"] == Data.POST_NO_TARGET and not Expedition.plan(s)["ok"], "no Post, no trip")
	s.town.add_building("expedition_post", _h._spot(s, "expedition_post"))
	s.economy.inv["berries"] = 0
	t.check(Expedition.plan(s)["why"].begins_with("The pack needs"), "an empty larder: " + Expedition.plan(s)["why"])
	s.economy.inv["berries"] = 200
	for k in s.people.kith:
		k["job"] = "work"
	t.check(Expedition.plan(s)["why"] == Data.POST_NOBODY, "nobody free")
	t.check(Expedition.send(s) == Data.POST_NOBODY, "and send says so")
	var cheap := Expedition.cost_text("light")
	t.check(cheap.contains("Berries"), "a pack's cost reads as words: " + cheap)


func test_keep_sending_sends_again() -> void:
	var s := _ready_town()
	s.starfall.orders["keep"] = true
	s.starfall.orders["pack"] = "light"
	_run(s, 20.0, func(): return Expedition.count(s) > 0)
	t.check(Expedition.count(s) == Data.PARTY_SIZE, "a standing order sends the first party on its own")
	var first := s.starfall.copied.size()
	_run(s, 900.0, func(): return s.starfall.copied.size() > first)
	t.check(s.starfall.copied.size() > first, "it came home with a mark")
	_run(s, 20.0, func(): return Expedition.count(s) > 0)
	t.check(Expedition.count(s) == Data.PARTY_SIZE, "and sent another")


func test_the_fog_trip_gives_a_wide_look() -> void:
	var s := _grown(true)
	s.town.add_building("expedition_post", _h._spot(s, "expedition_post"))
	s.starfall.orders["target"] = "fog"
	var to := Expedition.target_tile(s, "fog")
	t.check(to.x >= 0 and not s.fog.is_revealed(to), "there is fog to look at")
	t.check(Expedition.send(s).contains("nearest fog"), "a party goes")
	_run(s, 900.0, func(): return _back(s))
	t.check(_back(s) and s.fog.is_revealed(to), "the fog is lifted where they went")
	t.check(s.starfall.copied.is_empty() and not s.starfall.wreck_found, "no marks from the fog")


func test_the_gifts_work() -> void:
	var s: Sim = _h._arrived()
	s.town.add_building("gatherers_hut", _h._spot(s, "gatherers_hut"))
	var hut: Dictionary = s.town.buildings[s.town.buildings.size() - 1]
	var cairn_at: Vector2i = hut["pos"] + Vector2i(2, 0)
	s.town.add_building("shard_cairn", cairn_at)
	var base := Bonuses.speed(s, hut)
	s.starfall.locked["light"] = true
	t.check(is_equal_approx(Bonuses.speed(s, hut), base + 0.25), "Shardlight: a hut near the Cairn works 25% faster")
	s.town.buildings[s.town.buildings.size() - 1]["pos"] = hut["pos"] + Vector2i(9, 0)
	t.check(is_equal_approx(Bonuses.speed(s, hut), base), "out of the Cairn's light it does not")
	s.town.buildings[s.town.buildings.size() - 1]["pos"] = cairn_at
	var berries := Bonuses.yield_mult(s, hut, "berries")
	s.starfall.locked["growth"] = true
	t.check(
		is_equal_approx(Bonuses.yield_mult(s, hut, "berries"), berries + 0.5),
		"Starfruit: berries near the Cairn yield 50% more"
	)
	t.check(is_equal_approx(Bonuses.yield_mult(s, hut, "clay"), Bonuses.yield_mult(s, hut, "clay")), "only berries")
	var grow: float = s.people.grow_time()
	s.starfall.locked["body"] = true
	t.check(is_equal_approx(s.people.grow_time(), grow * Data.HEALER_GROW), "Lumen Healer: births come sooner")
	var k: Dictionary = s.people.kith[0]
	hut["worker"] = 0
	k["tool"] = 40
	k["tool_id"] = "flint_tools"
	for i in 10:
		s.people.wear(hut)
	t.check(k["tool"] > 30 and k["tool"] < 40, "and a tool wears a little slower: %d" % k["tool"])
	var plain: Sim = _h._arrived()
	t.check(not plain.starfall.gift("light") and not plain.starfall.gift("body"), "no gifts before a set is read")


func test_the_post_and_wall_panels_say_things() -> void:
	var s := _ready_town()
	var post := ExpeditionPicker.new()
	post.setup(s)
	var b: Dictionary = s.town.buildings[s.town.buildings.size() - 1]
	post.show_for(b)
	t.check(post.visible and post.get_child_count() >= 5, "the Post panel has its lines")
	t.check(ExpeditionPicker.target_text(s) == "Going to: " + Data.TARGETS["wreck"], "the target reads")
	t.check(
		ExpeditionPicker.pack_text(s).contains("Standard pack") and ExpeditionPicker.pack_text(s).contains("Berries"),
		"the pack"
	)
	t.check(ExpeditionPicker.keep_text(s) == "Keep sending: off", "and the switch")
	post._next_target()
	post._next_pack()
	t.check(
		s.starfall.orders["target"] == "fog" and s.starfall.orders["pack"] == "heavy", "a click moves the choice on"
	)
	post._toggle_keep()
	t.check(s.starfall.orders["keep"], "and flips the switch")
	var wall := GlyphPicker.new()
	wall.setup(s)
	s.town.add_building("glyph_wall", _h._spot(s, "glyph_wall"))
	wall.show_for(s.town.buildings[s.town.buildings.size() - 1])
	var before := wall.get_child_count()
	s.starfall.add_finds(3)
	wall.show_for(s.town.buildings[s.town.buildings.size() - 1])
	t.check(wall.get_child_count() > before, "a set from the Wreck shows on the Wall once its marks are home")
	s.starfall.locked["light"] = true
	wall.show_for(s.town.buildings[s.town.buildings.size() - 1])
	var found := false
	for c in wall.get_children():
		found = found or (c is Label and c.text.contains(Data.LUMEN_GIFTS["light"]["name"]))
	t.check(found, "and a read set shows its gift")
	post.free()
	wall.free()


func test_the_expedition_saves() -> void:
	var s := _ready_town()
	s.starfall.orders = {"target": "fog", "pack": "light", "keep": true}
	s.starfall.wreck_found = true
	Expedition.send(s)
	var s2 := Sim.new()
	t.check(RunSave.restore(s2, RunSave.from_json(RunSave.to_json(RunSave.dump(s)))), "a save with a party out loads")
	t.check(s2.starfall.to_dict() == s.starfall.to_dict(), "the Post's orders and the Wreck read back")
	t.check(Expedition.count(s2) == Expedition.count(s), "and the party is still out")
	var old := RunSave.dump(s)
	for key in ["wreck", "wreck_found", "orders"]:
		old["game"]["starfall"].erase(key)
	var s3 := Sim.new()
	t.check(
		RunSave.restore(s3, old) and s3.starfall.orders["target"] == "wreck" and s3.starfall.wreck.x < 0,
		"an older save loads"
	)
