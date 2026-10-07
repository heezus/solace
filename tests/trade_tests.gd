extends RefCounted
## Starfall stage 4 (design-system/16-starfall.md): the Lumen Market, the shared shrine and the Guard Post, the three
## buildings that move trust once the strangers have arrived. Run from tests/run_tests.gd, which owns check().

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const RunSave = preload("res://scripts/run_save.gd")
const StarfallTests = preload("res://tests/starfall_tests.gd")

var t  # the runner, tests/run_tests.gd
var _h  # the stage 1 tests, for their town helpers


func run(runner) -> void:
	t = runner
	_h = StarfallTests.new()
	_h.t = runner
	test_the_buildings_are_well_formed()
	test_the_lumen_will_trade_once_trust_stands()
	test_the_market_swaps_two_for_one()
	test_trade_alone_makes_neighbours()
	test_the_shrine_lifts_trust()
	test_the_guard_post_wears_trust_down_and_speeds_the_kith()
	test_the_standing_buildings_save()


## The strangers have arrived, the name is read and the Camp stands, so the market is open.
func _open() -> Sim:
	var s: Sim = _h._arrived()
	s.starfall.locked[Data.GLYPH_SETS[1]["id"]] = true
	s.starfall.nudge(Data.MARKET_OPEN_TRUST)
	s.starfall.tick(1.0)
	return s


func _build(s: Sim, type: String) -> int:
	s.town.add_building(type, _h._spot(s, type))
	return s.town.buildings.size() - 1


func test_the_buildings_are_well_formed() -> void:
	for id in ["lumen_market", "shared_shrine", "guard_post"]:
		var def: Dictionary = Data.BUILDINGS[id]
		t.check(def.has("event") and Data.STORY_EVENTS.has(def["event"]), id + " opens on a story event")
		t.check(id in Data.BUILD_ORDER and id in Data.BUILD_TABS["Lore"], id + " is on the build bar")
	t.check(Data.BUILDINGS["lumen_market"].get("trade_give", 0) == 2, "the Market gives 2 for 1")
	t.check(Data.TRUST_GUARD < 0.0 and Data.TRUST_GUARD_PER_MINUTE < 0.0, "the Guard Post costs trust")
	t.check(Data.TRUST_SHRINE > 0.0 and Data.MARKET_TRUST_CAP < Data.LEAN_ALLIES, "trade alone stops short of allies")


func test_the_lumen_will_trade_once_trust_stands() -> void:
	var s: Sim = _h._arrived()
	s.starfall.locked[Data.GLYPH_SETS[1]["id"]] = true
	s.starfall.tick(1.0)
	t.check(not s.story.events.has("market_open"), "wary and unknown: nothing to trade yet")
	s.starfall.nudge(Data.MARKET_OPEN_TRUST)
	s.starfall.tick(1.0)
	t.check(s.story.events.has("market_open"), "trust reaches the line and the Lumen would trade")
	t.check(s.events.has(Data.MARKET_OPEN_LINE), "and they say so")
	var guests: Sim = _h._arrived(true)
	guests.starfall.locked[Data.GLYPH_SETS[1]["id"]] = true
	guests.starfall.tick(1.0)
	t.check(guests.story.events.has("market_open"), "guests trade at once once the name is read")


func test_the_market_swaps_two_for_one() -> void:
	var s := _open()
	var i := _build(s, "lumen_market")
	t.check(s.town.set_trade(i, "wood", "stone"), "the Market is set to give Wood for Stone")
	var b: Dictionary = s.town.buildings[i]
	t.check(Buildings.recipe_in(b) == {"wood": 2}, "it takes 2")
	t.check(Buildings.recipe_out(b) == {"stone": Data.TRADE_GET}, "and gives 1")
	var post := _build(s, "trading_post")
	s.town.set_trade(post, "wood", "stone")
	t.check(Buildings.recipe_in(s.town.buildings[post]) == {"wood": Data.TRADE_GIVE}, "the Trading Post is dearer")


func test_trade_alone_makes_neighbours() -> void:
	var s := _open()
	_build(s, "lumen_market")
	s.starfall.tick(1.0)
	var before: float = s.starfall.trust
	_h._wait(s, 60)
	t.check(s.starfall.trust > before, "a standing Market lifts trust a little")
	s.starfall.trust = Data.MARKET_TRUST_CAP
	_h._wait(s, 120)
	t.check(s.starfall.trust == Data.MARKET_TRUST_CAP, "and stops at its ceiling")
	t.check(s.starfall.lean_now() == "neighbours", "which is neighbours, not allies")


func test_the_shrine_lifts_trust() -> void:
	var s := _open()
	var before: float = s.starfall.trust
	_build(s, "shared_shrine")
	s.starfall.tick(1.0)
	t.check(s.starfall.trust >= before + Data.TRUST_SHRINE, "a shrine is a step of trust")
	t.check(s.events.has(Data.SHRINE_BUILT_LINE), "and the strangers notice it")
	t.check(s.story.events.has("shrine_raised"), "and it is a story moment")
	var after: float = s.starfall.trust
	_h._wait(s, 60)
	t.check(s.starfall.trust > after, "and a little more while it stands")


func test_the_guard_post_wears_trust_down_and_speeds_the_kith() -> void:
	var s := _open()
	s.starfall.nudge(30.0)
	var hut := _build(s, "gatherers_hut")
	var plain: float = Bonuses.speed(s, s.town.buildings[hut])
	var before: float = s.starfall.trust
	var g := _build(s, "guard_post")
	s.town.buildings[g]["pos"] = s.town.buildings[hut]["pos"] + Vector2i(1, 0)
	s.starfall.tick(1.0)
	t.check(s.starfall.trust <= before + Data.TRUST_GUARD + 0.01, "a Guard Post is a step down")
	t.check(s.story.events.has("guard_raised"), "and a story moment")
	var after: float = s.starfall.trust
	_h._wait(s, 60)
	t.check(s.starfall.trust < after, "and a little more while it stands")
	t.check(is_equal_approx(Bonuses.speed(s, s.town.buildings[hut]), plain + 0.15), "huts beside it work 15% faster")
	s.town.buildings[g]["pos"] = s.town.buildings[hut]["pos"] + Vector2i(9, 0)
	t.check(is_equal_approx(Bonuses.speed(s, s.town.buildings[hut]), plain), "but not far from it")
	s.starfall.trust = 0.0
	_h._wait(s, 30)
	t.check(s.starfall.trust == 0.0, "trust never goes below nothing")


func test_the_standing_buildings_save() -> void:
	var s := _open()
	_build(s, "shared_shrine")
	s.starfall.tick(1.0)
	var back := Sim.new()
	t.check(RunSave.restore(back, RunSave.from_json(RunSave.to_json(RunSave.dump(s)))), "a save loads")
	t.check(back.starfall.seen == s.starfall.seen, "what has been counted survives it")
	var old := RunSave.dump(s)
	old["game"]["starfall"].erase("seen")
	var older := Sim.new()
	t.check(RunSave.restore(older, old) and older.starfall.seen.is_empty(), "an older save loads")
