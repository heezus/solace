extends RefCounted
## Two roads (design-system/29-two-roads.md): reading a gift's set asks whether to take the gift or keep to the Kith's own twin of it,
## and what each road does to trust, the stores, the work, the lean and a save. Run from tests/run_tests.gd.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const StarfallTests = preload("res://tests/starfall_tests.gd")
const GlyphPicker = preload("res://scripts/glyph_picker.gd")

var t  # the runner, tests/run_tests.gd
var _h  # the stage 1 tests, for their town helpers


func run(runner) -> void:
	t = runner
	_h = StarfallTests.new()
	_h.t = runner
	test_a_gift_set_asks_for_a_road()
	test_taking_the_gift_works_as_before()
	test_refusing_costs_trust_and_starts_the_twin()
	test_each_twin_does_its_job()
	test_a_twin_goes_out_when_the_stores_run_dry()
	test_refusals_set_the_lean_and_close_the_market()
	test_the_cards_and_panel_say_it()
	test_roads_save_and_old_saves_take_the_gift()


## An arrived town with full stores, the name read, the strangers' questions answered, and a hut with a Cairn beside it.
func _town() -> Sim:
	var s: Sim = _h._arrived()
	t.give(s, 200)
	s.starfall.locked["name"] = true
	for id in Data.MOMENT_ORDER:
		s.starfall.answered[id] = 0  # the strangers' questions are behind us, so only a road can hold a card
	s.town.add_building("gatherers_hut", _h._spot(s, "gatherers_hut"))
	var hut: Dictionary = s.town.buildings[s.town.buildings.size() - 1]
	s.town.add_building("shard_cairn", hut["pos"] + Vector2i(2, 0))
	return s


## The Kith read the set `id`: its marks on the Wall, every guess right, and the next talk.
func _read(s: Sim, id: String) -> void:
	for n in Data.GLYPH_SETS:
		if Data.GLYPH_SETS[n]["id"] == id:
			for g in Data.GLYPH_SETS[n]["glyphs"]:
				if not s.starfall.copied.has(g):
					s.starfall.copied.append(g)
				s.starfall.guesses[g] = Data.GLYPHS[g]["word"]
	s.starfall.check()


func _ask(s: Sim, id: String) -> void:
	_read(s, id)
	s.starfall.tick(0.1)  # the card goes up


func test_a_gift_set_asks_for_a_road() -> void:
	var s := _town()
	var before: float = s.starfall.trust
	_read(s, "light")
	t.check(
		s.starfall.read("light") and not s.starfall.gift("light"), "the set is read but its gift waits on the answer"
	)
	t.check(is_equal_approx(s.starfall.trust, before), "and no trust is given yet")
	t.check(s.starfall.pending == "", "the card goes up on the next tick, not in the middle of the talk")
	s.starfall.tick(0.1)
	t.check(s.starfall.pending == "road_light", "then the road is asked")
	var opts: Array = s.starfall.pending_options()
	t.check(
		opts.size() == 2 and opts[0]["label"].contains("Shardlight") and opts[1]["label"].contains("Cairnfire"),
		"two roads"
	)
	var card: Dictionary = s.starfall.pending_card()
	t.check(card["title"] == Data.ROAD_TITLE and card["says"].contains(Data.LEAD_NAME), "the card has Sela's say")
	t.check(not s.starfall.choose(5) and s.starfall.pending == "road_light", "a wrong index changes nothing")
	t.check(not s.starfall.may_end(), "and the Warning cannot be read while a road waits")
	# the non-gift sets do not ask
	var n: Sim = _h._arrived()
	n.starfall.locked["name"] = true
	_read(n, "name")
	n.starfall.tick(0.1)
	t.check(n.starfall.pending == "", "the first set (the name) asks no road")


func test_taking_the_gift_works_as_before() -> void:
	var s := _town()
	_ask(s, "light")
	var before: float = s.starfall.trust
	t.check(s.starfall.choose(0) and s.starfall.pending == "", "take the gift")
	t.check(is_equal_approx(s.starfall.trust, before + Data.TRUST_SET), "trust rises by a set's worth")
	t.check(s.starfall.gift("light") and s.starfall.roads["light"] == "accept", "the gift works")
	t.check(not s.starfall.twin("light") and s.starfall.refusals() == 0, "and no twin")


func test_refusing_costs_trust_and_starts_the_twin() -> void:
	var s := _town()
	_ask(s, "light")
	s.starfall.trust = 50.0
	var before: float = s.starfall.trust
	var charcoal: int = s.economy.inv["charcoal"]
	t.check(s.starfall.choose(1) and s.starfall.pending == "", "keep to the Kith way")
	t.check(is_equal_approx(s.starfall.trust, before + Data.TRUST_REFUSE), "trust falls a little")
	t.check(not s.starfall.gift("light") and s.starfall.twin("light"), "the gift is gone and the twin is lit")
	t.check(s.economy.inv["charcoal"] == charcoal - 1, "it burned one Charcoal for the one Cairn")
	t.check(s.starfall.refusals() == 1, "one refusal")
	var hut: Dictionary = s.town.buildings[s.town.buildings.size() - 2]
	var base := Bonuses.speed(s, hut)
	s.starfall.twin_lit.erase("light")
	var without := Bonuses.speed(s, hut)
	t.check(is_equal_approx(base, without + 0.25), "Cairnfire: the hut by the Cairn works 25% faster while it burns")
	s.starfall.twin_lit["light"] = true
	s.starfall.tick(Data.TWIN_EVERY)
	t.check(s.economy.inv["charcoal"] == charcoal - 2, "and another Charcoal goes each minute")


func test_each_twin_does_its_job() -> void:
	# Bonesetter's rule: births sooner, tools last longer, for a Berry a minute.
	var s := _town()
	var grow: float = s.people.grow_time()
	_ask(s, "body")
	var berries: int = s.economy.inv["berries"]
	s.starfall.choose(1)
	t.check(s.starfall.twin("body") and s.economy.inv["berries"] == berries - 1, "the bonesetter's rule costs a Berry")
	t.check(is_equal_approx(s.people.grow_time(), grow * Data.HEALER_GROW), "births come sooner, as with the Healer")
	# Orchard: berries near a Dwelling, 40 Wood once.
	s.town.add_building("dwelling", _h._spot(s, "dwelling"))
	var dwelling: Dictionary = s.town.buildings[s.town.buildings.size() - 1]
	s.town.add_building("gatherers_hut", dwelling["pos"] + Vector2i(2, 0))
	var hut: Dictionary = s.town.buildings[s.town.buildings.size() - 1]
	var plain := Bonuses.yield_mult(s, hut, "berries")
	_ask(s, "growth")
	var wood: int = s.economy.inv["wood"]
	s.starfall.choose(1)
	t.check(s.economy.inv["wood"] == wood - 40 and s.starfall.twin("growth"), "the Orchard costs 40 Wood")
	t.check(
		is_equal_approx(Bonuses.yield_mult(s, hut, "berries"), plain + 0.5), "berries near a Dwelling yield 50% more"
	)
	s.starfall.tick(Data.TWIN_EVERY * 3.0)
	t.check(s.economy.inv["wood"] == wood - 40, "and it is paid once")
	# Smith's Rule: workshops beside a Smelter, a Charcoal a minute per Smelter.
	s.town.add_building("smelter", _h._spot(s, "smelter"))
	var smelter: Dictionary = s.town.buildings[s.town.buildings.size() - 1]
	s.town.add_building("kiln", smelter["pos"] + Vector2i(2, 0))
	var kiln: Dictionary = s.town.buildings[s.town.buildings.size() - 1]
	var slow := Bonuses.speed(s, kiln)
	_ask(s, "craft")
	s.starfall.choose(1)
	t.check(s.starfall.twin("craft"), "Smith's Rule is lit")
	t.check(is_equal_approx(Bonuses.speed(s, kiln), slow + 0.25), "a workshop beside the Smelter works 25% faster")


func test_a_twin_goes_out_when_the_stores_run_dry() -> void:
	var s := _town()
	_ask(s, "light")
	s.starfall.choose(1)
	t.check(s.starfall.twin("light"), "it starts lit")
	s.economy.inv["charcoal"] = 0
	s.starfall.tick(Data.TWIN_EVERY)
	t.check(not s.starfall.twin("light"), "with no Charcoal it goes out")
	t.check(s.starfall.roads["light"] == "refuse", "but the road stays refused")
	s.economy.inv["charcoal"] = 50
	s.starfall.tick(Data.TWIN_EVERY)
	t.check(s.starfall.twin("light"), "and lights again when the stores can pay")
	# an Orchard with no Wood waits on its price, then is planted
	var o := _town()
	o.economy.inv["wood"] = 5
	_ask(o, "growth")
	o.starfall.choose(1)
	t.check(not o.starfall.twin("growth"), "an Orchard waits on its Wood")
	o.economy.inv["wood"] = 80
	o.starfall.tick(Data.TWIN_EVERY)
	t.check(o.starfall.twin("growth") and o.economy.inv["wood"] == 40, "and is planted when it can be paid")


func test_refusals_set_the_lean_and_close_the_market() -> void:
	var s := _town()
	s.starfall.trust = Data.TRUST_MAX
	t.check(s.starfall.lean_now() == "allies", "full trust and no refusals: allies")
	s.starfall.roads["light"] = "refuse"
	t.check(s.starfall.lean_now() == "neighbours", "one refusal: at most neighbours")
	for id in Data.ROAD_ORDER:
		s.starfall.roads[id] = "refuse"
	t.check(s.starfall.lean_now() == "enemies", "all four refused: enemies, whatever the trust")
	var m := _town()
	m.starfall.trust = Data.TRUST_MAX
	for id in Data.ROAD_ORDER:
		m.starfall.roads[id] = "refuse"
	m.starfall.tick(1.0)
	t.check(not m.starfall.seen.has("market_open"), "and the Lumen never open their Market")
	var open := _town()
	open.starfall.trust = Data.TRUST_MAX
	open.starfall.tick(1.0)
	t.check(open.starfall.seen.has("market_open"), "while with no refusals they do")


func test_the_cards_and_panel_say_it() -> void:
	var s := _town()
	_ask(s, "growth")
	var card = preload("res://scripts/moment_card.gd").new()
	card.setup()
	card.open(s.starfall)
	t.check(card.visible, "the card for the road is up")
	card.free()
	s.town.add_building("glyph_wall", _h._spot(s, "glyph_wall"))
	var wall := GlyphPicker.new()
	wall.setup(s)
	var at: Dictionary = s.town.buildings[s.town.buildings.size() - 1]
	wall.show_for(at)
	t.check(_has_text(wall, Data.TWIN_WAITING_LINE), "the Wall's panel says a road waits")
	s.starfall.choose(1)
	wall.show_for(at)
	t.check(
		_has_text(wall, Data.TWINS["growth"]["name"]) and not _has_text(wall, Data.TWIN_WAITING_LINE),
		"then names the twin"
	)
	wall.free()
	s.starfall.pending = "ending"
	t.check(s.starfall.pending_card()["text"].contains("1 of the 4"), "the ending names the roads taken")
	s.starfall.pending = "warning"
	t.check(s.starfall.pending_card()["text"].contains(Data.ROAD_WARNING_LINE), "and the Warning's question changes")
	t.check(s.starfall.pending_card()["title"] == Data.MOMENTS["warning"]["title"], "and keeps its title")


func _has_text(node: Node, text: String) -> bool:
	for c in node.find_children("*", "Label", true, false):
		if c.text.contains(text):
			return true
	return false


func test_roads_save_and_old_saves_take_the_gift() -> void:
	var s := _town()
	_ask(s, "light")
	s.starfall.choose(1)
	_read(s, "body")
	var back := Sim.new()
	back.generate(1)
	t.check(
		RunSave.restore(back, RunSave.from_json(RunSave.to_json(RunSave.dump(s)))), "a save with a refused gift loads"
	)
	t.check(
		back.starfall.roads == s.starfall.roads and back.starfall.road_queue == s.starfall.road_queue,
		"the roads and the waiting card are kept"
	)
	t.check(back.starfall.twin("light") == s.starfall.twin("light"), "and the twin is still lit")
	var old: Dictionary = RunSave.dump(s)
	var sf: Dictionary = old["game"]["starfall"]
	for k in ["roads", "road_queue", "twin_lit", "twin_paid", "twin_clock"]:
		sf.erase(k)
	sf["locked"] = {"name": true, "light": true}
	var legacy := Sim.new()
	legacy.generate(1)
	t.check(RunSave.restore(legacy, old), "an older save loads")
	t.check(
		legacy.starfall.gift("light") and legacy.starfall.pending == "", "and its gift still works, with no road asked"
	)
