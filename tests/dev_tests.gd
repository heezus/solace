extends RefCounted
## Stage starts, save slots and the debug keys (scripts/dev_starts.gd, scripts/save_slots.gd, scripts/slot_screen.gd,
## scripts/debug_keys.gd, scripts/launch.gd). run() is quick and runs everywhere (the starts it builds need no bot: the fresh
## map). run_starts() builds every start, and the bot-made ones take minutes of play, so run_tests.gd skips it with `-- fast`
## (or runs it alone with `-- starts`). Nothing touches the player's files: the tests keep to their own folder under user://.
## Run from tests/run_tests.gd, which owns check().

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Launch = preload("res://scripts/launch.gd")
const DevStarts = preload("res://scripts/dev_starts.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const SlotScreen = preload("res://scripts/slot_screen.gd")
const DebugKeys = preload("res://scripts/debug_keys.gd")

const DIR := "user://test_dev/"
const SECONDS := 60.0  # simulated seconds each start is ticked
const DT := 0.1

var t  # the runner, tests/run_tests.gd


## Stands in for the game scene (scripts/main.gd) where the debug keys act on it.
class Flag:
	var visible := false

	func is_open() -> bool:
		return false


class FakeGame:
	var state: Sim
	var speed := 1
	var paused := true
	var toasts: Array = []
	var era_card := Flag.new()
	var moment_card := Flag.new()
	var game_menu := Flag.new()

	func _refresh_ui() -> void:
		pass

	func _toast(text: String, _seconds: float) -> void:
		toasts.append(text)


func run(runner) -> void:
	t = runner
	DevStarts.cache_dir = ""  # the tests never read or write the starts the player has kept...
	DevStarts.baked_dir = ""  # ...or the ones a release bakes in (a local bake would only hide what the bots make)
	test_the_list_is_well_formed()
	test_launch_hands_over_once()
	test_slots_save_and_load()
	test_slot_summaries_and_the_latest_save()
	test_an_old_save_moves_into_a_slot()
	test_a_stage_start_is_a_new_run_and_never_overwritten()
	test_the_slot_screen_lists_saves_and_starts()
	test_the_debug_keys_start_off_and_work()
	test_a_start_is_kept_between_sessions()
	test_the_export_ships_the_bots_and_nothing_else_of_tests()
	_clean()


## Every start: built, round-tripped through the run save, with a Hearth and buildings, ticked a minute; and the Starfall
## ones, which are scripted, built twice to the same text. (The bot's own play is pinned by the golden tests.)
func run_starts(runner) -> void:
	t = runner
	DevStarts.cache_dir = ""
	DevStarts.baked_dir = ""
	for id in DevStarts.ids():
		test_start(id)
	test_starts_are_deterministic()


func _clean() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR + f)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


func _fresh_dir() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))


func _json(s: Sim) -> String:
	return RunSave.to_json(RunSave.dump(s))


# --- The list ----------------------------------------------------------------


func test_the_list_is_well_formed() -> void:
	var list := DevStarts.list()
	var seen := {}
	for row in list:
		t.check(row["id"] != "" and row["label"].begins_with("Stage: "), "%s has an id and a label" % row["id"])
		t.check(not seen.has(row["id"]), "the id %s is used once" % row["id"])
		seen[row["id"]] = true
	t.check(list.map(func(r): return r["id"]) == DevStarts.ids(), "ids() is the list's ids in order")
	for id in [
		"stone_age",
		"stone_late",
		"bronze_first",
		"falling_star",
		"starfall_landing",
		"starfall_camp",
		"starfall_market",
		"starfall_end",
		"ironfall",
		"ironfall_teardown",
		"ironfall_steam",
		"livewire"
	]:
		t.check(seen.has(id), "the start %s is there" % id)
	t.check(DevStarts.build("no_such_start") == null, "an unknown start builds nothing")
	var print_a := DevStarts.fingerprint()
	t.check(print_a != "" and print_a == DevStarts.fingerprint(), "the fingerprint of the data is steady")


# --- Launch and the save slots -----------------------------------------------


func test_launch_hands_over_once() -> void:
	t.check(Launch.take_load() == 0 and Launch.take_stage().is_empty(), "a game starts new unless asked")
	Launch.ask_to_load(3)
	t.check(Launch.take_load() == 3 and Launch.take_load() == 0, "an ask to load a slot is read once")
	Launch.ask_stage({"a": 1})
	t.check(Launch.take_stage() == {"a": 1} and Launch.take_stage().is_empty(), "and so is a stage start")


func test_slots_save_and_load() -> void:
	_fresh_dir()
	var s := Sim.new()
	s.generate(3)
	s.economy.inv["wood"] = 41
	t.check(SaveSlots.summary(2, DIR) == Data.SLOT_EMPTY, "an unused slot is empty")
	t.check(
		not SaveSlots.save(s, 0, DIR) and not SaveSlots.save(s, SaveSlots.COUNT + 1, DIR), "there are only the slots"
	)
	t.check(SaveSlots.save(s, 2, DIR) and FileAccess.file_exists(SaveSlots.path(2, DIR)), "a slot is written")
	t.check(not FileAccess.file_exists(SaveSlots.path(1, DIR)), "and no other")
	var back := Sim.new()
	t.check(SaveSlots.load_into(back, 2, DIR), "and read back")
	t.check(back.economy.inv["wood"] == 41 and back.people.kith.size() == s.people.kith.size(), "with what was saved")
	t.check(back.world.camp_pos == s.world.camp_pos and back.town.buildings.size() == 1, "on the same map")
	var plain := RunSave.from_json(FileAccess.get_file_as_string(SaveSlots.path(2, DIR)))
	t.check(
		RunSave.is_run_save(plain) and plain["version"] == RunSave.VERSION,
		"a slot file is a run save of the same version"
	)
	var untouched := Sim.new()
	t.check(
		not SaveSlots.load_into(untouched, 4, DIR) and untouched.town.buildings.is_empty(),
		"an empty slot loads nothing"
	)
	var bad := FileAccess.open(SaveSlots.path(5, DIR), FileAccess.WRITE)
	bad.store_string("not a save")
	bad.close()
	t.check(
		not SaveSlots.load_into(Sim.new(), 5, DIR) and SaveSlots.summary(5, DIR) == Data.SLOT_EMPTY,
		"a damaged slot is refused"
	)
	t.check(SaveSlots.filled(DIR) == [2], "only the readable slot is listed")
	t.check(SaveSlots.save(s, 2, DIR), "a slot can be written over")


func test_slot_summaries_and_the_latest_save() -> void:
	_fresh_dir()
	var s := Sim.new()
	s.generate(3)
	s.economy.flows.clock = 125.0
	SaveSlots.save(s, 1, DIR)
	t.check(
		SaveSlots.summary(1, DIR) == "%s, 2 min, 3 Kith" % Data.ERA_STONE, "the summary: " + SaveSlots.summary(1, DIR)
	)
	s.won = true
	SaveSlots.save(s, 3, DIR)
	t.check(SaveSlots.summary(3, DIR).begins_with(Data.ERA_BRONZE), "Bronze Dawn once it is won")
	s.starfall.begin(false)
	SaveSlots.save(s, 4, DIR)
	t.check(SaveSlots.summary(4, DIR).begins_with(Data.ERA_STARFALL), "and Starfall once the star has fallen")
	# Slot 1 is made the oldest by hand: the newest is Continue's.
	var d := SaveSlots.read(1, DIR)
	d["meta"]["saved_at"] = 5
	var f := FileAccess.open(SaveSlots.path(1, DIR), FileAccess.WRITE)
	f.store_string(RunSave.to_json(d))
	f.close()
	var d4 := SaveSlots.read(4, DIR)
	d4["meta"]["saved_at"] = 9000000000
	f = FileAccess.open(SaveSlots.path(4, DIR), FileAccess.WRITE)
	f.store_string(RunSave.to_json(d4))
	f.close()
	t.check(SaveSlots.latest(DIR) == 4, "the newest save is the one Continue loads")
	_fresh_dir()
	t.check(SaveSlots.latest(DIR) == 0 and SaveSlots.filled(DIR).is_empty(), "with no saves there is no newest")


func test_an_old_save_moves_into_a_slot() -> void:
	_fresh_dir()
	var s := Sim.new()
	s.generate(3)
	s.economy.inv["wood"] = 17
	t.check(RunSave.save(s, SaveSlots.legacy_path(DIR)), "a save of the one-file days")
	t.check(SaveSlots.filled(DIR) == [1], "it is slot 1 when slots are first listed")
	t.check(not FileAccess.file_exists(SaveSlots.legacy_path(DIR)), "and the old file is gone")
	var back := Sim.new()
	t.check(SaveSlots.load_into(back, 1, DIR) and back.economy.inv["wood"] == 17, "the run is as it was")
	t.check(SaveSlots.summary(1, DIR).begins_with(Data.ERA_STONE), "and it has a summary")
	t.check(SaveSlots.migrate(DIR) == 0 and SaveSlots.filled(DIR) == [1], "nothing moves twice")
	RunSave.save(s, SaveSlots.legacy_path(DIR))
	t.check(SaveSlots.migrate(DIR) == 2, "with slot 1 taken it goes to the next empty one")
	var junk := FileAccess.open(SaveSlots.legacy_path(DIR), FileAccess.WRITE)
	junk.store_string("not a save")
	junk.close()
	t.check(
		SaveSlots.migrate(DIR) == 0 and FileAccess.file_exists(SaveSlots.legacy_path(DIR)),
		"a file that is no save is left alone"
	)
	_clean()


func test_a_stage_start_is_a_new_run_and_never_overwritten() -> void:
	_fresh_dir()
	var before_list := DevStarts.list()
	var before := _json(DevStarts.build("stone_age"))
	Launch.ask_stage(RunSave.dump(DevStarts.build("stone_age")))
	var s := Sim.new()
	t.check(Launch.start_into(s, DIR), "a stage start begins a game")
	t.check(not Launch.start_into(Sim.new(), DIR), "once: the next game is new again")
	t.check(
		s.world.camp_pos == DevStarts.build("stone_age").world.camp_pos and s.town.buildings.size() == 1,
		"on the start's map"
	)
	t.check(SaveSlots.filled(DIR).is_empty(), "it has made no save")
	s.economy.inv["wood"] = 99
	t.check(SaveSlots.save(s, 1, DIR) and SaveSlots.filled(DIR) == [1], "Save writes to a slot")
	t.check(DevStarts.list() == before_list, "the list of starts is as it was")
	t.check(_json(DevStarts.build("stone_age")) == before, "and a start is as it was: the slot took the change")
	Launch.ask_to_load(1)
	var loaded := Sim.new()
	t.check(Launch.start_into(loaded, DIR) and loaded.economy.inv["wood"] == 99, "a slot loads through Launch too")
	Launch.ask_to_load(4)
	t.check(not Launch.start_into(Sim.new(), DIR), "an empty slot is no start: the game begins on a new map")
	_clean()


func test_the_slot_screen_lists_saves_and_starts() -> void:
	_fresh_dir()
	var s := Sim.new()
	s.generate(3)
	SaveSlots.save(s, 2, DIR)
	var screen := SlotScreen.new()
	screen.dir = DIR
	screen.use_thread = false
	screen.setup()
	var picked := []
	screen.slot_picked.connect(func(n): picked.append(n))
	screen.open("load")
	t.check(
		_named(screen, "Slot_").size() == 1 and _named(screen, "Slot_2").size() == 1, "load lists the filled slot only"
	)
	t.check(_named(screen, "Start_").size() == DevStarts.list().size(), "and a button for each stage start")
	t.check(_named(screen, "Slot_2")[0].text.contains(SaveSlots.summary(2, DIR)), "the slot says what is in it")
	t.check(_named(screen, "Start_stone_age")[0].text == DevStarts.list()[0]["label"], "a start says its stage")
	_named(screen, "Slot_2")[0].pressed.emit()
	t.check(picked == [2], "picking a save says which")
	var built: Dictionary = screen._build("stone_age")
	t.check(
		RunSave.is_run_save(built) and screen._build("nope").is_empty(), "a start builds a run, an unknown one nothing"
	)
	screen.open("save")
	t.check(
		_named(screen, "Slot_").size() == SaveSlots.COUNT and _named(screen, "Start_").is_empty(),
		"save lists every slot, and no start"
	)
	t.check(_named(screen, "Slot_1")[0].text.ends_with(Data.SLOT_EMPTY), "an empty one says so")
	picked.clear()
	_named(screen, "Slot_1")[0].pressed.emit()
	t.check(picked == [1], "an empty slot is saved into at once")
	_named(screen, "Slot_2")[0].pressed.emit()
	t.check(picked == [1] and _named(screen, "Slot_2")[0].text.contains(Data.SLOT_OVERWRITE), "a filled one asks again")
	_named(screen, "Slot_2")[0].pressed.emit()
	t.check(picked == [1, 2], "and is written on the second click")
	screen.free()
	_clean()


func _named(node: Node, prefix: String) -> Array:
	var out := []
	for c in node.get_children():
		if c is Button and String(c.name).begins_with(prefix):
			out.append(c)
		out.append_array(_named(c, prefix))
	return out


# --- The debug keys ----------------------------------------------------------


func test_the_debug_keys_start_off_and_work() -> void:
	_fresh_dir()
	var old_path := DebugKeys.path
	DebugKeys.path = DIR + "debug_keys.cfg"
	DebugKeys.reset()
	t.check(not DebugKeys.on(), "the keys are off with no file")
	var game := FakeGame.new()
	game.state = Sim.new()
	game.state.generate(3)
	DebugKeys.press(game, KEY_F1)
	DebugKeys.press(game, KEY_F3)
	DebugKeys.press(game, KEY_F4)
	t.check(
		game.state.economy.inv.get("wood", 0) < 100 and game.speed == 1 and game.toasts.is_empty(),
		"off, no key does anything"
	)
	t.check(game.state.fog.count() < game.state.world.width * game.state.world.height, "and the fog stays")
	DebugKeys.set_on(true)
	DebugKeys.reset()
	t.check(DebugKeys.on(), "the choice is kept in the file")
	DebugKeys.press(game, KEY_F1)
	t.check(
		game.state.economy.inv["wood"] >= 100 and game.state.economy.inv.get("copper_ore", 0) == 0,
		"F1 stacks the stone age's goods"
	)
	game.state.won = true
	DebugKeys.press(game, KEY_F1)
	t.check(game.state.economy.inv["copper_ore"] >= 100, "and Bronze Dawn's once it is won")
	t.check(
		not game.state.economy.inv.has("bronze_tools") or game.state.economy.inv["bronze_tools"] == 0,
		"but not the tools that speed workers up"
	)
	var learned := game.state.tech_tree.researched.size()
	DebugKeys.press(game, KEY_F2)
	t.check(game.state.tech_tree.researched.size() > learned, "F2 researches what is ready")
	var seen := []
	for i in 5:
		DebugKeys.press(game, KEY_F3)
		seen.append(game.speed)
	t.check(seen == [3, 10, 30, 1, 3] and not game.paused, "F3 cycles 3x, 10x, 30x, 1x and goes on")
	DebugKeys.press(game, KEY_F4)
	t.check(game.state.fog.count() == game.state.world.width * game.state.world.height, "F4 lifts the fog")
	t.check(game.toasts.size() == 9, "each says what it did (%d toasts)" % game.toasts.size())
	game.moment_card.visible = true
	var speed := game.speed
	DebugKeys.press(game, KEY_F3)
	t.check(game.speed == speed, "the speed key waits while a card is up")
	DebugKeys.press(game, KEY_F5)
	t.check(game.toasts.size() == 9, "another key is none of its business")
	DebugKeys.set_on(false)
	DebugKeys.reset()
	t.check(not DebugKeys.on(), "and it can be turned off again")
	DebugKeys.path = old_path
	DebugKeys.reset()
	_clean()


# --- The kept starts ---------------------------------------------------------


## A start that took a bot is kept in a file with the data's fingerprint, and read from it next time; a different fingerprint
## is ignored. (Tried on the fresh map's text, which is cheap: the keeping works on any run.)
func test_a_start_is_kept_between_sessions() -> void:
	_fresh_dir()
	DevStarts.cache_dir = DIR
	DevStarts.clear_cache()
	var made := [0]
	var make := func() -> String:
		made[0] += 1
		return _json(DevStarts.build("stone_age"))
	var first: Sim = DevStarts._kept("kept_test", make)
	t.check(made[0] == 1 and FileAccess.file_exists(DIR + "kept_test.run"), "built once and written")
	var again: Sim = DevStarts._kept("kept_test", make)
	t.check(made[0] == 1 and _json(again) == _json(first), "the same session builds nothing more")
	DevStarts.clear_cache()
	var next: Sim = DevStarts._kept("kept_test", make)
	t.check(made[0] == 1 and _json(next) == _json(first), "a new session reads the file")
	var stale := FileAccess.open(DIR + "kept_test.run", FileAccess.WRITE)
	stale.store_string('{"fingerprint": "other", "run": %s}' % RunSave.to_json(RunSave.dump(first)))
	stale.close()
	DevStarts.clear_cache()
	DevStarts._kept("kept_test", make)
	t.check(made[0] == 2, "a file from other data is built afresh")
	# A baked start (shipped in a release) is read before the kept one, by the same fingerprint rule.
	DevStarts.cache_dir = ""
	DevStarts.baked_dir = DIR + "baked/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DevStarts.baked_dir))
	var run_text := _json(first)
	var baked := FileAccess.open(DevStarts.baked_dir + "baked_test.run", FileAccess.WRITE)
	baked.store_string('{"fingerprint": "%s", "run": %s}' % [DevStarts.fingerprint(), run_text])
	baked.close()
	DevStarts.clear_cache()
	var from_baked: Sim = DevStarts._kept("baked_test", make)
	t.check(made[0] == 2 and _json(from_baked) == run_text, "a baked start is read without building")
	baked = FileAccess.open(DevStarts.baked_dir + "baked_test.run", FileAccess.WRITE)
	baked.store_string('{"fingerprint": "other", "run": %s}' % run_text)
	baked.close()
	DevStarts.clear_cache()
	DevStarts._kept("baked_test", make)
	t.check(made[0] == 3, "a baked start from other data is built afresh")
	DevStarts.baked_dir = ""
	DevStarts.clear_cache()
	_clean()


## The game's title screen reaches the bots (tests/autoplay*.gd) through the stage starts, so the exports must ship those two
## files and what they load (all in scripts/), while the tests, their data and the tools stay out. Every other file under
## tests/ must match an exclude pattern of both presets, so a new test file is left out of the build or this test says so.
func test_the_export_ships_the_bots_and_nothing_else_of_tests() -> void:
	var cfg := ConfigFile.new()
	t.check(cfg.load("res://export_presets.cfg") == OK, "the export presets are readable")
	var filters := []
	for section in cfg.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			filters.append(String(cfg.get_value(section, "exclude_filter", "")).split(",", false))
	t.check(filters.size() == 2 and filters[0] == filters[1], "both presets exclude the same files")
	# The baked starts (stage_starts/*.run, made at release time and never committed) are shipped through the include filter.
	for section in cfg.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			var include := String(cfg.get_value(section, "include_filter", ""))
			t.check("stage_starts/x.run".matchn(include.strip_edges()), "%s ships the baked starts" % section)
	t.check(
		FileAccess.get_file_as_string("res://.gitignore").contains("/stage_starts/"),
		"and the baked folder is not committed"
	)
	t.check(
		DevStarts.BAKED_DIR == "res://stage_starts/" and DevStarts.EXT == ".run",
		"the loader reads where the bake writes"
	)
	t.check(
		FileAccess.get_file_as_string("res://.github/workflows/release.yml").contains("bake_starts.gd"),
		"and a release bakes first"
	)
	var files := _files("res://tests")
	t.check(files.size() > 50, "the tests folder was listed (%d files)" % files.size())
	for path in files:
		var rel: String = path.trim_prefix("res://")
		var ships: bool = rel.begins_with("tests/autoplay") and rel.ends_with(".gd")
		var excluded := false
		for pattern in filters[0]:
			excluded = excluded or rel.matchn(pattern.strip_edges())
		if rel.ends_with(".uid") or rel.ends_with(".import"):
			continue  # bookkeeping files go with their script
		t.check(excluded != ships, "%s is %s the exports" % [rel, "shipped in" if ships else "left out of"])


func _files(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir + "/" + d))
	return out


# --- Every start -------------------------------------------------------------


func test_start(id: String) -> void:
	var s := DevStarts.build(id)
	t.check(s != null, "%s builds" % id)
	if s == null:
		return
	t.check(s.town.buildings.size() >= 1 and s.town.building_at.has(s.world.camp_pos), "%s has a Hearth" % id)
	t.check(s.town.buildings[0]["type"] == "camp" and s.people.kith.size() > 0, "%s has the camp and Kith" % id)
	if id != "stone_age":
		t.check(s.town.buildings.size() > 10, "%s has a town (%d buildings)" % [id, s.town.buildings.size()])
	_expect_stage(id, s)
	# It round-trips through the run save, in memory and as text.
	var copy := Sim.new()
	t.check(RunSave.restore(copy, RunSave.dump(s)) and _json(copy) == _json(s), "%s restores to the same run" % id)
	var text_copy := Sim.new()
	t.check(RunSave.restore(text_copy, RunSave.from_json(_json(s))), "%s reads back from text" % id)
	t.check(
		text_copy.town.buildings.size() == s.town.buildings.size() and text_copy.economy.inv == s.economy.inv,
		"%s keeps its buildings and goods through text" % id
	)
	for i in int(SECONDS / DT):
		text_copy.tick(DT)
		text_copy.events.clear()
	t.check(text_copy.people.kith.size() > 0, "%s runs a minute, with the Kith still there" % id)


## What each start is, beyond a town.
func _expect_stage(id: String, s: Sim) -> void:
	match id:
		"stone_age":
			t.check(not s.won and s.town.buildings.size() == 1, "stone_age is a fresh map")
		"stone_late":
			t.check(s.won and s.economy.inv.get("bronze", 0) == 0, "stone_late stands at Bronze Dawn found")
		"bronze_first":
			t.check(s.won and s.economy.inv.get("bronze", 0) > 0, "bronze_first has made Bronze")
		"falling_star":
			t.check(s.starfall.stage == "falling" and s.story.has_event("star_falling"), "falling_star is the silence")
		"starfall_landing":
			t.check(
				s.starfall.arrived() and not s.starfall.has_building("glyph_wall"),
				"starfall_landing: the strangers are here"
			)
		"starfall_camp":
			var st = s.starfall
			t.check(
				st.has_building("glyph_wall") and st.has_building("lumen_camp") and st.has_building("expedition_post"),
				"the camp stands"
			)
			t.check(st.locked.has("name") and st.pending == "", "and the first set is read, with nothing asked yet")
		"starfall_market":
			t.check(
				s.starfall.has_building("lumen_market") and s.story.has_event("market_open"),
				"the market is open and built"
			)
			t.check(s.starfall.trust >= Data.MARKET_OPEN_TRUST, "with trust built")
		"starfall_end":
			var probe := Sim.new()
			RunSave.restore(probe, RunSave.dump(s))
			for i in int(30.0 / DT):
				probe.tick(DT)
			t.check(
				probe.starfall.ended and probe.story.has_event("warning_read"),
				"starfall_end ends the era within the half minute"
			)
		"ironfall":
			t.check(s.starfall.ended and s.starfall.pending == "", "ironfall: the Starfall is over and put away")
			t.check(s.story.has_event(Data.IRONFALL_EVENT), "and Ironfall has begun")
			t.check(s.tech_tree.tech_visible("coal_seams"), "so its first techs are in view")
		"ironfall_teardown":
			t.check(
				s.teardown.has_bench() and s.teardown.pack.size() + s.teardown.bench.size() == 3,
				"ironfall_teardown: a Bench and three parts"
			)
			t.check(s.world.is_grown_south(), "and the south is open")
		"ironfall_steam":
			t.check(
				["boiler", "forge", "steam_shed"].all(
					func(type): return s.town.buildings.any(func(b): return b["type"] == type)
				),
				"ironfall_steam: a Boiler, a Forge and a Steam Shed stand"
			)
			t.check(
				s.tech_tree.researched.has("rails") and s.economy.inv.get("coal", 0) > 100,
				"with Rails learned and coal in store"
			)
		"livewire":
			t.check(
				s.story.has_event(Data.LIVEWIRE_EVENT) and s.story.has_event(Data.LIVEWIRE_BEGUN),
				"livewire: the Wires Hum card is put away and Livewire has begun"
			)
			t.check(s.story.goal_list() == Data.GOALS_ERA5, "with its own goals")
			t.check(
				s.tech_tree.can_research("power_poles") and s.tech_tree.can_research("order_board"),
				"Power Poles and the Order Board can be bought"
			)
			t.check(not s.tech_tree.researched.has("power_poles"), "though neither is learned yet")
			# The bots' own Grindstones and Smelters stand where they like (some by a Water Wheel), so look for one of each out of reach.
			var out := func(type: String) -> bool:
				return s.town.buildings.any(func(b): return b["type"] == type and not s.town.is_powered(b["pos"]))
			t.check(
				out.call("grindstone") and out.call("smelter"),
				"a Grindstone and a Smelter stand unpowered, ready for a net"
			)
			t.check(s.livewire.nets.is_empty() and s.livewire.orders.is_empty(), "with no net and no order yet")


func test_starts_are_deterministic() -> void:
	for id in DevStarts.ids():
		var first := _json(DevStarts.build(id))
		t.check(first == _json(DevStarts.build(id)), "%s is the same run each build" % id)
