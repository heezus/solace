extends SceneTree
## Turn a play log (scripts/play_log.gd) into the scorecard's "measured play" lines (design-system/25-playtesting.md).
## Run: godot --headless --path . -s tests/tools/play_summary.gd -- <log.jsonl> [more logs]
## With no path it reads every log in the game's user folder (the Mac's: ~/Library/Application Support/Godot/app_userdata/Solace/playlogs).

const Data = preload("res://scripts/data.gd")

const DECISIONS := ["built", "removed", "researched", "orders", "season"]  # the acts that count as a decision
const QUIET_SECONDS := 30.0  # no click or key for this long counts as waiting


func _init() -> void:
	var paths: Array = []
	for a in OS.get_cmdline_user_args():
		paths.append(a)
	if paths.is_empty():
		for f in DirAccess.get_files_at(Data.PLAYLOG_DIR):
			if f.ends_with(".jsonl"):
				paths.append(Data.PLAYLOG_DIR + f)
	paths.sort()
	for p in paths:
		print(p)
		print(report(read(p)))
	quit()


## The lines of a log file, each parsed (a line that is not JSON is left out).
static func read(path: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		if line == "":
			continue
		var d = JSON.parse_string(line)
		if d is Dictionary:
			out.append(d)
	return out


## The numbers a log gives: game minutes played, decisions and decisions a minute, minutes with no click or key, the longest quiet,
## how long each card waited, the goods that were full, the leanest food, the era-end answers and how the run ended.
static func summarize(entries: Array) -> Dictionary:
	var out := {
		"minutes": 0.0,
		"decisions": 0,
		"per_minute": 0.0,
		"idle_minutes": 0.0,
		"longest_quiet": 0.0,
		"cards": {},
		"full": {},
		"least_food_secs": -1,
		"eras": [],
		"ended": "not closed",
		"era": 0,
	}
	var idle := 0
	for e in entries:
		match e.get("k", ""):
			"sample":
				out["minutes"] = maxf(out["minutes"], float(e["t"]) / 60.0)
				out["era"] = int(e["era"])
				if int(e["inputs"]) == 0:
					idle += 1
				out["longest_quiet"] = maxf(out["longest_quiet"], float(e["quiet"]))
				for g in e["full"]:
					out["full"][g] = out["full"].get(g, 0) + 1
				var fs := int(e["food_secs"])
				if out["least_food_secs"] < 0 or fs < out["least_food_secs"]:
					out["least_food_secs"] = fs
			"act":
				if e["did"] in DECISIONS:
					out["decisions"] += int(e.get("n", 1))
			"card":
				if e["state"] == "closed":
					var w: Array = out["cards"].get(e["id"], [])
					w.append(float(e["waited"]))
					out["cards"][e["id"]] = w
			"era_end":
				out["eras"].append(e)
			"end":
				out["ended"] = e["why"]
	if out["minutes"] > 0.0:
		out["per_minute"] = snappedf(out["decisions"] / out["minutes"], 0.1)
	out["idle_minutes"] = snappedf(idle * Data.PLAYLOG_SAMPLE_SECONDS / 60.0, 0.1)
	return out


## The summary as the lines the scorecard's Measured play block takes.
static func report(entries: Array) -> String:
	var s := summarize(entries)
	var lines: Array = []
	lines.append("  played: %.1f game minutes to era %d, ended: %s" % [s["minutes"], s["era"], s["ended"]])
	lines.append(
		(
			"  measured: %d decisions (%s a minute), %s minutes with no click or key, longest quiet %d s"
			% [s["decisions"], s["per_minute"], s["idle_minutes"], roundi(s["longest_quiet"])]
		)
	)
	for id in s["cards"]:
		var w: Array = s["cards"][id]
		var total := 0.0
		for x in w:
			total += x
		lines.append(
			"  card %s: %d times, %.0f s on average, %.0f s at most" % [id, w.size(), total / w.size(), w.max()]
		)
	if not s["full"].is_empty():
		lines.append("  full goods (samples): %s" % str(s["full"]))
	lines.append("  least food: %d s" % s["least_food_secs"])
	for e in s["eras"]:
		lines.append(
			(
				"  era %s: felt %s, in the way: %s, play on: %s"
				% [e["id"], e.get("feel", ""), e.get("block", ""), e.get("onward", "")]
			)
		)
	return "\n".join(lines)
