extends RefCounted
## Stage starts: a run begun at a chosen stage, on a fixed map (seed 1) with the town already built, so any stage can be
## tested or debugged without playing up to it. Nothing here is committed as a save: a start is built on demand by running
## the pacing bots (tests/autoplay.gd, tests/autoplay_bronze.gd) to the stage boundary and then, for the stages no bot
## reaches (the Starfall era), a short scripted setup on top of the Falling Star state. So every start is deterministic and
## follows the balance by itself: change a price or a delay and the next build is the new stage.
## To add a start: one line in `_table()` (id, label, the function that builds it) and the function.
## The Load screen lists these (read-only: a start begins a new run, and Save always writes to a save slot).
## Static, like Hands and Ranks; `build` returns a ready Sim, `list` the ids and labels in order.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const AutoplayBronze = preload("res://tests/autoplay_bronze.gd")

const MAP_SEED := 1  # every start is on this map
const BOT_LIMIT := 70.0 * 60.0  # the most game seconds a bot may play to reach a boundary
const STEP := 0.5  # seconds of one scripted tick
const SPOT_RADIUS := 16  # how far from the Hearth a scripted building may be put
const TRUST_MARKET := 40.0  # trust at the market start: well past the point where the Lumen would trade
const END_FUSE := 4.0  # seconds before the Kith talk the last guesses over at the ending start

const REV := 1  # bump when a bot's play changes without a change to Data: it throws away every start kept on disk
const CACHE_DIR := "user://stage_starts/"
const BAKED_DIR := "res://stage_starts/"  # starts baked at release time (tests/tools/bake_starts.gd); not in the repo
const EXT := ".run"  # not .json: an export takes such a file only through the include filter, never as a resource

## Where the slow starts (the ones a bot plays to) are kept between sessions; "" keeps none. A kept start is used only when
## its fingerprint (every Data constant, REV and the save version) is the same, so a balance change builds it afresh.
## Before that cache a start is looked for in `baked_dir`: the release builds ship the slow starts baked, so the first click
## is as quick as the rest. Neither folder need exist: the start is then built on demand.
static var cache_dir := CACHE_DIR
static var baked_dir := BAKED_DIR
static var _print := ""  # the fingerprint, worked out once
static var _memo := {}  # id -> the start as run-save text: built once a session, since five starts begin on the Falling Star


## The starts in the order the Load screen shows them: [{"id", "label"}].
static func list() -> Array:
	return _table().map(func(row): return {"id": row[0], "label": row[1]})


## The ids alone.
static func ids() -> Array:
	return _table().map(func(row): return row[0])


## A Sim at the start `id`, or null for an id that is not in the list. It is a new Sim each time.
static func build(id: String) -> Sim:
	for row in _table():
		if row[0] == id:
			return row[2].call()
	return null


## Forget what this session has built (the files on disk stay), so the next build runs the bot again or reads the file.
static func clear_cache() -> void:
	_memo.clear()


## What the kept starts were built from: every Data constant, REV and the save version, as a short string.
static func fingerprint() -> String:
	if _print != "":
		return _print
	var script: Script = Data
	var map: Dictionary = script.get_script_constant_map()
	var keys := map.keys().map(func(k): return String(k))  # sorted as text: StringNames do not sort by their letters
	keys.sort()
	var h := REV * 1000 + RunSave.VERSION
	for k in keys:
		if typeof(map[k]) != TYPE_OBJECT:
			h = (h * 31 + ("%s=%s" % [k, var_to_str(map[k])]).hash()) & 0x7fffffff
	_print = str(h)
	return _print


## The start `id` as a new Sim: from this session's memo, else the baked file, else the file kept on disk, else `make` (a
## bot's long play, giving the start as run-save text), kept in the memo and on disk. It is always read back from that text,
## so the first build and every later one are the same game.
static func _kept(id: String, make: Callable) -> Sim:
	var text: String = _memo.get(id, "")
	if text == "":
		text = _read_file(baked_dir, id)
	if text == "":
		text = _read_file(cache_dir, id)
	if text == "":
		text = make.call()
		_keep(id, text)
	_memo[id] = text
	var s := Sim.new()
	RunSave.restore(s, RunSave.from_json(text))
	return s


## Keep `text` as the start `id`, in the session and on disk.
static func _keep(id: String, text: String) -> void:
	_memo[id] = text
	_write_file(id, text)


static func _file(dir: String, id: String) -> String:
	return dir + id + EXT


## The run-save text kept in `dir` for `id`, or "" when there is none or it is from another fingerprint.
static func _read_file(dir: String, id: String) -> String:
	if dir == "" or not FileAccess.file_exists(_file(dir, id)):
		return ""
	var kept := RunSave.from_json(FileAccess.get_file_as_string(_file(dir, id)))
	if kept.get("fingerprint", "") != fingerprint() or not RunSave.is_run_save(kept.get("run")):
		return ""
	return RunSave.to_json(kept["run"])


static func _write_file(id: String, text: String) -> void:
	if cache_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_dir))
	var file := FileAccess.open(_file(cache_dir, id), FileAccess.WRITE)
	if file != null:
		file.store_string('{"fingerprint": "%s", "run": %s}' % [fingerprint(), text])
		file.close()


## One row per start: [id, label, builder].
static func _table() -> Array:
	return [
		["stone_age", "Stage: Stone Age, a fresh map", _stone_age],
		["stone_late", "Stage: Stone Age, Bronze Dawn found", _stone_late],
		["bronze_first", "Stage: Bronze Dawn, first Bronze", _bronze_first],
		["falling_star", "Stage: Bronze Dawn, the Falling Star", _falling_star],
		["starfall_landing", "Stage: Starfall, the landing", _starfall_landing],
		["starfall_camp", "Stage: Starfall, camp and first glyphs", _starfall_camp],
		["starfall_market", "Stage: Starfall, the market", _starfall_market],
		["starfall_end", "Stage: Starfall, before the ending", _starfall_end],
		["ironfall", "Stage: Ironfall, the Starfall is over", _ironfall],
		["ironfall_teardown", "Stage: Ironfall, Teardown and the Wreck's parts", _ironfall_teardown],
		["ironfall_steam", "Stage: Ironfall, steam: a Boiler, a Forge and Rail to lay", _ironfall_steam],
	]


# --- The bot stages ----------------------------------------------------------


static func _stone_age() -> Sim:
	var s := Sim.new()
	s.generate(MAP_SEED)
	return s


## The stone age played to the moment Bronze Dawn is discovered.
static func _stone_late() -> Sim:
	return _kept("stone_late", _play_era.bind("stone_late"))


## On to the first Bronze, the end of the era's first stage.
static func _bronze_first() -> Sim:
	return _kept("bronze_first", _play_era.bind("bronze_first"))


## The Falling Star has just fallen: the era after it begins with its silence.
static func _falling_star() -> Sim:
	return _kept("falling_star", _play_era.bind("falling_star"))


## One bot plays the whole era (it passes each of the three boundaries on the way, so all three starts come from one run,
## each kept as it is passed). Returns the run-save text of the start `id`.
static func _play_era(id: String) -> String:
	var bot := AutoplayBronze.new()
	bot.on_dawn = func(b): _keep("stone_late", RunSave.to_json(RunSave.dump(b.s)))
	bot.on_bronze = func(b): _keep("bronze_first", RunSave.to_json(RunSave.dump(b.s)))
	bot.play_to_star(MAP_SEED, BOT_LIMIT)
	_keep("falling_star", RunSave.to_json(RunSave.dump(bot.s)))
	return _memo[id]


# --- The Starfall stages: scripted on top of the Falling Star ----------------


## The star has come down and the strangers have walked out of the fog.
static func _starfall_landing() -> Sim:
	var s := _falling_star()
	_wait(s, Data.LANDING_DELAY + Data.ARRIVAL_DELAY + 1.0)
	return s


## The Glyph Wall has copied the first set and the Kith read it: the strangers have a name, and the Lumen Camp and the
## Expedition Post stand.
static func _starfall_camp() -> Sim:
	var s := _starfall_landing()
	_build(s, "glyph_wall")
	_wait(s, Data.COPY_SECONDS * 3.0 + 1.0)
	_guess_right(s, 1)
	_wait(s, Data.CHECK_SECONDS + 1.0)
	_build(s, "lumen_camp")
	_build(s, "expedition_post")
	_wait(s, 2.0)
	return s


## Trust has grown, the Lumen would trade, and the Market stands.
static func _starfall_market() -> Sim:
	var s := _starfall_camp()
	s.starfall.nudge(TRUST_MARKET - s.starfall.trust)
	_wait(s, 2.0)
	_build(s, "lumen_market")
	_wait(s, 2.0)
	return s


## Five sets read and every question answered, the Warning copied and guessed right: the Kith read it at the next talk, a
## few seconds on, and the era ends.
static func _starfall_end() -> Sim:
	var s := _starfall_market()
	for n in range(1, 6):
		s.starfall.locked[Data.GLYPH_SETS[n]["id"]] = true
	for id in Data.MOMENT_ORDER:
		s.starfall.answered[id] = 0
	for g in Data.GLYPH_SETS[6]["glyphs"]:
		if g not in s.starfall.copied:
			s.starfall.copied.append(g)
		s.starfall.guesses[g] = Data.GLYPHS[g]["word"]
	s.starfall.check_clock = Data.CHECK_SECONDS - END_FUSE
	return s


## The Warning is read, the ending card put away and the first tick of Ironfall run: its techs are in view and the coal and
## iron wait in the land south of the map for Coal Seams or Ironstone.
static func _ironfall() -> Sim:
	var s := _starfall_end()
	_wait(s, END_FUSE + 6.0)
	s.starfall.choose(0)
	_wait(s, 2.0)
	return s


## Teardown is learned and the south is open: a Bench stands beside the Hearth and the Wreck's three parts are in the pack,
## so the first Lessons are a haul away. The Lumen Camp is there for its own parts.
static func _ironfall_teardown() -> Sim:
	var s := _ironfall()
	for tech in ["coal_seams", "teardown"]:
		s.tech_tree.researched[tech] = true
	_build(s, "teardown_bench", 1)
	for id in Data.WRECK_PARTS:
		s.teardown.wreck_taken.append(id)
		s.teardown.add_part(id)
	_wait(s, 2.0)
	return s


## Steam is learned (Boiler, Rails, the Blast Furnace and what they follow) and a Boiler, a Forge and a Steam Shed stand near the
## Hearth with coal, iron and the materials for Rail in the stores: the Livewire gate is the next thing to build toward.
static func _ironfall_steam() -> Sim:
	var s := _ironfall_teardown()
	for tech in ["ironstone", "bloomery", "iron_tools", "boiler", "rails", "blast_furnace"]:
		s.tech_tree.researched[tech] = true
	for id in ["coal", "iron", "wood", "brick", "stone"]:
		s.economy.add(id, 300)
	for type in ["boiler", "forge", "steam_shed"]:
		_build(s, type, 2)
	_wait(s, 2.0)
	return s


# --- Scripted steps ----------------------------------------------------------


## Run `s` forward `seconds` of game time.
static func _wait(s: Sim, seconds: float) -> void:
	for i in int(ceil(seconds / STEP)):
		s.tick(STEP)
		s.events.clear()


## Set the guesses of glyph set `n` to the right words, the way a player would after copying them.
static func _guess_right(s: Sim, n: int) -> void:
	for g in Data.GLYPH_SETS[n]["glyphs"]:
		while s.starfall.guesses.get(g, "") != Data.GLYPHS[g]["word"]:
			if s.starfall.cycle_guess(g) == "":
				break


## Put `type` down on the nearest free tile to the Hearth, paid for (the start gives the town the materials, as a bot
## that had saved up would have). Rings from `from` tiles out, so a building that must stand near the Hearth can take a spot
## next to it when the town has filled the rest. False when there is no room.
static func _build(s: Sim, type: String, from := 2) -> bool:
	for r in range(from, SPOT_RADIUS):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var p: Vector2i = s.world.camp_pos + Vector2i(dx, dy)
				if s.town.placement_error(type, p) == "Not enough materials" or s.town.placement_error(type, p) == "":
					var price: Dictionary = s.town.price(type)
					for id in price:
						if s.economy.inv.get(id, 0) < price[id]:
							s.economy.add(id, price[id] - s.economy.inv.get(id, 0))
					if s.place(type, p):
						return true
	return false
