extends RefCounted
## Tests for saving (scripts/run_save.gd, scripts/profile.gd and each block's to_dict / from_dict): the small
## blocks that have no testbench of their own (Fog, Flows, the codec), the run save as a whole, the profile
## and how it stays apart from the run save. run() is quick and runs everywhere; run_system() plays the pacing
## bot and needs a few minutes of simulated play, so run_tests.gd skips it with `-- fast`.
## The system-level tests are the important ones: a run dumped in the middle of a game and loaded into a
## fresh Sim must go on exactly like the original (same state hash, same full dump), and a bot that is
## dumped and restored along the way must still win at the golden time with the golden hash.
## Nothing touches the disk except one small file under user:// that is deleted again.
## Run from tests/run_tests.gd, which owns check().

const Autoplay = preload("res://tests/autoplay.gd")
const Codec = preload("res://scripts/save_codec.gd")
const Data = preload("res://scripts/data.gd")
const Fog = preload("res://scripts/fog.gd")
const Flows = preload("res://scripts/flows.gd")
const Sim = preload("res://scripts/sim.gd")
const GoldenTests = preload("res://tests/golden_tests.gd")
const Profile = preload("res://scripts/profile.gd")
const Roads = preload("res://scripts/roads.gd")
const RunSave = preload("res://scripts/run_save.gd")

const TEMP_RUN := "user://solace_test_run.json"
const TEMP_PROFILE := "user://solace_test_profile.json"

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_codec()
	test_fog_round_trip()
	test_flows_round_trip()
	test_a_new_game_round_trips()
	test_a_played_game_round_trips()
	test_restore_replaces_what_was_there()
	test_bad_saves_are_refused()
	test_run_save_file()
	test_derived_state_is_rebuilt()
	test_profile_absorb()
	test_profile_is_tolerant()
	test_profile_file()
	test_run_save_and_profile_stay_apart()


## The system-level tests: play the bot on a fixed map, dump and restore, and carry on.
func run_system(runner) -> void:
	t = runner
	test_a_loaded_game_carries_on_the_same()
	test_the_bot_wins_on_time_through_restores()


## A dictionary as JSON text, in the order kept: two saves are the same when their texts are.
static func text(d: Dictionary) -> String:
	return RunSave.to_json(d)


## The dictionary after a trip through JSON text (every number a float, Vector2i gone).
static func via_json(d: Dictionary) -> Dictionary:
	return RunSave.from_json(RunSave.to_json(d))


## A new game on `map_seed` with a few things done, so the save has something in every block.
## (The default 190 s is a moment when no float in the state is one that Godot's JSON parser reads back a
## last-digit off, e.g. 1.9000000000000006 as ...08: a known limit of the text round trip, which most
## moments of a run hit. A dump compared as text needs a moment that doesn't.)
func _played(map_seed: int = 7, seconds: int = 190) -> Sim:
	var s := Sim.new()
	s.generate(map_seed)
	var bot := Autoplay.new()
	bot.attach(s)
	while bot.clock < seconds:
		bot.step(true)
	return s


# --- The small blocks --------------------------------------------------------


func test_codec() -> void:
	t.check(Codec.to_vec(Codec.vec(Vector2i(-3, 9))) == Vector2i(-3, 9), "a tile position")
	t.check(Codec.to_vec2(Codec.vec2(Vector2(1.5, -0.25))) == Vector2(1.5, -0.25), "a position between tiles")
	var members := {Vector2i(2, 1): true, Vector2i(0, 5): true, Vector2i(1, 1): true}
	t.check(Codec.to_vec_set(Codec.vec_keys(members)).keys() == members.keys(), "a set of positions keeps its order")
	var names := {"b": true, "a": true, "c": true}
	t.check(Codec.to_set(Codec.keys(names)).keys() == ["b", "a", "c"], "a set of names keeps its order")
	var counts := Codec.int_dict(via_json({"wood": 4, "stone": 0}))
	t.check(counts["wood"] is int and counts == {"wood": 4, "stone": 0}, "counts come back as ints")
	t.check(Codec.float_dict({"a": 2})["a"] is float, "and floats as floats")
	var moved := Codec.with_points({"tile": Vector2i(1, 2), "kind": "x"}, ["tile", "depot"])
	t.check(moved == {"tile": [1, 2], "kind": "x"}, "named entries become [x, y] and the rest stay")
	t.check(Codec.from_points(via_json(moved), ["tile", "depot"])["tile"] == Vector2i(1, 2), "and back")


func test_fog_round_trip() -> void:
	var a := Fog.new()
	a.setup(6, 4)
	a.reveal(Vector2i(2, 1), 1)
	var d := a.to_dict()
	t.check(
		d["cells"] is String and d["cells"].length() == 24 and d["width"] == 6, "fog is written as a string of cells"
	)
	var b := Fog.new()
	b.from_dict(d)
	t.check(b.cells == a.cells and b.width == 6 and b.height == 4, "a Fog restored from a dict has the same cells")
	t.check(text(b.to_dict()) == text(d), "and writes the same dict")
	var c := Fog.new()
	c.from_dict(via_json(d))
	t.check(c.cells == a.cells and c.count() == a.count(), "the same after a trip through JSON text")
	c.from_dict({"width": 3, "height": 3, "cells": "101"})
	t.check(c.count() == 0 and c.cells.size() == 9, "cells that don't fit the size come back fogged")


func test_flows_round_trip() -> void:
	var a := Flows.new()
	a.add("wood", 3, "hand")
	a.advance(1.0)
	a.add("wood", -1.5, "craft")
	a.advance(0.4)
	var b := Flows.new()
	b.from_dict(via_json(a.to_dict()))
	t.check(text(b.to_dict()) == text(a.to_dict()), "a Flows restored through JSON writes the same dict")
	t.check(b.rate("wood") == a.rate("wood") and b.clock == a.clock, "the same rates and clock")


# --- The run save ------------------------------------------------------------


func test_a_new_game_round_trips() -> void:
	var a := Sim.new()
	a.generate(5)
	var d := RunSave.dump(a)
	t.check(int(d["version"]) == RunSave.VERSION, "the dump carries its version")
	var keys := d.keys()
	keys.sort()
	var want := RunSave.SECTIONS.duplicate()
	want.append("version")
	want.sort()
	t.check(keys == want, "and one section per block, no more")
	var b := Sim.new()
	t.check(RunSave.restore(b, via_json(d)), "a fresh Sim takes the dump")
	t.check(text(RunSave.dump(b)) == text(d), "and writes it back the same")
	var golden := GoldenTests.new()
	t.check(golden.state_hash(a) == golden.state_hash(b), "with the same state hash")


func test_a_played_game_round_trips() -> void:
	var a := _played()
	t.check(
		a.town.buildings.size() > 1 and not a.economy.inv.is_empty() and a.fog.count() > 30,
		"set up: a game with something in it"
	)
	t.check(not a.hand_counts.is_empty() and a.economy.flows.hist.size() > 10, "and hand counts and flows")
	var d := RunSave.dump(a)
	var b := Sim.new()
	t.check(RunSave.restore(b, d), "restore from the dump itself")
	t.check(text(RunSave.dump(b)) == text(d), "a played game writes back the same dump")
	var c := Sim.new()
	t.check(RunSave.restore(c, via_json(d)), "restore from parsed JSON")
	t.check(text(RunSave.dump(c)) == text(d), "and writes the same dump")
	var golden := GoldenTests.new()
	t.check(golden.canonical(c) == golden.canonical(a), "with the state the golden test hashes")
	t.check(
		c.people.kith == a.people.kith and c.town.buildings == a.town.buildings,
		"people and buildings are equal, field for field"
	)
	t.check(
		(
			c.economy.inv == a.economy.inv
			and c.world.roads.keys() == a.world.roads.keys()
			and c.world.fields.keys() == a.world.fields.keys()
		),
		"as are the stock and the roads"
	)
	t.check(c.town.building_at == a.town.building_at and c.world.tiles == a.world.tiles, "and the index and the map")
	a.economy.inv["wood"] += 5
	a.town.buildings[0]["progress"] = 9.0
	t.check(text(RunSave.dump(c)) == text(d), "a dump is a copy: later play doesn't change it")


func test_restore_replaces_what_was_there() -> void:
	var a := _played(7, 40)
	var d := RunSave.dump(a)
	var b := _played(11, 20)  # another map, another run
	t.check(RunSave.restore(b, via_json(d)), "a game already under way takes a dump")
	t.check(text(RunSave.dump(b)) == text(d), "and becomes exactly that game")
	var held := b.tech_tree.researched
	t.check(RunSave.restore(b, d) and is_same(held, b.tech_tree.researched), "the shared researched set stays one set")


func test_bad_saves_are_refused() -> void:
	var a := _played(7, 30)
	var before := text(RunSave.dump(a))
	var good := RunSave.dump(a)
	var other := good.duplicate(true)
	other["version"] = RunSave.VERSION + 1
	var missing := good.duplicate(true)
	missing.erase("kith")
	var wrong := good.duplicate(true)
	wrong["world"] = []
	var b := _played(11, 10)
	var was := text(RunSave.dump(b))
	for bad in [{}, other, missing, wrong]:
		t.check(not RunSave.restore(b, bad), "a bad dump is refused: %s" % str(bad.keys()).left(40))
	t.check(
		not RunSave.restore(b, null) and not RunSave.restore(b, "text") and not RunSave.restore(b, 3),
		"so are other types"
	)
	t.check(text(RunSave.dump(b)) == was, "and the game is untouched")
	t.check(RunSave.from_json("{not json").is_empty() and RunSave.from_json("").is_empty(), "bad JSON gives {}")
	t.check(RunSave.from_json("[1, 2]").is_empty(), "and so does JSON that isn't an object")
	t.check(text(RunSave.dump(a)) == before, "dumping doesn't change the game")


func test_run_save_file() -> void:
	var a := _played(7, 30)
	t.check(RunSave.save(a, TEMP_RUN), "the run is written to a file")
	var b := Sim.new()
	t.check(RunSave.load_into(b, TEMP_RUN), "and read back into a fresh game")
	t.check(text(RunSave.dump(b)) == text(RunSave.dump(a)), "the same game")
	var f := FileAccess.open(TEMP_RUN, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var c := _played(11, 10)
	var was := text(RunSave.dump(c))
	t.check(
		not RunSave.load_into(c, TEMP_RUN) and text(RunSave.dump(c)) == was,
		"a corrupt file is refused and the game kept"
	)
	_delete(TEMP_RUN)
	t.check(not RunSave.load_into(c, TEMP_RUN), "a missing file is refused")
	t.check(not RunSave.save(a, "user://no_such_folder/run.json"), "a path that can't be written says so")


func test_derived_state_is_rebuilt() -> void:
	var a := _played(7, 400)
	var b := Sim.new()
	t.check(RunSave.restore(b, via_json(RunSave.dump(a))), "set up: a loaded game")
	t.check(
		b.town.road_net.is_empty() and b.town.road_rev == a.town.road_rev,
		"the road cache starts empty, at the same revision"
	)
	var same_grid := true
	for y in b.world.height:
		for x in b.world.width:
			var p := Vector2i(x, y)
			if (
				b.pathing.astar.is_point_solid(p) != a.pathing.astar.is_point_solid(p)
				or b.pathing.astar.get_point_weight_scale(p) != a.pathing.astar.get_point_weight_scale(p)
			):
				same_grid = false
	t.check(same_grid, "the walking grid is rebuilt to match the original")
	t.check(b.town.building_at == a.town.building_at, "and so is the building index")
	var from := b.world.camp_pos
	var to := Vector2i(clampi(from.x + 6, 0, 35), from.y)
	t.check(b.pathing.path(from, to) == a.pathing.path(from, to), "and paths come out the same")
	var ra := a.town.buildings.map(func(x): return Roads.linked(a, x))
	var rb := b.town.buildings.map(func(x): return Roads.linked(b, x))
	t.check(ra == rb, "as do the road links, which Roads rebuilds when asked")


# --- The profile -------------------------------------------------------------


func test_profile_absorb() -> void:
	var p := Profile.new()
	t.check(p.is_empty() and p.chronicle.is_empty() and p.knowledge.is_empty(), "a new profile is empty")
	var s := Sim.new()
	s.generate(3)
	s.story.record("shard_found")
	s.story.record("first_lesson")
	s.people.learn("wood", "Aro")
	s.people.learn("flint", "Bel")
	p.absorb(s)
	t.check(p.chronicle == ["shard_found", "first_lesson"], "the story ids, in the order they happened")
	t.check(p.knowledge == ["wood", "flint"], "and the items the people learned")
	p.absorb(s)
	t.check(p.chronicle.size() == 2 and p.knowledge.size() == 2, "absorbing the same run again changes nothing")
	s.story.record("haulers")
	s.people.learn("stone", "Cai")
	p.absorb(s)
	t.check(
		p.chronicle == ["shard_found", "first_lesson", "haulers"], "new ids go on the end, old ones keep their place"
	)
	t.check(
		p.knowledge == ["wood", "flint", "stone"] and p.knows("stone") and not p.knows("clay"), "same for knowledge"
	)
	var other := Sim.new()
	other.generate(9)
	other.story.record("haulers")
	other.story.record("first_trip")
	other.people.learn("clay", "Dov")
	other.people.learn("wood", "Eli")
	p.absorb(other)
	t.check(
		p.chronicle == ["shard_found", "first_lesson", "haulers", "first_trip"], "a second run adds only what is new"
	)
	t.check(p.knowledge == ["wood", "flint", "stone", "clay"], "in order, with no repeats")
	var before := text(p.to_dict())
	p.merge(["haulers", 5, "x"], ["clay", null])
	t.check(
		p.chronicle.has("x") and not p.chronicle.has(5) and p.knowledge.size() == 4,
		"merge keeps only strings, once each"
	)
	t.check(before != text(p.to_dict()), "(and did add the new string)")
	var q := Profile.new()
	q.absorb(s)
	q.absorb(other)
	var r := Profile.new()
	r.absorb(other)
	r.absorb(s)
	t.check(
		q.chronicle.size() == r.chronicle.size() and q.knowledge.size() == r.knowledge.size(),
		"the order of runs never duplicates"
	)
	var fresh := Sim.new()
	fresh.generate(3)
	var untouched := text(RunSave.dump(fresh))
	p.absorb(fresh)
	t.check(text(RunSave.dump(fresh)) == untouched, "absorbing never changes the run")


func test_profile_is_tolerant() -> void:
	var p := Profile.new()
	p.merge(["shard_found"], ["wood"])
	t.check(
		not p.load_file("user://solace_no_such_profile.json") and p.is_empty(), "a missing file gives an empty profile"
	)
	for bad in [
		"",
		"{oops",
		"[1,2]",
		"null",
		'{"version": 1}',
		'{"version": 9, "chronicle": [], "knowledge": []}',
		'{"version": 1, "chronicle": 3, "knowledge": []}'
	]:
		p.merge(["shard_found"], ["wood"])
		t.check(not p.from_json(bad) and p.is_empty(), "corrupt text gives an empty profile: %s" % bad.left(30))
	p.from_dict(
		{"version": 1, "chronicle": ["haulers", 3, "haulers", "first_trip"], "knowledge": ["wood", null, "wood"]}
	)
	t.check(
		p.chronicle == ["haulers", "first_trip"] and p.knowledge == ["wood"], "stray entries and repeats are dropped"
	)
	p.from_dict(null)
	t.check(p.is_empty(), "a dict that isn't one gives an empty profile")
	var q := Profile.new()
	q.merge(["shard_found", "haulers"], ["flint", "wood"])
	var d := q.to_dict()
	t.check(d.keys() == ["version", "chronicle", "knowledge"], "the profile's top-level keys")
	p.from_dict(via_json(d))
	t.check(text(p.to_dict()) == text(d), "a dict, through JSON text, comes back the same")
	t.check(p.from_json(q.to_json()) and p.chronicle == q.chronicle and p.knowledge == q.knowledge, "so does its text")


func test_profile_file() -> void:
	var a := Profile.new()
	a.merge(["shard_found", "first_lesson", "haulers"], ["wood", "flint"])
	t.check(a.save(TEMP_PROFILE), "the profile is written to a file")
	var b := Profile.new()
	t.check(b.load_file(TEMP_PROFILE), "and read back")
	t.check(text(b.to_dict()) == text(a.to_dict()), "the same profile")
	var f := FileAccess.open(TEMP_PROFILE, FileAccess.WRITE)
	f.store_string("{ corrupt")
	f.close()
	t.check(not b.load_file(TEMP_PROFILE) and b.is_empty(), "a corrupt file gives an empty profile")
	_delete(TEMP_PROFILE)
	t.check(not b.load_file(TEMP_PROFILE) and b.is_empty(), "and so does a missing one")
	t.check(not a.save("user://no_such_folder/profile.json"), "a path that can't be written says so")


func test_run_save_and_profile_stay_apart() -> void:
	var s := _played(7, 90)
	s.story.record("shard_found")
	s.people.learn("wood", "Aro")
	var saved_run := RunSave.dump(s)
	var p := Profile.new()
	p.absorb(s)
	var profile := p.to_dict()
	t.check(
		not saved_run.has("chronicle") and not saved_run.has("knowledge") and not saved_run.has("profile"),
		"a run save has no profile section"
	)
	t.check(
		not text(saved_run).contains('"chronicle"') and not text(saved_run).contains('"knowledge"'),
		"nor any profile key deeper down"
	)
	var allowed := ["version", "chronicle", "knowledge"]
	t.check(profile.keys() == allowed, "the profile has only its own keys")
	for key in RunSave.SECTIONS:
		t.check(not profile.has(key), "the profile has no %s" % key)
	for word in ["tiles", "inv", "buildings", "roads", "researched", "kith", "food", "cells"]:
		t.check(not p.to_json().contains('"%s"' % word), "and no run data (%s) inside" % word)
	t.check(Profile.is_profile(profile) and not Profile.is_profile(saved_run), "one is not taken for the other")
	t.check(RunSave.is_run_save(saved_run) and not RunSave.is_run_save(profile), "either way round")
	var fresh := Sim.new()
	t.check(RunSave.restore(fresh, via_json(saved_run)), "restoring a run needs no profile")
	t.check(
		fresh.people.learned_by == s.people.learned_by and fresh.story.events == s.story.events,
		"the run's own story and lessons are in it"
	)


# --- The system level: the bot's whole game ----------------------------------


## A bot on `map_seed`, played up to `seconds` of simulated time.
func _bot_at(map_seed: int, seconds: float) -> Autoplay:
	var game := Sim.new()
	game.generate(map_seed)
	var bot := Autoplay.new()
	bot.attach(game)
	while bot.clock < seconds and not game.won:
		bot.step(true)
	return bot


## A second bot playing a restored copy of `bot`'s game from the same moment. The bot keeps a little state of
## its own (the clock, the click budget, what it is holding on), copied here, not changed in the bot.
func _clone(bot: Autoplay, game: Sim) -> Autoplay:
	var c := Autoplay.new()
	c.s = game
	_copy_mind(bot, c)
	return c


func _copy_mind(from: Autoplay, to: Autoplay) -> void:
	to.clock = from.clock
	to.clicks = from.clicks
	to.think = from.think
	to.hold_tile = from.hold_tile
	to.known = from.known.duplicate()
	to.clicked = from.clicked.duplicate()
	to.reach = from.reach.duplicate()
	to.lines = from.lines.duplicate()


## Dump the game in the middle of play, load it into a fresh Sim, and play both on with the same bot
## steps: they must stay the same, second for second.
func test_a_loaded_game_carries_on_the_same() -> void:
	var golden := GoldenTests.new()
	var original := _bot_at(2, 600.0)
	var s := original.s
	t.check(
		not s.won and s.tech_tree.researched.has("haulers"),
		"set up: map 2 at %d s, haulers researched, not won yet" % roundi(original.clock)
	)
	t.check(
		s.people.kith.any(func(k): return not k["task"].is_empty()) and not s.world.roads.is_empty(),
		"with haulers on a task and roads laid"
	)
	var loaded_game := Sim.new()
	var text_form := RunSave.to_json(RunSave.dump(s))
	t.check(RunSave.restore(loaded_game, RunSave.from_json(text_form)), "the dump is loaded into a fresh Sim")
	var loaded := _clone(original, loaded_game)
	t.check(golden.state_hash(loaded.s) == golden.state_hash(s), "the loaded copy starts with the same hash")
	var same := true
	for chunk in 6:
		for i in 150:  # 15 s a chunk, 90 s in all
			original.step(true)
			loaded.step(true)
		var h1 := golden.state_hash(original.s)
		var h2 := golden.state_hash(loaded.s)
		if h1 != h2 or text(RunSave.dump(original.s)) != text(RunSave.dump(loaded.s)):
			same = false
			t.check(
				false,
				"the copy went its own way within %d s (hash %s vs %s)" % [(chunk + 1) * 15, h1.left(10), h2.left(10)]
			)
			break
	t.check(same, "90 s on, the original and the loaded copy have the same hash and the same full dump")
	t.check(
		original.s.town.buildings.size() > 10 and original.clock > 690.0,
		"(and the game did move: %d buildings)" % original.s.town.buildings.size()
	)


## The bot plays map 3 straight through, but at three points its game is dumped to JSON and swapped for a fresh
## Sim restored from that dump. It must still win at the golden time, with the golden hash.
func test_the_bot_wins_on_time_through_restores() -> void:
	var golden := GoldenTests.new()
	if not golden.load_golden(t):
		return
	var bot := Autoplay.new()
	var game := Sim.new()
	game.generate(3)
	bot.attach(game)
	var points := [250.0, 550.0, 800.0]
	var restored := 0
	while bot.clock < 30 * 60.0 and not bot.s.won:
		if not points.is_empty() and bot.clock >= points[0]:
			points.remove_at(0)
			var fresh := Sim.new()
			if RunSave.restore(fresh, RunSave.from_json(RunSave.to_json(RunSave.dump(bot.s)))):
				bot.s = fresh
				restored += 1
		bot.step(true)
	t.check(restored == 3, "the game was dumped and restored at three points (%d)" % restored)
	golden.check_run(3, bot)  # the win time and the state hash of tests/golden.json


## Remove a temporary file under user://.
func _delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
