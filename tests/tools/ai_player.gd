extends SceneTree
## The AI player's table (design-system/25-playtesting.md, part 2). It runs the real Sim with no screen, and every few game seconds
## stops, writes `snapshot_<n>.txt`, and waits for the player (a Claude session that sees only that page) to write `moves_<n>.json`
## and `diary_<n>.md`. The moves go through the game's own commands (tests/tools/ai_snapshot.gd). Game time stands still while the
## player thinks. Stops after --decisions pages, when the era turns over (--stop-at-era), or when no answer comes in --patience s.
## Run: godot --headless --path . -s tests/tools/ai_player.gd -- --dir=/some/folder [--seed=3] [--every=15] [--decisions=60]
##      [--stop-at-era=Bronze Dawn] [--patience=900] [--start=earned_livewire] [--replay=/folder/with/moves]
## With --then-live=1 the page after the last replayed one is played by a live player (the replay carries on as a game).
## The table saves the game at the start of every era (era_save.json and its profile in the folder). A folder that holds one is resumed
## from it, not replayed: replays diverge across sessions (fun playtest 5). A folder that holds moves_<n>.json and no era save is picked
## up by replaying them (a restart or a closed lid costs the replay, minutes); --fresh=1 starts it over instead.
## With --replay the moves come from that folder's moves_<n>.json instead of a player (same --seed and --start, the same cached
## start in user://ai_starts/): the game is deterministic, so every page comes out as it did, with whatever the page shows now.
## With --start an earned checkpoint plays on map --seed (built by the bots, kept in user://ai_starts/); any other start is on map 1.
## The playing session reads snapshot_<n>.txt and writes moves_<n>.json and diary_<n>.md in the folder. Then it reads the next one.

const Data = preload("res://scripts/data.gd")
const DevStarts = preload("res://scripts/dev_starts.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Sim = preload("res://scripts/sim.gd")
const Snapshot = preload("res://tests/tools/ai_snapshot.gd")
const AiStory = preload("res://tests/tools/ai_story.gd")

const DT := 0.1
const POLL_MS := 500

var s: Sim
var dir := "user://ai_player/"
var every := 15.0
var decisions := 60
var stop_at_era := ""
var patience := 900.0
var timed_out := false
var replay := ""  # a folder of moves_<n>.json to play back instead of waiting for a player
var then_live := false  # after the last replayed page, carry on with a live player
var fresh := false  # start over even when the folder already holds moves
var resume_at := 0  # the page number a resumed game carries on from, 0 for none
var start := ""  # a stage start or earned checkpoint to begin from (scripts/dev_starts.gd), "" for a fresh map


func _init() -> void:
	var map_seed := 3
	var seed_given := false
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"dir":
				dir = kv[1] if kv[1].ends_with("/") else kv[1] + "/"
			"seed":
				map_seed = int(kv[1])
				seed_given = true
			"every":
				every = float(kv[1])
			"decisions":
				decisions = int(kv[1])
			"stop-at-era":
				stop_at_era = kv[1]
			"start":
				start = kv[1]
			"replay":
				replay = kv[1] if kv[1].ends_with("/") else kv[1] + "/"
			"then-live":
				then_live = true
			"fresh":
				fresh = true
			"patience":
				patience = float(kv[1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	AiStory.reset(dir + "profile.json")  # the table is one player's whole game: a first game, then a profile of its own
	if not fresh and replay == "" and _resume():
		pass  # the game is back as the last era began; the pages from there on are new
	elif replay == "" and not fresh and FileAccess.file_exists(dir + "moves_1.json"):
		replay = dir  # a game stopped part way (a restart, a closed lid): play its saved moves back, then go on live
		then_live = true
	if s != null:
		pass  # resumed from an era save
	elif start in DevStarts.EARNED and seed_given:
		s = DevStarts.earned_on_map(map_seed, start, "user://ai_starts/")  # an earned checkpoint on that map, played by the bots
	elif start != "":
		s = DevStarts.build(start)  # the starts are on map 1 whatever `seed` says
	else:
		s = Sim.new()
		s.generate(map_seed)
	print(
		(
			"AI player: map %d, a page every %d game seconds, in %s"
			% [s.world.map_seed, int(every), ProjectSettings.globalize_path(dir)]
		)
	)
	var refused: Array = []
	var told: Array = []
	var era := Snapshot.era_name(s)
	for n in range(maxi(resume_at, 1), decisions + 1):
		if n == maxi(resume_at, 1) or Snapshot.era_name(s) != era:
			_save_era(n)  # the game as this era begins: a restart resumes here, not from a replay
		var page := Snapshot.text(s, n, told, refused)
		if n == 1 and start != "":
			page = Snapshot.KNOWN + "\n" + page  # the player of a later era has played the earlier ones
		_write(dir + "snapshot_%d.txt" % n, page)
		var replaying := replay != "" and not (then_live and not FileAccess.file_exists(replay + "moves_%d.json" % n))
		var moves := _replayed(n) if replaying else _await_moves(n)
		if replaying and moves.is_empty() and not FileAccess.file_exists(replay + "moves_%d.json" % n):
			print("AI player: no moves_%d.json to replay, stopping" % n)
			break
		if timed_out:
			print("AI player: no answer in %d s, stopping" % int(patience))
			break
		told = []
		refused = Snapshot.play(s, moves, every, func(seconds: float): _run(seconds, told))
		_swap()
		if stop_at_era != "" and Snapshot.era_name(s) == stop_at_era and era != stop_at_era:
			print("AI player: reached %s" % stop_at_era)
			break
		era = Snapshot.era_name(s)
	print("AI player: done at game time %d s, era %s" % [int(s.seasons.time), Snapshot.era_name(s)])
	quit(0)


## Run the game for `seconds`, or until a card needs the player; what the game said goes into `told`.
func _run(seconds: float, told: Array) -> void:
	_swap()
	var t := 0.0
	var asked: bool = s.seasons.phase == "pending"
	if asked:  # a Season card holds the game as it does for a person: no time passes, and the card never answers itself unseen
		told.append("The game is paused: a season card is waiting for an answer (CARD WAITING at the top of the page)")
	while t < seconds and s.starfall.pending == "" and not asked:  # a story moment holds the game, as it does for a person
		s.tick(DT)
		t += DT
		for e in s.events:
			tell(told, e)
		s.events.clear()
		if s.seasons.phase == "pending" and not asked:
			break  # a Season card has come up: the player is told at once


## The game as the era begins, kept in the folder with the page number and the profile (the table's own Chronicle).
func _save_era(n: int) -> void:
	var file := FileAccess.open(dir + "era_save.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"n": n, "era": Snapshot.era_name(s), "run": RunSave.to_json(RunSave.dump(s))}))
	file.close()
	if FileAccess.file_exists(AiStory.profile_path):
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(AiStory.profile_path),
			ProjectSettings.globalize_path(dir + "era_save_profile.json")
		)


## Bring the game back from the folder's era save: true when there was one and it loaded.
func _resume() -> bool:
	var kept = JSON.parse_string(FileAccess.get_file_as_string(dir + "era_save.json"))
	if typeof(kept) != TYPE_DICTIONARY or not kept.has("run"):
		return false
	var game := Sim.new()
	if not RunSave.restore(game, RunSave.from_json(kept["run"])):
		return false
	s = game
	resume_at = int(kept.get("n", 1))
	if FileAccess.file_exists(dir + "era_save_profile.json"):
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(dir + "era_save_profile.json"),
			ProjectSettings.globalize_path(AiStory.profile_path)
		)
	for n in range(resume_at, resume_at + 400):  # the moves written for pages from here on belong to a game that no longer stands
		var path := ProjectSettings.globalize_path(dir + "moves_%d.json" % n)
		if not FileAccess.file_exists(dir + "moves_%d.json" % n):
			break
		DirAccess.remove_absolute(path)
	print("AI player: resumed from the %s save at page %d" % [kept.get("era", "?"), resume_at])
	return true


## Add what the game said to `told`. "The Bloom reaches the Kiln in about 3 min" says one thing a building at a time, so a later one
## replaces the one before it, in its place (fun playtest 5: the page repeated stale times).
static func tell(told: Array, line: String) -> void:
	var cut := line.find(" in about ")
	if line.begins_with(Data.TIDE_REACHES_LINE.split("%s")[0]) and cut > 0:
		var key := line.substr(0, cut + 10)
		for i in told.size():
			if String(told[i]).begins_with(key):
				told[i] = line
				return
	told.append(line)


## A telling ended by a set_out move: the table carries on in the new run.
func _swap() -> void:
	var next = AiStory.take_next()
	if next != null:
		s = next


## The moves the player wrote for page `n` in the replay folder.
func _replayed(n: int) -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(replay + "moves_%d.json" % n))
	return parsed if typeof(parsed) == TYPE_ARRAY else []


## Wait for moves_<n>.json; sets `timed_out` if it does not come in time.
func _await_moves(n: int) -> Array:
	var path := dir + "moves_%d.json" % n
	var waited := 0.0
	while waited < patience:
		if FileAccess.file_exists(path):
			OS.delay_msec(300)  # the writer may still be at it
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(parsed) == TYPE_ARRAY:
				return parsed
			return []
		OS.delay_msec(POLL_MS)
		waited += POLL_MS / 1000.0
	timed_out = true
	return []


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
