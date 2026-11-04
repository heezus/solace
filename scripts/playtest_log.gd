extends RefCounted
## The playtest log (design-system/25-playtesting.md, "The playtest log"): raw events for the fun rubric's measured metrics M1 to M15
## (/mnt/project-files/director/fun-rubric.md). A local file of JSON lines under user://playtest_logs/, never sent anywhere, never in a
## save or the profile. OFF unless asked: `-- --playtest-log` (or `--playtest-log=<folder>`) on the command line, or `[playtest] on=true`
## in user://playtest_log.cfg. Every Sim made while it is on writes one file, so the scripted players and the AI player log with the
## same flag and no code of their own: the Sim's Seasons block holds the log (`sim.seasons.watcher`) and calls `tick` once a tick.
## It only reads the game: it listens to the town's built, demolished and refused signals and the tech tree's, and compares the town
## at each look. Nothing here writes to the Sim or draws a random number, so a run plays the same with the log on or off
## (tests/playtest_log_tests.gd).
## Lines (`m` is the game minute): run, era, goal, tech, act, first_use, stopped, loss, regret, tick (every 10 game s), snap (every 5
## game min), end; the recorder in the game adds click, panel, menu, cutscene, chronicle, endings, detail, quiet.
## `act` has a `kind` and `decision` (true for a build, research, choice or demolish; false for upkeep: a hand harvest, a building paused
## or resumed, a failed placement). A drag that lays a line of roads is one act with `n` tiles.

const Data = preload("res://scripts/data.gd")

const DIR := "user://playtest_logs/"
const CONFIG := "user://playtest_log.cfg"
const FLAG := "--playtest-log"
const TICK_SECONDS := 10.0
const SNAP_SECONDS := 300.0
const LOOK_SECONDS := 1.0  # game seconds between looks at the town (stopped buildings, new techs and goals)
const REGRET_SECONDS := 60.0
const STOP_HOLD := 10.0  # game seconds an alert must stay up to be a stopped building, and stay down to be over
const FLUSH_LINES := 25

## What each era adds, as the town shows it: the first use of it is `first_use`.
const MECHANICS := {
	1: "hand harvest",
	2: "first crucible",
	3: "first moment answered",
	4: "first lesson learned",
	5: "power pole or order",
	6: "signal tower"
}

static var folder := ""  # tests set this; the flag's value sets it too
static var _wanted := -1  # -1 not asked yet, 0 off, 1 on
static var _count := 0  # logs begun in this process: part of a file's name

var path := ""
var keep := false  # tests: also keep every line in `lines`
var lines: Array = []

var _file: FileAccess
var _begun := false
var _era := 0
var _look := 0.0
var _tick_at := 0.0
var _snap_at := 0.0
var _flow_second := -1
var _hand := 0.0  # goods the player's own hands made since the last tick line
var _hauled := 0.0  # goods the haulers carried since the last tick line
var _made := 0.0  # goods the buildings made since the last tick line
var _hand_total := 0.0
var _hauled_total := 0.0
var _made_total := 0.0
var _made_recent: Array = []  # [game second, goods] over the last minute
var _trip_at := -1.0  # the game second of the last hauler trip counted
var _decisions := 0  # acts since the last tick line
var _upkeep := 0
var _touch := 0  # acts since the last tick line that touch the town (a build, a demolish, a pause or resume)
var _progress_at := 0.0  # the game second of the last progress: a goal, a tech, a new kind of building, an era
var _goals := {}
var _techs := {}
var _kinds := {}  # building types seen standing
var _stopped := {}  # tile -> true once a stop was written, until the alert has been gone STOP_HOLD seconds
var _alert_since := {}  # tile -> the game second its alert came up (a flickering alert starts over)
var _clear_since := {}  # tile -> the game second its alert went
var _built_at := {}  # tile -> the game second it was placed
var _used := {}  # era -> true once its new mechanic was used
var _pending_choice := false
var _choices := 0
var _season_pending := false
var _queue: Array = []  # signals heard since the last flush: {k, type, pos, t}
var _now := 0.0  # the game second of the last tick
var _paused := {}  # tile -> true while the building there is paused
var _at_type := {}  # tile -> building type, for the buildings standing at the last look
var _hand_seen := {}  # item -> hand_counts at the last look
var _lost_seen := 0
var _unwritten := 0


## True when the command line or the debug setting asks for a log.
static func wanted() -> bool:
	if _wanted < 0:
		_wanted = 0
		for arg in OS.get_cmdline_user_args():
			if arg == FLAG or arg.begins_with(FLAG + "="):
				_wanted = 1
				if arg.contains("=") and folder == "":
					folder = arg.get_slice("=", 1).rstrip("/") + "/"
		if _wanted == 0:
			var cfg := ConfigFile.new()
			if cfg.load(CONFIG) == OK and bool(cfg.get_value("playtest", "on", false)):
				_wanted = 1
	return _wanted == 1


## A new log for a Sim, or null when none was asked for (the Sim keeps it as `playtest`).
static func maybe():
	return new() if wanted() else null


## Forget what was read, so the next `wanted()` asks again (tests).
static func reset() -> void:
	_wanted = -1
	folder = ""


## Open the file for the run in `s`. `tag` goes in the first line (a bot's name, a player's).
func begin(s, tag := "") -> void:
	_begun = true
	_count += 1
	var dir := folder if folder != "" else DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")
	path = "%s%s-seed%d-%d.jsonl" % [dir, stamp, s.world.map_seed, _count]
	_file = FileAccess.open(path, FileAccess.WRITE)
	var now: float = s.seasons.time
	_era = _era_of(s)
	_look = now
	_tick_at = now + TICK_SECONDS
	_snap_at = now + SNAP_SECONDS
	_progress_at = now
	_flow_second = floori(s.economy.flows.clock)
	_trip_at = now
	_now = now
	_goals = s.story.goals_done.duplicate()
	_techs = s.tech_tree.researched.duplicate()
	_hand_seen = s.hand_counts.duplicate()
	_lost_seen = s.tide.lost
	s.town.built.connect(_on_built)
	s.town.demolished.connect(_on_demolished)
	s.town.refused.connect(_on_refused)
	s.tech_tree.tech_researched.connect(_on_tech)
	_emit(
		"run",
		s,
		{
			"v": 1,
			"tag": tag,
			"seed": s.world.map_seed,
			"telling": s.carry.exodus + 1,
			"cycle": s.carry.cycle(),
			"loaded": now > 1.0,
			"era": _era
		}
	)
	_emit("era", s, {"era": _era})


## Close the file with a reason ("won", "left", "closed", "test").
func end(s, reason: String) -> void:
	if _file == null:
		return
	_flush(s)
	_emit("end", s, {"why": reason, "era": _era})
	_file.close()
	_file = null


# --- What the player does -----------------------------------------------------------------------------------------


## A player action: `kind` build, research, choice, demolish, hand, pause, resume, ending. `decision` is true for the ones that are a
## choice and false for upkeep.
func act(s, kind: String, target: String, decision: bool, extra := {}) -> void:
	if not _ready(s):
		return
	if decision:
		_decisions += 1
	else:
		_upkeep += 1
	if kind in ["build", "demolish", "pause", "resume"]:
		_touch += 1
	var data := {"kind": kind, "what": target, "decision": decision}
	data.merge(extra)
	_emit("act", s, data)


## The town's `built`, `demolished` and `refused` signals and the tech tree's, queued with the game second they came at and written
## at the next tick (a dragged line of roads, all in one frame, is one act with its tiles).
func _on_built(type: String, p: Vector2i) -> void:
	_queue.append({"k": "built", "type": type, "pos": p, "t": _now})


func _on_demolished(type: String, p: Vector2i) -> void:
	_queue.append({"k": "demolished", "type": type, "pos": p, "t": _now})


func _on_refused(type: String, p: Vector2i) -> void:
	_queue.append({"k": "refused", "type": type, "pos": p, "t": _now})


func _on_tech(id: String) -> void:
	_queue.append({"k": "tech", "type": id, "t": _now})


func _flush(s) -> void:
	var builds := {}  # type@second -> the first tile and the count: a dragged line is one act
	for q in _queue:
		if q["k"] == "built":
			var key: String = "%s@%s" % [q["type"], q["t"]]
			_built_at[q["pos"]] = q["t"]
			if builds.has(key):
				builds[key]["n"] += 1
			else:
				builds[key] = {"type": q["type"], "pos": q["pos"], "n": 1}
	for key in builds:
		var g: Dictionary = builds[key]
		act(s, "build", g["type"], true, {"pos": [g["pos"].x, g["pos"].y], "n": g["n"]})
	for q in _queue:
		match q["k"]:
			"demolished":
				_demolished(s, q)
			"refused":
				act(s, "build_failed", q["type"], false, {"pos": [q["pos"].x, q["pos"].y]})
			"tech":
				_progress_at = q["t"]
				_techs[q["type"]] = true
				_emit("tech", s, {"id": q["type"], "known": s.carry.knows_tech(q["type"])})
				act(s, "research", q["type"], true)
	_queue = []


## A demolish. A building taken down within a minute of being put up is `regret`.
func _demolished(s, q: Dictionary) -> void:
	var p: Vector2i = q["pos"]
	act(s, "demolish", q["type"], true, {"pos": [p.x, p.y]})
	if _built_at.has(p) and q["t"] - _built_at[p] <= REGRET_SECONDS:
		_emit("regret", s, {"what": q["type"], "pos": [p.x, p.y], "age": snappedf(q["t"] - _built_at[p], 0.1)})
	_forget(p)


func _forget(p: Vector2i) -> void:
	_built_at.erase(p)
	_stopped.erase(p)
	_alert_since.erase(p)
	_clear_since.erase(p)
	_paused.erase(p)
	_at_type.erase(p)


## The Bloom took the building `type` at `p`. It was warned when the game had told the player the tide was coming for it first.
func lost(s, type: String, p: Vector2i) -> void:
	var warned: bool = s.tide._told.has(p)
	_emit("loss", s, {"what": type, "pos": [p.x, p.y], "warned": warned})
	_forget(p)


## A line the recorder in the game writes (click, panel, menu, cutscene, chronicle, endings, detail, quiet).
func event(s, kind: String, data := {}) -> void:
	if _ready(s):
		_flush(s)
		_emit(kind, s, data)


# --- Every tick -----------------------------------------------------------------------------------------------------


## Called from the first thing Seasons.tick does, with the Sim.
func tick(s, _delta: float) -> void:
	if not _ready(s):
		return
	var now: float = s.seasons.time
	_now = now
	_flush(s)
	_flows(s)
	if now >= _look:
		_look = now + LOOK_SECONDS
		_looks(s, now)
	if now >= _tick_at:
		_tick_at = now + TICK_SECONDS
		_emit_tick(s, now)
	if now >= _snap_at:
		_snap_at = now + SNAP_SECONDS
		_emit_snap(s, now)


## Goods made by hand, carried by haulers and made by buildings, read from the flows' finished second and the hauler trips.
func _flows(s) -> void:
	var flows = s.economy.flows
	var second := floori(flows.clock)
	if second != _flow_second and not flows.hist.is_empty():
		_flow_second = second
		var made := 0.0
		for key in flows.hist.back():
			var amount: float = flows.hist.back()[key]
			var source: String = key.get_slice("|", 1)
			if amount <= 0.0:
				continue
			if source in [Data.FLOW_HAND_SOURCE, "craft"]:
				_hand += amount
				_hand_total += amount
			elif source not in [Data.FLOW_EAT_SOURCE, Data.FLOW_FORAGE_SOURCE]:
				made += amount
		_made += made
		_made_total += made
		_made_recent.append([s.seasons.time, made])
		while _made_recent.size() > 60:
			_made_recent.pop_front()
	var trips: Array = s.hauling.trip_log
	for i in range(trips.size() - 1, -1, -1):
		if trips[i]["at"] <= _trip_at:
			break
		_hauled += float(trips[i]["amount"])
		_hauled_total += float(trips[i]["amount"])
	if not trips.is_empty():
		_trip_at = maxf(_trip_at, float(trips[trips.size() - 1]["at"]))


## What changed in the town since the last look: eras, goals, techs, new kinds of building, stopped buildings, choices, mechanics.
func _looks(s, now: float) -> void:
	var era := _era_of(s)
	if era != _era:
		_era = era
		_progress_at = now
		_emit("era", s, {"era": era})
	for id in s.story.goals_done:
		if not _goals.has(id):
			_goals[id] = true
			_progress_at = now
			_emit("goal", s, {"id": id})
	for id in s.tech_tree.researched:
		if not _techs.has(id):
			_techs[id] = true
			_progress_at = now
			_emit("tech", s, {"id": id, "known": s.carry.knows_tech(id)})
	var seen := {}
	var standing := {}
	for b in s.town.buildings:
		seen[b["type"]] = true
		standing[b["pos"]] = b["type"]
		_watch_pause(s, b)
		if not _kinds.has(b["type"]):
			_kinds[b["type"]] = true
			_progress_at = now
		_watch_alert(s, b, now)
	_watch_loss(s, standing)
	_watch_hands(s)
	var asking: bool = s.starfall.pending != ""
	if _pending_choice and not asking:
		_choices += 1
		act(s, "choice", "moment", true)
	_pending_choice = asking
	var season: bool = s.seasons.phase == "pending"
	if _season_pending and not season and s.seasons.phase == "active":
		act(s, "choice", "season", true)
	_season_pending = season
	if not _used.has(era) and _mechanic_used(s, era, seen):
		_used[era] = true
		_emit("first_use", s, {"era": era, "what": MECHANICS[era]})


## A pause or resume the player made.
func _watch_pause(s, b: Dictionary) -> void:
	var p: Vector2i = b["pos"]
	var now: bool = bool(b.get("paused", false))
	if now != _paused.has(p):
		if now:
			_paused[p] = true
		else:
			_paused.erase(p)
		act(s, "pause" if now else "resume", b["type"], true, {"pos": [p.x, p.y]})


## Buildings the Bloom took since the last look: tiles that stood and are gone though nobody demolished them.
func _watch_loss(s, standing: Dictionary) -> void:
	var taken: int = s.tide.lost - _lost_seen
	_lost_seen = s.tide.lost
	for p in _at_type.keys():
		if not standing.has(p) and taken > 0:
			taken -= 1
			lost(s, _at_type[p], p)
	_at_type = standing


## Each harvest by hand, from the Sim's own count of them: upkeep, and a chore when it is repeated.
func _watch_hands(s) -> void:
	for item in s.hand_counts:
		var more: int = s.hand_counts[item] - int(_hand_seen.get(item, 0))
		for i in more:
			act(s, "hand", item, false)
		_hand_seen[item] = s.hand_counts[item]


## A building whose alert has stayed up STOP_HOLD seconds is stopped: one `stopped` line until it has run STOP_HOLD seconds.
func _watch_alert(s, b: Dictionary, now: float) -> void:
	var p: Vector2i = b["pos"]
	if b["alert"] != "":
		_clear_since.erase(p)
		if not _alert_since.has(p):
			_alert_since[p] = now
		if now - _alert_since[p] >= STOP_HOLD and not _stopped.has(p):
			_stopped[p] = true
			_emit("stopped", s, {"what": b["type"], "pos": [p.x, p.y], "why": str(b["alert"]).left(40)})
	else:
		_alert_since.erase(p)
		if not _clear_since.has(p):
			_clear_since[p] = now
		if now - _clear_since[p] >= STOP_HOLD:
			_stopped.erase(p)


func _mechanic_used(s, era: int, seen: Dictionary) -> bool:
	match era:
		1:
			return not s.hand_counts.is_empty()
		2:
			return seen.has("crucible")
		3:
			return _choices > 0
		4:
			return not s.teardown.lessons.is_empty()
		5:
			return seen.has("power_pole") or s.livewire.orders.size() > 0
		6:
			return seen.has("signal_tower")
	return false


func _emit_tick(s, now: float) -> void:
	var goals: Array = s.story.goal_list()
	var at: int = s.story.current_goal()
	_emit(
		"tick",
		s,
		{
			"era": _era,
			"dec": _decisions,
			"up": _upkeep,
			"touch": _touch,
			"hand": snappedf(_hand, 0.1),
			"hauled": snappedf(_hauled, 0.1),
			"made": snappedf(_made, 0.1),
			"goal": goals[at]["id"] if at < goals.size() else "",
			"since": snappedf(now - _progress_at, 1.0),
			"afford": _affordable(s),
			"kith": s.people.kith.size()
		}
	)
	_decisions = 0
	_upkeep = 0
	_touch = 0
	_hand = 0.0
	_hauled = 0.0
	_made = 0.0
	_unwritten = 0
	if _file != null:
		_file.flush()


func _emit_snap(s, now: float) -> void:
	var per_min := 0.0
	for pair in _made_recent:
		if pair[0] > now - 60.0:
			per_min += pair[1]
	var by_type := {}
	for b in s.town.buildings:
		by_type[b["type"]] = by_type.get(b["type"], 0) + 1
	_emit(
		"snap",
		s,
		{
			"era": _era,
			"buildings": s.town.buildings.size(),
			"types": by_type,
			"out_min": snappedf(per_min, 0.1),
			"hand_total": snappedf(_hand_total, 1.0),
			"hauled_total": snappedf(_hauled_total, 1.0),
			"made_total": snappedf(_made_total, 1.0)
		}
	)


## True when the player could pay for a step that moves the goal on show: the research or building it names (or a tech that
## is ready, on the way to it). A goal that names neither counts anything worth building (roads and bridges, always cheap, do not).
func _affordable(s) -> bool:
	var goals: Array = s.story.goal_list()
	var at: int = s.story.current_goal()
	if at < goals.size():
		var g: Dictionary = goals[at]
		var building: String = g.get("building", "grindstone" if g["id"] == "grind" else "")
		if g.has("tech") or building != "":
			if not s.tech_tree.ready_list().is_empty():
				return true
			if building != "":
				return s.town.unlocked(building) and s.economy.can_afford(Data.BUILDINGS[building]["cost"])
			return s.tech_tree.can_research(g["tech"])
	for type in Data.BUILDINGS:
		if Data.BUILDINGS[type]["kind"] in ["road", "bridge"] or not s.town.unlocked(type):
			continue
		if s.economy.can_afford(Data.BUILDINGS[type]["cost"]):
			return true
	return false


## The era now: 1 stone age, 2 Bronze Dawn, 3 Starfall, 4 Ironfall, 5 Livewire, 6 Skyreach.
func _era_of(s) -> int:
	var events: Array = s.story.events
	if "skyreach_begun" in events:
		return 6
	if Data.LIVEWIRE_BEGUN in events:
		return 5
	if Data.IRONFALL_EVENT in events:
		return 4
	if "star_falling" in events:
		return 3
	return 2 if "bronze_dawn" in events else 1


func _ready(s) -> bool:
	if not _begun:
		begin(s)
	return _file != null


func _emit(kind: String, s, data: Dictionary) -> void:
	var out := {"k": kind, "m": snappedf(s.seasons.time / 60.0, 0.01)}
	out.merge(data)
	var line := JSON.stringify(out)
	if keep:
		lines.append(line)
	if _file != null:
		_file.store_line(line)
		_unwritten += 1
		if _unwritten >= FLUSH_LINES:
			_unwritten = 0
			_file.flush()
