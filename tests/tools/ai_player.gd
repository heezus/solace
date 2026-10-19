extends SceneTree
## The AI player's table (design-system/25-playtesting.md, part 2). It runs the real Sim with no screen, and every few game seconds
## stops, writes `snapshot_<n>.txt`, and waits for the player (a Claude session that sees only that page) to write `moves_<n>.json`
## and `diary_<n>.md`. The moves go through the game's own commands (tests/tools/ai_snapshot.gd). Game time stands still while the
## player thinks. Stops after --decisions pages, when the era turns over (--stop-at-era), or when no answer comes in --patience s.
## Run: godot --headless --path . -s tests/tools/ai_player.gd -- --dir=/some/folder [--seed=3] [--every=15] [--decisions=60]
##      [--stop-at-era=Bronze Dawn] [--patience=900] [--start=earned_livewire]
## The playing session reads snapshot_<n>.txt and writes moves_<n>.json and diary_<n>.md in the folder. Then it reads the next one.

const Data = preload("res://scripts/data.gd")
const DevStarts = preload("res://scripts/dev_starts.gd")
const Sim = preload("res://scripts/sim.gd")
const Snapshot = preload("res://tests/tools/ai_snapshot.gd")

const DT := 0.1
const POLL_MS := 500

var s: Sim
var dir := "user://ai_player/"
var every := 15.0
var decisions := 60
var stop_at_era := ""
var patience := 900.0
var timed_out := false
var start := ""  # a stage start or earned checkpoint to begin from (scripts/dev_starts.gd), "" for a fresh map


func _init() -> void:
	var map_seed := 3
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"dir":
				dir = kv[1] if kv[1].ends_with("/") else kv[1] + "/"
			"seed":
				map_seed = int(kv[1])
			"every":
				every = float(kv[1])
			"decisions":
				decisions = int(kv[1])
			"stop-at-era":
				stop_at_era = kv[1]
			"start":
				start = kv[1]
			"patience":
				patience = float(kv[1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	if start != "":
		s = DevStarts.build(start)
	else:
		s = Sim.new()
		s.generate(map_seed)
	print(
		(
			"AI player: map %d, a page every %d game seconds, in %s"
			% [map_seed, int(every), ProjectSettings.globalize_path(dir)]
		)
	)
	var refused: Array = []
	var told: Array = []
	var era := Snapshot.era_name(s)
	for n in range(1, decisions + 1):
		_write(dir + "snapshot_%d.txt" % n, Snapshot.text(s, n, told, refused))
		var moves := _await_moves(n)
		if timed_out:
			print("AI player: no answer in %d s, stopping" % int(patience))
			break
		refused = Snapshot.apply(s, moves)
		told = []
		_run(Snapshot.wait_of(moves, every), told)
		if stop_at_era != "" and Snapshot.era_name(s) == stop_at_era and era != stop_at_era:
			print("AI player: reached %s" % stop_at_era)
			break
		era = Snapshot.era_name(s)
	print("AI player: done at game time %d s, era %s" % [int(s.seasons.time), Snapshot.era_name(s)])
	quit(0)


## Run the game for `seconds`, or until a card needs the player; what the game said goes into `told`.
func _run(seconds: float, told: Array) -> void:
	var t := 0.0
	var asked: bool = s.seasons.phase == "pending"
	while t < seconds and s.starfall.pending == "":  # a story moment holds the game, as it does for a person
		s.tick(DT)
		t += DT
		told.append_array(s.events)
		s.events.clear()
		if s.seasons.phase == "pending" and not asked:
			break  # a Season card has come up: the player is told at once


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
