extends SceneTree
## Pacing report: the bot (tests/autoplay.gd) plays maps and prints when each tech came, with a trace
## of what held it up every minute. With `bronze` it plays on past Bronze Dawn to the first Bronze (the era's stage 1) and
## reports the minutes that took.
## With `star` it plays the whole era, on past the first Bronze to The Falling Star, and reports both spans.
## With `ironfall` it plays Ironfall (tests/autoplay_ironfall.gd) from a stage start to the Livewire gate and prints the clock at
## each goal: `ironfall` alone starts where the era does, `steam` or `teardown` after it starts at that stage start. Maps other
## than the starts' own (1) are played to the Falling Star first (minutes of real time); `cache` keeps that in user://pace_starts/
## (clear the folder when an earlier era's numbers change).
## With `starfall` it plays Starfall (tests/autoplay_starfall.gd) from The Falling Star, played by the bots first, to the ending.
## With `livewire` it plays on from the Ironfall start through the Livewire gate (the Wires Hum) to the Skyward tech and prints the
## clock at each Livewire goal (tests/autoplay_livewire.gd).
## With `baseline` it plays one map through all five eras in a row, every era by its bot with nothing handed over (stone age, Bronze
## Dawn, Starfall, Ironfall, Livewire), reads each era with tests/tools/era_probe.gd and writes one row per era to `out=<folder>`
## (seed_<map>.json). `minutes` is then the most the Ironfall and Livewire bot may play. `baseline` takes one map.
## Run: godot --headless --path . -s tests/tools/pace.gd --
##   [map|all] [minutes] [quiet] [bronze|star|ironfall [steam|teardown]|livewire|baseline [noseams] out=<folder>] [cache]

const Autoplay = preload("res://tests/autoplay.gd")
const AutoplayBronze = preload("res://tests/autoplay_bronze.gd")
const AutoplayIronfall = preload("res://tests/autoplay_ironfall.gd")
const AutoplayLivewire = preload("res://tests/autoplay_livewire.gd")
const AutoplayStarfall = preload("res://tests/autoplay_starfall.gd")
const DevStarts = preload("res://scripts/dev_starts.gd")
const EraProbe = preload("res://tests/tools/era_probe.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Sim = preload("res://scripts/sim.gd")

const BASELINE_SAVE_EVERY := 120.0  # game seconds between checkpoints of a baseline run
const BASELINE_SAVE_WALL_MS := 60000  # real milliseconds between checkpoints, so a slow stretch still saves
const LIVEWIRE_SAVE_EVERY := 300.0  # the same for a Livewire-alone run


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var maps: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	if not args.is_empty() and args[0] != "all":
		maps = [int(args[0])]
	var minutes := float(args[1]) if args.size() > 1 else 30.0
	var quiet := "quiet" in args
	if "bronze" in args:
		_bronze(maps, minutes, quiet)
		return
	if "star" in args:
		_star(maps, minutes, quiet)
		return
	if "baseline" in args:
		var out := ""
		var from := ""
		for a in args:
			if a.begins_with("out="):
				out = a.substr(4)
			if a.begins_with("from="):
				from = a.substr(5)
		if from != "":
			_from_livewire_start(int(args[0]), minutes, out, from, "notide" not in args)
			return
		_baseline(int(args[0]), minutes, out)
		return
	if "starfall" in args:
		_starfall(maps, minutes, quiet, "user://pace_starts/" if "cache" in args else "")
		return
	if "livewire" in args:
		_livewire(maps, minutes, quiet, "user://pace_starts/" if "cache" in args else "")
		return
	if "ironfall" in args:
		var from := "ironfall_steam" if "steam" in args else ("ironfall_teardown" if "teardown" in args else "ironfall")
		_ironfall(maps, minutes, quiet, from, "user://pace_starts/" if "cache" in args else "")
		return
	var times: Array = []
	for m in maps:
		var bot := Autoplay.new()
		bot.trace = not quiet
		var r: Dictionary = bot.play(m, minutes * 60.0)
		times.append(r["seconds"] / 60.0)
		print("map %d: %s at %.1f min" % [m, "WON" if r["won"] else "not won", r["seconds"] / 60.0])
		if not quiet:
			for line in r["log"]:
				print("   ", line)
			print("   inv ", bot.s.economy.inv)
			print("   ranks ", bot.s.ranks, " kith %d" % bot.s.people.kith.size())
			var counts := {}
			for b in bot.s.town.buildings:
				var key: String = (
					b["type"] + ("/" + "+".join(b["gather_items"]) if b["type"] == "gatherers_hut" else "")
				)
				counts[key] = counts.get(key, 0) + 1
			print("   buildings ", counts)
	var total := 0.0
	for x in times:
		total += x
	print("average %.1f min, from %.1f to %.1f" % [total / times.size(), times.min(), times.max()])
	quit(0)


## The era-2 report: minutes from Bronze Dawn to the first Bronze, per map.
func _bronze(maps: Array, minutes: float, quiet: bool) -> void:
	var spans: Array = []
	for m in maps:
		var bot := AutoplayBronze.new()
		bot.trace = not quiet
		var r: Dictionary = bot.play_bronze(m, minutes * 60.0)
		print(
			(
				"map %d: Bronze Dawn at %.1f min, first Bronze %s"
				% [
					m,
					r["seconds"] / 60.0,
					(
						"%.1f min later" % r["minutes"]
						if r["minutes"] >= 0.0
						else "never (stopped at %.1f min)" % [bot.clock / 60.0]
					)
				]
			)
		)
		spans.append(r["minutes"])
		if not quiet:
			for line in r["log"]:
				print("   ", line)
			print("   inv ", bot.s.economy.inv)
	var total := 0.0
	for x in spans:
		total += x
	print("era 2: average %.1f min, from %.1f to %.1f" % [total / spans.size(), spans.min(), spans.max()])
	quit(0)


## The whole era: minutes from Bronze Dawn to the first Bronze, and from the first Bronze to The Falling Star, per map.
func _star(maps: Array, minutes: float, quiet: bool) -> void:
	var firsts: Array = []
	var stars: Array = []
	for m in maps:
		var bot := AutoplayBronze.new()
		bot.trace = not quiet
		var r: Dictionary = bot.play_to_star(m, minutes * 60.0)
		print(
			(
				"map %d: Bronze Dawn at %.1f min, first Bronze %.1f min later, The Falling Star %s"
				% [
					m,
					r["seconds"] / 60.0,
					r["minutes"],
					(
						"%.1f min after that" % r["star_minutes"]
						if r["star_minutes"] >= 0.0
						else "never (stopped at %.1f min)" % [bot.clock / 60.0]
					)
				]
			)
		)
		firsts.append(r["minutes"])
		stars.append(r["star_minutes"])
		if not quiet:
			for line in r["log"]:
				print("   ", line)
			print("   inv ", bot.s.economy.inv)
	print(
		(
			"era 2: first Bronze %.1f min on average (%.1f to %.1f), the star %.1f min after it (%.1f to %.1f)"
			% [_mean(firsts), firsts.min(), firsts.max(), _mean(stars), stars.min(), stars.max()]
		)
	)
	quit(0)


## What the bot's log says about how much the era asked of a player: "N decisions (D a minute), W minutes waiting". A decision is
## a building placed, a tech learned or an order written; a minute is waiting when the bot's trace line says what held it up
## ("next ... missing"). A reading of the bot, never of a human: scorecards cite it beside a human or captured play.
static func measured(entries: Array, clock: float) -> String:
	var rx := RegEx.new()
	rx.compile("^\\s*\\d+ s\\s+(\\+ |== order written|[A-Z][^=.(]*\\(Kith)")
	var decisions := 0
	var waits := 0
	for line in entries:
		var text := String(line)
		if rx.search(text) != null:
			decisions += 1
		elif ".. next " in text:
			waits += 1
	var minutes := maxf(clock / 60.0, 0.1)
	return (
		"measured: %d decisions (%.1f a minute), %d minutes waiting on a want" % [decisions, decisions / minutes, waits]
	)


func _mean(xs: Array) -> float:
	var total := 0.0
	for x in xs:
		total += x
	return total / xs.size()


## The baseline: map `m` played through every era by the bots, one probe row per era (era_probe.gd), written to `out`/seed_<m>.json.
## An era a bot does not finish in time is closed with "ended": false and the run stops there. A run takes hours of real time, so
## it keeps a checkpoint (the game and the probe) in user://baseline_work/ every ten game minutes and picks up from it when run
## again; delete that folder to start a map afresh.
func _baseline(m: int, minutes: float, out: String) -> void:
	var work := "user://baseline_work/seed_%d.json" % m
	DirAccess.make_dir_recursive_absolute("user://baseline_work")
	var probe := EraProbe.new()
	var game := Sim.new()
	var limit := 70.0 * 60.0
	var stage := _baseline_resume(work, probe, game)
	if stage == "":
		game.generate(m)
		stage = "stone_age"
		probe.begin("stone_age", game)
	var at := [stage, game.seasons.time, Time.get_ticks_msec()]  # the stage, and the game clock and wall clock of the last checkpoint
	var wire_of := []  # the Livewire bot, once there is one: the hook closes the era on its limit through its watch list
	var hook := func(s):
		probe.observe(s)
		if probe.era == "livewire" and not wire_of.is_empty() and s.seasons.time - probe._at >= limit:
			wire_of[0].watch.clear()
		if s.seasons.time - at[1] >= BASELINE_SAVE_EVERY or Time.get_ticks_msec() - at[2] >= BASELINE_SAVE_WALL_MS:
			at[1] = s.seasons.time
			at[2] = Time.get_ticks_msec()
			_baseline_save(work, at[0], probe, s, m, out)
	var bronze := AutoplayBronze.new()
	bronze.probe = hook
	if at[0] == "stone_age":
		bronze.attach(game)
		while bronze.clock < limit and not game.won:
			bronze.step(true)
		at[0] = "bronze_dawn" if _close(probe, game, game.won) else "done"
		if at[0] == "bronze_dawn":
			probe.begin("bronze_dawn", game)
		_baseline_save(work, at[0], probe, game, m, out)
	if at[0] == "bronze_dawn":
		var from := game.seasons.time
		bronze.play_from_dawn(game, from, from + limit)
		while bronze.clock < from + limit and not bronze.fell():
			bronze.step(true)
		at[0] = "starfall" if _close(probe, game, bronze.fell()) else "done"
		if at[0] == "starfall":
			probe.begin("starfall", game)
		_baseline_save(work, at[0], probe, game, m, out)
	if at[0] == "starfall":
		var starfall := AutoplayStarfall.new()
		starfall.probe = hook
		var r: Dictionary = starfall.play_starfall(game, game.seasons.time, 40.0 * 60.0)
		at[0] = "ironfall" if _close(probe, game, r["won"]) else "done"
		if at[0] == "ironfall":
			probe.begin("ironfall", game)
		_baseline_save(work, at[0], probe, game, m, out)
	if at[0] == "ironfall":
		if "noseams" in OS.get_cmdline_user_args():
			_empty_seams(game)
		var wire := AutoplayLivewire.new()
		wire.probe = hook
		wire.watch = {"livewire_start": "livewire_begins", "era_limit": "never"}
		wire.stop_when_watched = true  # a resumed run starts its clock afresh, so the era's own limit is enforced by the hook
		wire_of.append(wire)
		wire.on_checkpoint = func(_id: String, bot): _keep_livewire_start(out, m, bot.s)
		var r: Dictionary = wire.play_livewire(game, minutes * 60.0)
		_close(probe, game, r["won"])
		at[0] = "done"
		_baseline_save(work, at[0], probe, game, m, out)
	for row in probe.rows:
		print(
			(
				"map %d %s: %.1f min, goals %d of %d, ended %s"
				% [m, row["era"], row["length_min"], row["goals_done"], row["goals_total"], row["ended"]]
			)
		)
	quit(0)


## Keep the game as Livewire begins (once: a run picked up mid-Livewire does not overwrite it), for the variant bot to start from.
func _keep_livewire_start(out: String, m: int, game: Sim) -> void:
	if out == "":
		return
	var path := "%s/livewire_start_%d.json" % [out, m]
	DirAccess.make_dir_recursive_absolute(out)
	if not FileAccess.file_exists(path):
		_write_file(path, RunSave.to_json(RunSave.dump(game)))


## Livewire alone, from a copy of the game as it began (`from`, kept by a baseline run), played for `minutes`; one row to
## `out`/livewire_seed_<m>.json. With `answer` false (`notide`) it is the variant that lights a Generator and never answers the
## tide (no Arc Lamp, Scorcher or Firebreak), to `out`/variant_seed_<m>.json: a pressure check, never a balance run.
## It keeps a checkpoint in user://baseline_work/ every five game minutes and picks up from it when run again.
func _from_livewire_start(m: int, minutes: float, out: String, from: String, answer: bool) -> void:
	var game := Sim.new()
	var probe := EraProbe.new()
	var work := "user://baseline_work/%s_seed_%d.json" % ["livewire" if answer else "variant", m]
	DirAccess.make_dir_recursive_absolute("user://baseline_work")
	var played := _keep_resume(work, probe, game)  # game seconds the bot has played so far, -1 with nothing kept
	if played < 0.0:
		var kept := FileAccess.get_file_as_string(from)
		if kept == "" or not RunSave.restore(game, RunSave.from_json(kept)):
			print("variant: no Livewire start at %s" % from)
			quit(1)
			return
		probe.begin("livewire", game)
		played = 0.0
	var wire := AutoplayLivewire.new()
	var saved := [game.seasons.time]  # the game clock of the last checkpoint
	wire.probe = func(s):
		probe.observe(s)
		if s.seasons.time - saved[0] >= LIVEWIRE_SAVE_EVERY:
			saved[0] = s.seasons.time
			_keep_save(work, probe, s, played + wire.clock)
	wire.answer_tide = answer
	wire.play_livewire(game, minutes * 60.0 - played)
	var row: Dictionary = probe.finish(game)
	row["ended"] = game.tech_tree.researched.has("skyward")  # as in a baseline run: the era ended when Skyward was learned
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		_write_file("%s/%s_seed_%d.json" % [out, "livewire" if answer else "variant", m], JSON.stringify(row, "\t"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(work))  # finished: the next run starts afresh
	print(
		(
			"map %d %s: woke at %.1f min, lost %d, within 20 min of waking %d, %d Firebreaks, goals %d of %d"
			% [
				m,
				"Livewire alone" if answer else "variant (no answer to the tide)",
				row["tide_woke_min"],
				row["lost_total"],
				row["lost_within_20_of_wake"],
				row["firebreak_tiles"],
				row["goals_done"],
				row["goals_total"]
			]
		)
	)
	quit(0)


## The `noseams` variant (a test, never a balance run): every Coal Seam is spent when Ironfall starts, so only Charcoal is left to burn.
func _empty_seams(game: Sim) -> void:
	for id in game.world.seam_left:
		game.world.seam_left[id] = 0
	for p in game.world.seam_of:
		if game.world.tile_at(p) == "coal_seam":
			game.world.set_tile(p, "spent_seam")


## Keep the run so far: the game, the probe and the stage in `work`, and the rows so far in `out`/seed_<m>.json.
func _baseline_save(work: String, stage: String, probe: RefCounted, game: Sim, m: int, out: String) -> void:
	probe.ledger.flush(game)
	var state := {"stage": stage, "probe": probe.to_dict(), "run": RunSave.to_json(RunSave.dump(game))}
	_write_file(work + ".tmp", JSON.stringify(state))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(work + ".tmp"), ProjectSettings.globalize_path(work))
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		var rows := {"seed": m, "complete": stage == "done", "eras": probe.rows}
		_write_file("%s/seed_%d.json" % [out, m], JSON.stringify(rows, "\t"))


## Keep a Livewire-alone run so far (the game, the probe, the seconds the bot has played) in `work`.
func _keep_save(work: String, probe: RefCounted, game: Sim, played: float) -> void:
	var state := {"played": played, "probe": probe.to_dict(), "run": RunSave.to_json(RunSave.dump(game))}
	_write_file(work + ".tmp", JSON.stringify(state))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(work + ".tmp"), ProjectSettings.globalize_path(work))


## Restore a kept Livewire-alone run into `game` and `probe`: the seconds already played, or -1 when there is none.
func _keep_resume(work: String, probe: RefCounted, game: Sim) -> float:
	if not FileAccess.file_exists(work):
		return -1.0
	var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(work))
	if typeof(kept) != TYPE_DICTIONARY or not RunSave.restore(game, RunSave.from_json(kept["run"])):
		return -1.0
	probe.from_dict(kept["probe"])
	return float(kept["played"])


func _write_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Restore a kept baseline run into `game` and `probe`: the stage it was in, or "" when there is none.
func _baseline_resume(work: String, probe: RefCounted, game: Sim) -> String:
	if not FileAccess.file_exists(work):
		return ""
	var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(work))
	if typeof(kept) != TYPE_DICTIONARY or not RunSave.restore(game, RunSave.from_json(kept["run"])):
		return ""
	probe.from_dict(kept["probe"])
	return kept["stage"]


## Close the open era with whether it reached its end (an era is "ended" when its bot passed the boundary, not when time ran out).
func _close(probe: RefCounted, game: Sim, reached: bool) -> bool:
	var row: Dictionary = probe.finish(game)
	row["ended"] = reached
	return reached


## Starfall: the minutes from The Falling Star to the Warning read and the ending put away, per map, with the era's milestones.
func _starfall(maps: Array, minutes: float, quiet: bool, cache: String) -> void:
	for m in maps:
		var game := DevStarts.star_on_map(m, cache)
		var bot := AutoplayStarfall.new()
		bot.trace = not quiet
		var r: Dictionary = bot.play_starfall(game, game.seasons.time, minutes * 60.0)
		var shown: Array = []
		for key in r["marks"]:
			shown.append("%s %.1f" % [key, r["marks"][key] / 60.0])
		print(
			(
				"map %d starfall: %s"
				% [
					m,
					(
						"over at %.1f min" % (r["seconds"] / 60.0)
						if r["won"]
						else "not over by %.1f min" % (r["seconds"] / 60.0)
					)
				]
			)
		)
		print("   marks (min): ", ", ".join(shown))
		if not quiet:
			for line in r["log"]:
				print("   ", line)
		print("   inv ", bot.s.economy.inv)
		print("   trust %.0f, locked %s" % [bot.s.starfall.trust, bot.s.starfall.locked.keys()])
	quit(0)


## Ironfall: the clock at each goal from the start `from` to the Livewire gate, per map.
## The era-5 report: minutes from the Ironfall start to its gate and from there to Skyward, per map.
func _livewire(maps: Array, minutes: float, quiet: bool, cache: String) -> void:
	for m in maps:
		var bot := AutoplayLivewire.new()
		bot.trace = not quiet
		for a in OS.get_cmdline_user_args():
			if a.begins_with("coal+"):  # `coal+1000`: a what-if, the coal the seams do not hold
				bot.coal_gift = int(a.substr(5))
		var game := DevStarts.ironfall_on_map(m, "ironfall", cache)
		var r: Dictionary = bot.play_livewire(game, minutes * 60.0)
		var shown: Array = []
		for key in r["marks"]:
			shown.append("%s %.1f" % [key, r["marks"][key] / 60.0])
		print(
			(
				"map %d livewire: %s; Ironfall gate %s"
				% [
					m,
					(
						"Skyward at %.1f min" % (r["seconds"] / 60.0)
						if r["won"]
						else "no Skyward by %.1f min" % (bot.clock / 60.0)
					),
					"%.1f min" % (r["gate_seconds"] / 60.0) if r["gate_seconds"] >= 0.0 else "never"
				]
			)
		)
		print("   marks (min): ", ", ".join(shown))
		print("   ", measured(r["log"], bot.clock))
		if not quiet:
			for line in r["log"]:
				print("   ", line)
		print("   inv ", bot.s.economy.inv)
		print("   caps ", bot.s.economy.caps)
		print("   spilled ", bot.s.economy.spilled)
	quit(0)


func _ironfall(maps: Array, minutes: float, quiet: bool, from: String, cache: String) -> void:
	var gates: Array = []
	for m in maps:
		var bot := AutoplayIronfall.new()
		bot.trace = not quiet
		var game := DevStarts.ironfall_on_map(m, from, cache)
		var r: Dictionary = bot.play_from(game, minutes * 60.0)
		gates.append(r["seconds"] / 60.0 if r["won"] else -1.0)
		var shown: Array = []
		for key in r["marks"]:
			shown.append("%s %.1f" % [key, r["marks"][key] / 60.0])
		print(
			(
				"map %d from %s: %s"
				% [m, from, "gate at %.1f min" % gates[-1] if r["won"] else "no gate by %.1f min" % (bot.clock / 60.0)]
			)
		)
		print("   marks (min): ", ", ".join(shown))
		print("   ", measured(r["log"], bot.clock))
		if not quiet:
			for line in r["log"]:
				print("   ", line)
		print("   inv ", bot.s.economy.inv)
	var won: Array = gates.filter(func(g): return g >= 0.0)
	if not won.is_empty():
		print(
			(
				"ironfall from %s: gate %.1f min on average (%.1f to %.1f), %d of %d maps"
				% [from, _mean(won), won.min(), won.max(), won.size(), gates.size()]
			)
		)
	quit(0)
