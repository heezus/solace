extends RefCounted
## The play log (design-system/25-playtesting.md): what a person did in a run, written as one JSON object a line. It only reads
## the game: `note` is handed the Sim and what the screen shows each frame, and works out what changed by comparing the town with
## how it was at the last sample. Nothing here writes to the Sim or draws a random number, so a run plays the same with the log
## on or off. Lines: `run` (once), `sample` (every Data.PLAYLOG_SAMPLE_SECONDS game seconds), `act` (a change the player made),
## `card` (a card opened or answered, with the real seconds it waited), `era_end` (the three answers) and `end`.

const Data = preload("res://scripts/data.gd")

const LOOK_EVERY := 0.25  # real seconds between comparisons of the town

var path := ""  # the file being written, "" until `begin`
var keep := false  # tests: also keep every line in `lines`
var lines: Array = []

var _file: FileAccess
var _real := 0.0  # real seconds since the log began
var _since := 0.0  # real seconds since the town was last compared
var _last_input := 0.0  # the real second of the last click or key
var _inputs := 0  # clicks and keys since the last sample
var _next_sample := 0.0  # the game second of the next sample
var _before := {}  # what the town was at the last look: building signatures, techs, goals, orders, speed, paused, cards
var _open_cards := {}  # card id -> the real second it opened


## Start a log for the run in `s`, in `dir` (one file per run). `window` and `build` go in the first line.
func begin(s, dir: String, stamp: String, window := Vector2i.ZERO, build := "", loaded := false) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	path = "%s%s-seed%d.jsonl" % [dir, stamp, s.world.map_seed]
	_file = FileAccess.open(path, FileAccess.WRITE)
	_real = 0.0
	_last_input = 0.0
	_inputs = 0
	_next_sample = s.seasons.time
	_before = _look(s)
	_open_cards = {}
	_emit(
		"run",
		{
			"v": 1,
			"build": build,
			"seed": s.world.map_seed,
			"window": [window.x, window.y],
			"loaded": loaded,
			"t": s.seasons.time
		}
	)


## One frame: `ui` is what the screen shows ({speed, paused, cards: [ids of the cards up]}), `delta` is real seconds.
func note(s, ui: Dictionary, delta: float) -> void:
	if _file == null:
		return
	_real += delta
	_since += delta
	if _since < LOOK_EVERY:
		return
	_since = 0.0
	var now := _look(s)
	now["speed"] = int(ui.get("speed", 1))
	now["paused"] = bool(ui.get("paused", false))
	_acts(s, now)
	_cards(s, ui.get("cards", []))
	_before = now
	if s.seasons.time >= _next_sample:
		_next_sample = s.seasons.time + Data.PLAYLOG_SAMPLE_SECONDS
		_emit("sample", _sample(s, now))


## A click or a key: the player is at the keyboard.
func input() -> void:
	_last_input = _real
	_inputs += 1


## The answers to the era-end card, by question id ("" for one left unanswered).
func era_end(s, era_id: String, answers: Dictionary) -> void:
	var out := {"era": _era(s), "id": era_id, "t": s.seasons.time}
	out.merge(answers)
	_emit("era_end", out)


## Close the file with a reason ("left" for the title screen, "closed" for the window, "won" when the run ends).
func end(s, reason: String) -> void:
	if _file == null:
		return
	_emit("end", {"why": reason, "t": s.seasons.time, "real": snappedf(_real, 0.1), "era": _era(s)})
	_file.close()
	_file = null


## The era now: 1 stone age, 2 Bronze Dawn on, 3 the Falling Star, 4 Ironfall, 5 Livewire.
func _era(s) -> int:
	var events: Array = s.story.events
	if Data.LIVEWIRE_BEGUN in events:
		return 5
	if Data.IRONFALL_EVENT in events:
		return 4
	if "star_falling" in events:
		return 3
	return 2 if "bronze_dawn" in events else 1


## What the town is now, in the few things a player changes: each building by type (and a hut by what it gathers), the techs,
## the goals met and the standing orders.
func _look(s) -> Dictionary:
	var sig := {}
	for b in s.town.buildings:
		var key: String = b["type"] + ("/" + b["focus"] if b.get("focus", "") != "" else "")
		sig[key] = sig.get(key, 0) + 1
	var season: String = "" if s.seasons.phase == "idle" else s.seasons.phase
	return {
		"sig": sig,
		"techs": s.tech_tree.researched.keys(),
		"goals": s.story.goals_done.keys(),
		"orders": s.livewire.orders.size(),
		"season": season,
		"answer": s.seasons.answer,
		"speed": 1,
		"paused": false
	}


## Write an `act` line for each difference from the last look.
func _acts(s, now: Dictionary) -> void:
	var t := snappedf(s.seasons.time, 0.1)
	var old: Dictionary = _before.get("sig", {})
	var cur: Dictionary = now["sig"]
	for key in cur:
		if cur[key] > old.get(key, 0):
			_emit("act", {"t": t, "did": "built", "what": key, "n": cur[key] - old.get(key, 0)})
	for key in old:
		if old[key] > cur.get(key, 0):
			_emit("act", {"t": t, "did": "removed", "what": key, "n": old[key] - cur.get(key, 0)})
	for tech in now["techs"]:
		if not _before.get("techs", []).has(tech):
			_emit("act", {"t": t, "did": "researched", "what": tech})
	for goal in now["goals"]:
		if not _before.get("goals", []).has(goal):
			_emit("act", {"t": t, "did": "goal", "what": goal})
	if now["orders"] != _before.get("orders", 0):
		_emit("act", {"t": t, "did": "orders", "what": str(now["orders"])})
	if now["season"] == "active" and _before.get("season", "") == "pending":
		_emit("act", {"t": t, "did": "season", "what": s.seasons.kind, "answer": now["answer"]})
	if now["speed"] != _before.get("speed", 1):
		_emit("act", {"t": t, "did": "speed", "what": str(now["speed"])})
	if now["paused"] != _before.get("paused", false):
		_emit("act", {"t": t, "did": "paused" if now["paused"] else "resumed", "what": ""})


## A `card` line when one opens and again when it is put away, with how long it was up.
func _cards(s, up: Array) -> void:
	var t := snappedf(s.seasons.time, 0.1)
	for id in up:
		if not _open_cards.has(id):
			_open_cards[id] = _real
			_emit("card", {"t": t, "id": id, "state": "open"})
	for id in _open_cards.keys():
		if not up.has(id):
			_emit("card", {"t": t, "id": id, "state": "closed", "waited": snappedf(_real - _open_cards[id], 0.1)})
			_open_cards.erase(id)


## The town in numbers for a `sample` line.
func _sample(s, now: Dictionary) -> Dictionary:
	var inv := {}
	var full: Array = []
	for id in s.economy.inv:
		if s.economy.inv[id] > 0:
			inv[id] = s.economy.inv[id]
		if s.economy.is_full(id):
			full.append(id)
	var idle := 0
	for k in s.people.kith:
		if k["task"].is_empty():
			idle += 1
	var goals: Array = s.story.goal_list()
	var at: int = s.story.current_goal()
	return {
		"t": snappedf(s.seasons.time, 0.1),
		"era": _era(s),
		"kith": s.people.kith.size(),
		"idle": idle,
		"food": roundi(s.economy.food_total()),
		"food_secs": roundi(minf(s.economy.seconds_of_food(), 3600.0)),
		"inv": inv,
		"full": full,
		"buildings": now["sig"],
		"techs": now["techs"].size(),
		"goal": goals[at]["id"] if at < goals.size() else "",
		"goals_done": s.story.done_count(),
		"speed": now["speed"],
		"paused": now["paused"],
		"season": now["season"],
		"quiet": snappedf(_real - _last_input, 0.1),
		"inputs": _take_inputs(),
		"real": snappedf(_real, 0.1)
	}


func _take_inputs() -> int:
	var n := _inputs
	_inputs = 0
	return n


func _emit(kind: String, data: Dictionary) -> void:
	var out := {"k": kind}
	out.merge(data)
	var line := JSON.stringify(out)
	if keep:
		lines.append(line)
	if _file != null:
		_file.store_line(line)
		_file.flush()
