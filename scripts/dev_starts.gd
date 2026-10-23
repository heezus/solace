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
const StartTidy = preload("res://scripts/start_tidy.gd")
const RunSave = preload("res://scripts/run_save.gd")
const AutoplayBronze = preload("res://tests/autoplay_bronze.gd")
const AutoplayLivewire = preload("res://tests/autoplay_livewire.gd")
const AutoplayStarfall = preload("res://tests/autoplay_starfall.gd")

const MAP_SEED := 1  # every start is on this map
const BOT_LIMIT := 70.0 * 60.0  # the most game seconds a bot may play to reach a boundary
const STEP := 0.5  # seconds of one scripted tick
const SPOT_RADIUS := 16  # how far from the Hearth a scripted building may be put
const TRUST_MARKET := 40.0  # trust at the market start: well past the point where the Lumen would trade
const TIDE_START_SECONDS := 420.0  # how long the tide has crept at the Livewire tide start
const END_FUSE := 4.0  # seconds before the Kith talk the last guesses over at the ending start

const REV := 2  # bump when a bot's play changes without a change to Data: it throws away every start kept on disk
const CACHE_DIR := "user://stage_starts/"
const BAKED_DIR := "res://stage_starts/"  # starts baked at release time (tests/tools/bake_starts.gd); not in the repo
const EXT := ".run"  # not .json: an export takes such a file only through the include filter, never as a resource

## The checkpoints the Livewire bot's own play passes, and the mark of its that sets each off. They are saves of a town earned
## from a fresh game (the pacing bots play the stone age, Bronze and the Falling Star, the Starfall bot plays that era through the
## game's own systems, then the Ironfall and Livewire bots play on), with nothing handed over: what playtesters start mid-game from.
## There is none for the Livewire gate: the bot runs out of coal before it (page 23), so no honest town exists there yet.
const EARNED := {
	"earned_ironfall_steam": "steam_cart",
	"earned_livewire": "livewire_begins",
}

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
			var s: Sim = row[2].call()
			StartTidy.tidy(s)  # the bots' surplus pauses are not a player's start
			return s
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
		["starfall_landing", "Stage: Starfall, the landing (scripted, not for balance)", _starfall_landing],
		["starfall_camp", "Stage: Starfall, camp and first glyphs (scripted, not for balance)", _starfall_camp],
		["starfall_market", "Stage: Starfall, the market (scripted, not for balance)", _starfall_market],
		["starfall_end", "Stage: Starfall, before the ending (scripted, not for balance)", _starfall_end],
		["ironfall", "Stage: Ironfall, the Starfall is over (scripted, not for balance)", _ironfall],
		[
			"ironfall_teardown",
			"Stage: Ironfall, Teardown and the Wreck's parts (scripted, not for balance)",
			_ironfall_teardown
		],
		[
			"ironfall_steam",
			"Stage: Ironfall, steam: a Boiler, a Forge and Rail to lay (scripted, not for balance)",
			_ironfall_steam
		],
		["livewire", "Stage: Livewire, the wires hum (scripted, not for balance)", _livewire],
		[
			"livewire_tide",
			"Stage: Livewire, the tide: seven minutes in, every tool learned (scripted, not for balance)",
			_livewire_tide
		],
		[
			"livewire_gate",
			"Stage: Livewire, the factories: the gate is all that is left (scripted, not for balance)",
			_livewire_gate
		],
		[
			"earned_ironfall_steam",
			"Checkpoint: Ironfall, the Steam Cart rolls (earned)",
			_earned.bind("earned_ironfall_steam")
		],
		["earned_livewire", "Checkpoint: Livewire begins (earned)", _earned.bind("earned_livewire")],
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


## A checkpoint of the earned run, kept as the other bot stages are; one run makes them all.
static func _earned(id: String) -> Sim:
	return _kept(id, _play_earned.bind(id))


static func _play_earned(id: String) -> String:
	var bot := AutoplayLivewire.new()
	bot.watch = EARNED.duplicate()
	bot.stop_when_watched = true
	bot.on_checkpoint = func(name: String, b): _keep(name, RunSave.to_json(RunSave.dump(b.s)))
	bot.play_livewire(_earned_ironfall(), BOT_LIMIT * 2.0)
	return _memo[id]


## The Starfall era played by its bot on the earned Falling Star, through the game's systems only (no gifts, no edits of trust or
## answers), to the moment Ironfall begins. Unlike _ironfall(), nothing here is for the UI tests: it is the real chain.
static func _earned_ironfall() -> Sim:
	var game := _falling_star()
	var bot := AutoplayStarfall.new()
	bot.play_starfall(game, game.seasons.time, BOT_LIMIT)
	_wait(game, 2.0)
	return game


# --- The Starfall stages: scripted on top of the Falling Star ----------------


## The star has come down and the strangers have walked out of the fog.
static func _starfall_landing() -> Sim:
	return _landing_on(_falling_star())


static func _landing_on(s: Sim) -> Sim:
	_wait(s, Data.LANDING_DELAY + Data.ARRIVAL_DELAY + 1.0)
	return s


## The Glyph Wall has copied the first set and the Kith read it: the strangers have a name, and the Lumen Camp and the
## Expedition Post stand.
static func _starfall_camp() -> Sim:
	return _camp_on(_starfall_landing())


static func _camp_on(s: Sim) -> Sim:
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
	return _market_on(_starfall_camp())


static func _market_on(s: Sim) -> Sim:
	s.starfall.nudge(TRUST_MARKET - s.starfall.trust)
	_wait(s, 2.0)
	_build(s, "lumen_market")
	_wait(s, 2.0)
	return s


## Five sets read and every question answered, the Warning copied and guessed right: the Kith read it at the next talk, a
## few seconds on, and the era ends.
static func _starfall_end() -> Sim:
	return _end_on(_starfall_market())


static func _end_on(s: Sim) -> Sim:
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
	return _ironfall_on(_starfall_end())


static func _ironfall_on(s: Sim) -> Sim:
	_wait(s, END_FUSE + 6.0)
	s.starfall.choose(0)
	_wait(s, 2.0)
	return s


## Teardown is learned and the south is open: a Bench stands beside the Hearth and the Wreck's three parts are in the pack,
## so the first Lessons are a haul away. The Lumen Camp is there for its own parts.
static func _ironfall_teardown() -> Sim:
	return _teardown_on(_ironfall())


static func _teardown_on(s: Sim) -> Sim:
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
	return _steam_on(_ironfall_teardown())


static func _steam_on(s: Sim) -> Sim:
	for tech in ["ironstone", "bloomery", "iron_tools", "boiler", "rails", "blast_furnace"]:
		s.tech_tree.researched[tech] = true
	for id in ["coal", "iron", "wood", "brick", "stone"]:
		s.economy.add(id, 300)
	_build(s, "boiler", 2)
	if not _build_beside(s, "forge", _where(s, "boiler")):
		_build(s, "forge", 2)  # no room beside the Boiler: anywhere will do
	_build(s, "steam_shed", 2)
	_wait(s, 2.0)
	return s


## The Wires Hum card is put away and Livewire has begun, on top of the steam start: the gate's techs and the Bloom Lessons are
## learned, the stores hold Steel, Rope and Copper for Power Poles, the Order Board and the Generator, and a Grindstone and a
## Smelter stand beyond the Boiler's reach, ready to be put on a net.
static func _livewire() -> Sim:
	return _livewire_on(_ironfall_steam())


static func _livewire_on(s: Sim) -> Sim:
	for tech in ["shard_lamps", "shard_boiler", "steel", "bloom_sampling", "livewire"]:
		s.tech_tree.researched[tech] = true
	s.teardown.lessons.append_array(["spore", "root", "sap"])
	for id in ["steel", "rope", "copper", "coal", "iron", "wood", "brick", "stone"]:
		s.economy.add(id, 300)
	for type in ["grindstone", "smelter"]:
		_build_out_of_reach(s, type)
	s.story.record(Data.LIVEWIRE_EVENT)  # the card is put away at once in a start: Livewire begins on the next tick
	_wait(s, 2.0)
	return s


## Livewire seven minutes into the tide: the stage 1 and 2 techs are learned, the stores hold Wire, Coal and Steel for Poles, Arc
## Lamps, Scorchers and Firebreaks, and the Bloom has crept for TIDE_START_SECONDS out of the south patches, so its front is on the
## map and Tide Watch has something to show.
static func _livewire_tide() -> Sim:
	return _livewire_tide_on(_livewire())


static func _livewire_tide_on(s: Sim) -> Sim:
	s.tide.begin(s)  # the hum has been heard: the scripted start wakes the tide at once, whatever the Generator does
	_learn(s, ["power_poles", "order_board", "generator", "tide_watch", "arc_lamps", "scorcher", "living_ground"])
	for id in ["wire", "coal", "steel", "copper", "brick"]:
		s.economy.add(id, 200)
	_lay_net(s)
	_wait(s, TIDE_START_SECONDS)
	return s


## Mark these techs learned, and everything each one needs: a start never holds a tech whose requirements are missing, so the tech
## tree's slots and routes read as they would in a real run.
static func _learn(s: Sim, techs: Array) -> void:
	for tech in techs:
		if s.tech_tree.researched.has(tech):
			continue
		s.tech_tree.researched[tech] = true
		_learn(s, Data.TECHS[tech].get("requires", []))


## What the first two stages' goals ask, done, so the Goals panel at a later start is not stuck on "Lay two Power Poles": a
## Generator with two Poles beside it and a Wire Mill on the net, the Order Board with one order written, and a few seconds for
## the order to fire.
static func _lay_net(s: Sim) -> void:
	_build(s, "generator", 2)
	var gen := _where(s, "generator")
	_build_near(s, "power_pole", gen, Data.POLE_REACH)
	var pole := _where(s, "power_pole")
	_build_near(s, "power_pole", pole, Data.POLE_LINK)
	_build_near(s, "wire_mill", pole, Data.POLE_REACH)
	_build(s, "order_board", 1)
	if s.livewire.add(s):
		s.livewire.orders[0].merge(
			{"item": "coal", "compare": "above", "number": 5, "verb": "pause", "target": "forge"}, true
		)
	_wait(s, 10.0)


## Livewire's last stage: on the tide start, the Factory Floor, Shard Dynamo and Chain Orders are learned and the stores hold what
## the Skyward gate costs, so the player has only the two deeds (five orders written, the south held) and the last tech left.
static func _livewire_gate() -> Sim:
	return _livewire_gate_on(_livewire_tide())


static func _livewire_gate_on(s: Sim) -> Sim:
	_learn(s, ["factory_floor", "shard_dynamo", "chain_orders"])
	for id in ["steel", "iron", "wire", "brick"]:
		s.economy.add(id, 200)
	var pole := _where(s, "power_pole")
	for type in ["arc_lamp", "scorcher", "factory_floor", "shard_dynamo"]:
		_build_near(s, type, pole, Data.POLE_REACH)
	for p in s.tide.grown:  # one tile of the Bloom burnt clear: the goal for it is met
		s.tide.clear(s, p)
		break
	_wait(s, 2.0)
	return s


## Put `type` down on the nearest free tile to the Hearth that is out of every engine's reach, lit or not (a Boiler reaches only
## while it burns, which a start cannot count on), paid for like _build: a machine for a Power Pole net to reach. Anywhere will do
## when there is no such spot.
static func _build_out_of_reach(s: Sim, type: String) -> void:
	for r in range(4, SPOT_RADIUS):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p: Vector2i = s.world.camp_pos + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) != r or _in_reach_of_an_engine(s, p):
					continue
				var why := s.town.placement_error(type, p)
				if why == "Not enough materials" or why == "":
					var price: Dictionary = s.town.price(type)
					for id in price:
						if s.economy.inv.get(id, 0) < price[id]:
							s.economy.add(id, price[id] - s.economy.inv.get(id, 0))
					if s.place(type, p):
						return
	_build(s, type, 2)


## True when an engine (a Water Wheel, a Boiler lit or not) reaches p.
static func _in_reach_of_an_engine(s: Sim, p: Vector2i) -> bool:
	return s.town.buildings.any(
		func(b):
			var def: Dictionary = Data.BUILDINGS[b["type"]]
			return def["kind"] == "power" and Vector2(b["pos"]).distance_to(Vector2(p)) <= def["radius"] + 1.0
	)


# --- The Ironfall starts on any map (the pacing tool) --------------------------


## The Ironfall start `id` ("ironfall", "ironfall_teardown", "ironfall_steam" or "livewire") on the map made from `seed_value`, for the
## pacing bot (tests/tools/pace.gd): a bot plays that map to the Falling Star (minutes of real time; map MAP_SEED uses the
## kept start), then the same scripted stages run on it as for the starts above. `dir` keeps the Falling Star of a map between
## runs ("" keeps none); the files in it are not fingerprinted, so clear it when an earlier era's numbers change.
static func ironfall_on_map(seed_value: int, id: String, dir := "") -> Sim:
	var s := _falling_star() if seed_value == MAP_SEED else _star_on_map(seed_value, dir)
	s = _ironfall_on(_end_on(_market_on(_camp_on(_landing_on(s)))))
	if id == "ironfall":
		return s
	s = _teardown_on(s)
	if id == "ironfall_teardown":
		return s
	s = _steam_on(s)
	return s if id == "ironfall_steam" else _livewire_on(s)


## The earned checkpoint `id` ("earned_ironfall_steam" or "earned_livewire") on map `seed_value`: the pacing bots play the stone age and
## Bronze Dawn, the Starfall bot plays Starfall, then the Ironfall and Livewire bots play on to the mark. Map MAP_SEED uses the kept
## start. A run takes minutes of real time, so `dir` keeps the checkpoint of a map between runs ("" keeps none); the files in it are
## not fingerprinted, so clear it when an earlier era's numbers change.
static func earned_on_map(seed_value: int, id: String, dir := "") -> Sim:
	if seed_value == MAP_SEED:
		return build(id)
	var file := dir + "%s_map%d.run" % [id, seed_value]
	var text := ""
	if dir != "" and FileAccess.file_exists(file):
		text = FileAccess.get_file_as_string(file)
	if text == "":
		var game := star_on_map(seed_value, dir)
		var star := AutoplayStarfall.new()
		star.play_starfall(game, game.seasons.time, BOT_LIMIT)
		_wait(game, 2.0)
		var kept := []
		var bot := AutoplayLivewire.new()
		bot.watch = {id: EARNED[id]}
		bot.stop_when_watched = true
		bot.on_checkpoint = func(_name: String, b): kept.append(RunSave.to_json(RunSave.dump(b.s)))
		bot.play_livewire(game, BOT_LIMIT * 2.0)
		text = kept[0] if not kept.is_empty() else ""
		if text != "" and dir != "":
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
			var out := FileAccess.open(file, FileAccess.WRITE)
			if out != null:
				out.store_string(text)
				out.close()
	if text == "":
		return null
	var s := Sim.new()
	RunSave.restore(s, RunSave.from_json(text))
	StartTidy.tidy(s)
	return s


## The Falling Star on map `seed_value`, played by the bots (the stone age, Bronze Dawn, the first Bronze), kept in `dir` if given.
static func star_on_map(seed_value: int, dir := "") -> Sim:
	return _falling_star() if seed_value == MAP_SEED else _star_on_map(seed_value, dir)


## The Falling Star on map `seed_value`: played by the bots, or read from `dir`.
static func _star_on_map(seed_value: int, dir: String) -> Sim:
	var file := dir + "falling_star_map%d.run" % seed_value
	var text := ""
	if dir != "" and FileAccess.file_exists(file):
		text = FileAccess.get_file_as_string(file)
	if text == "":
		var bot := AutoplayBronze.new()
		bot.play_to_star(seed_value, BOT_LIMIT)
		text = RunSave.to_json(RunSave.dump(bot.s))
		if dir != "":
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
			var out := FileAccess.open(file, FileAccess.WRITE)
			if out != null:
				out.store_string(text)
				out.close()
	var s := Sim.new()
	RunSave.restore(s, RunSave.from_json(text))
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


## Where the first building of `type` stands.
static func _where(s: Sim, type: String) -> Vector2i:
	for b in s.town.buildings:
		if b["type"] == type:
			return b["pos"]
	return s.world.camp_pos


## Put `type` down on the nearest free tile to `at` that is within the Boiler's reach of it (5 tiles), paid for like _build.
static func _build_beside(s: Sim, type: String, at: Vector2i) -> bool:
	return _build_near(s, type, at, Data.BUILDINGS["boiler"]["radius"])


## Put `type` down on the nearest free tile to `at` that is no more than `reach` tiles from it (and not on it), paid for like _build.
static func _build_near(s: Sim, type: String, at: Vector2i, reach: float) -> bool:
	for r in range(1, int(reach) + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p: Vector2i = at + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) != r or Vector2(p).distance_to(Vector2(at)) > reach:
					continue
				var why := s.town.placement_error(type, p)
				if why == "Not enough materials" or why == "":
					var price: Dictionary = s.town.price(type)
					for id in price:
						if s.economy.inv.get(id, 0) < price[id]:
							s.economy.add(id, price[id] - s.economy.inv.get(id, 0))
					if s.place(type, p):
						return true
	return false


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
