extends RefCounted
## The playtest log read back (scripts/playtest_log.gd): the fun rubric's measured metrics M1 to M15 as a markdown table, each with
## its target and PASS, MISS or N/A (the log has nothing to judge it by, e.g. no stopped building, no cutscene, no UI events in a
## scripted run). Static. `rows(entries, base)` gives the rows; `markdown(rows)` the table. `base` is an optional earlier telling's log
## (for M8, the run 2 speed-up). The definitions are in each metric's `how` line, so a reader can see what was counted.
## /mnt/project-files/director/fun-rubric.md holds the targets.

const ERA_NAMES := ["Stone Age", "Bronze Dawn", "Starfall", "Ironfall", "Livewire", "Skyreach"]
const AUTOMATION_TICKS := 12  # 12 tick lines of 10 game seconds: the chain runs 2 minutes untouched
const CHORE_COUNT := 5
const CHORE_SECONDS := 60.0
const STUCK_SECONDS := 180.0
const LONG_STUCK_MINUTES := 5.0  # a stuck spell longer than this misses M6 and is a near-quit for M10
const END_WINDOW := 5.0  # the last game minutes of an era that the hand share is read over
const NEAR_QUIT_PLACEMENTS := 3


## The lines of a log file, each parsed.
static func read(path: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		var d = JSON.parse_string(line) if line != "" else null
		if d is Dictionary:
			out.append(d)
	return out


## The 15 rows: {id, name, result, target, verdict, how}.
static func rows(entries: Array, base := []) -> Array:
	var run := _Run.new(entries)
	var out: Array = []
	out.append(_m1(run))
	out.append(_m2(run))
	out.append(_m3(run))
	out.append(_m4(run))
	out.append(_m5(run))
	out.append(_m6(run))
	out.append(_m7(run))
	out.append(_m8(run, _Run.new(base) if not base.is_empty() else null))
	out.append(_m9(run))
	out.append(_m10(run))
	out.append(_m11(run))
	out.append(_m12(run))
	out.append(_m13(run))
	out.append(_m14(run))
	out.append(_m15(run))
	return out


## The table as markdown, with the counting rules under it.
static func markdown(table: Array, title := "Playtest metrics") -> String:
	var lines: Array = ["## " + title, "", "| # | Metric | Result | Target | |", "|---|---|---|---|---|"]
	var how: Array = []
	for r in table:
		lines.append("| M%d | %s | %s | %s | **%s** |" % [r["id"], r["name"], r["result"], r["target"], r["verdict"]])
		how.append("- M%d: %s" % [r["id"], r["how"]])
	var pass_n := table.filter(func(r): return r["verdict"] == "PASS").size()
	var miss_n := table.filter(func(r): return r["verdict"] == "MISS").size()
	lines.append("")
	lines.append("%d PASS, %d MISS, %d N/A." % [pass_n, miss_n, table.size() - pass_n - miss_n])
	lines.append("")
	lines.append_array(how)
	return "\n".join(lines) + "\n"


# --- The rows ----------------------------------------------------------------------------------------------------


static func _m1(r: _Run) -> Dictionary:
	var streak := 0
	var start := -1.0
	var found := -1.0
	for t in r.ticks:
		if t["made"] > 0.0 and t["hand"] == 0.0:
			if streak == 0:
				start = t["m"] - 1.0 / 6.0
			streak += 1
			if streak >= AUTOMATION_TICKS:
				found = start
				break
		else:
			streak = 0
	var result := "never" if found < 0.0 else "%.1f min" % found
	var verdict := "MISS" if found < 0.0 or found > 8.0 else "PASS"
	if r.telling > 1:
		verdict = "N/A"
	return _row(
		1,
		"Minutes to first automation",
		result,
		"8 or less in run 1",
		verdict,
		(
			"the first 12 tick lines in a row (2 game minutes) with goods made by buildings and none made by hand;"
			+ " building other things in that time is allowed"
		)
	)


static func _m2(r: _Run) -> Dictionary:
	var parts: Array = []
	var ok := true
	var any := false
	for e in r.eras:
		var hand := 0.0
		var hauled := 0.0
		for t in r.ticks:
			if t["era"] == e["era"] and t["m"] >= e["end"] - END_WINDOW and t["m"] <= e["end"]:
				hand += t["hand"]
				hauled += t["hauled"]
		if hand + hauled <= 0.0:
			continue
		var share := hand / (hand + hauled)
		parts.append("%s %d%%" % [_name(e["era"]), roundi(share * 100.0)])
		if e["era"] > 1:  # the haulers come in Bronze Dawn: the stone age is read but not judged
			any = true
			ok = ok and share < 0.2
	return _row(
		2,
		"Hand share",
		", ".join(parts) if not parts.is_empty() else "no goods moved",
		"under 20% at the end of each era",
		("PASS" if ok else "MISS") if any else "N/A",
		"goods made by hand over hand plus goods carried by haulers, over the last 5 game minutes of each era (the stone age is not judged)"
	)


static func _m3(r: _Run) -> Dictionary:
	var counts := {}
	var keys := {}
	for a in r.acts:
		if not a["decision"] or a.has("pos"):
			var key: String = "%s/%s/%s" % [a["kind"], a["what"], str(a.get("pos", "")) if a["decision"] else ""]
			if not keys.has(key):
				keys[key] = []
			keys[key].append(a)
	for key in keys:
		var list: Array = keys[key]
		var i := 0
		while i + CHORE_COUNT - 1 < list.size():
			if (list[i + CHORE_COUNT - 1]["m"] - list[i]["m"]) * 60.0 <= CHORE_SECONDS:
				var era: int = r.era_at(list[i]["m"])
				counts[era] = counts.get(era, 0) + 1
				i += CHORE_COUNT
			else:
				i += 1
	var parts: Array = []
	var worst := 0
	for e in r.eras:
		var n: int = counts.get(e["era"], 0)
		worst = maxi(worst, n)
		parts.append("%s %d" % [_name(e["era"]), n])
	return _row(
		3,
		"Chore detector",
		", ".join(parts),
		"0 to 2 per era",
		"PASS" if worst <= 2 else "MISS",
		"the same upkeep act (a hand harvest, a pause) 5 or more times in 60 s, or the same decision at the same tile; each run of 5 is one hit"
	)


static func _m4(r: _Run) -> Dictionary:
	var minutes := maxf(r.minutes, 0.01)
	var decisions := r.acts.filter(func(a): return a["decision"]).size()
	var share := float(decisions) / maxf(float(r.acts.size()), 1.0)
	var clicks := r.count("click")
	var per_min := (clicks if clicks > 0 else r.acts.size()) / minutes
	return _row(
		4,
		"Clicks per game minute",
		(
			"%.1f (%s), %d%% decisions"
			% [per_min, "clicks" if clicks > 0 else "acts, no clicks logged", roundi(share * 100.0)]
		),
		"60% or more decisions",
		"PASS" if share >= 0.6 else "MISS",
		"mouse presses from the recorder (acts in a scripted run); decisions are builds, research, choices, demolishes and endings over all acts"
	)


static func _m5(r: _Run) -> Dictionary:
	var idle := 0
	for t in r.ticks:
		if t["since"] >= 60.0 and not t["afford"]:
			idle += 1
	var share := float(idle) / maxf(float(r.ticks.size()), 1.0)
	return _row(
		5,
		"Idle share",
		"%d%%" % roundi(share * 100.0),
		"5% to 20%",
		"PASS" if share >= 0.05 and share <= 0.20 else "MISS",
		(
			"tick lines where nothing had progressed for a minute (no goal, tech, new kind of building or era)"
			+ " and nothing was affordable that moves the goal on show"
		)
	)


## The stuck spells of a run: {era, m (when it passed 3 minutes), goal, minutes (how long it lasted, from the last progress)}.
static func _spells(r: _Run) -> Array:
	var out: Array = []
	var inside := false
	for t in r.ticks:
		if t["since"] >= STUCK_SECONDS:
			if not inside:
				inside = true
				out.append({"era": int(t["era"]), "m": t["m"], "goal": str(t["goal"]), "minutes": 0.0})
			out.back()["minutes"] = maxf(out.back()["minutes"], float(t["since"]) / 60.0)
		else:
			inside = false
	return out


static func _m6(r: _Run) -> Dictionary:
	var spells := _spells(r)
	var counts := {}
	var longest := 0.0
	var total := 0.0
	var waited: Array = []
	for sp in spells:
		counts[sp["era"]] = counts.get(sp["era"], 0) + 1
		longest = maxf(longest, sp["minutes"])
		total += sp["minutes"]
		waited.append(
			(
				"%s %.0f min on %s, %.1f min"
				% [_name(sp["era"]), sp["m"], sp["goal"] if sp["goal"] != "" else "no goal left", sp["minutes"]]
			)
		)
	var worst := 0
	var parts: Array = []
	for e in r.eras:
		var n: int = counts.get(e["era"], 0)
		worst = maxi(worst, n)
		parts.append("%s %d" % [_name(e["era"]), n])
	var result := ", ".join(parts)
	if not spells.is_empty():
		result += "; longest %.1f min, %.1f min stuck in all" % [longest, total]
		result += " (%s)" % "; ".join(waited.slice(0, 3))
	return _row(
		6,
		"Stuck spells",
		result,
		"0 to 1 per era, none over 5 min",
		"PASS" if worst <= 1 and longest <= LONG_STUCK_MINUTES else "MISS",
		(
			"3 game minutes or more with no progress (a goal, a tech, a new kind of building, an era); the goal then"
			+ " showing is what was waited on; a spell over 5 minutes misses"
		)
	)


static func _m7(r: _Run) -> Dictionary:
	var parts: Array = []
	var ok := true
	var judged := false
	for e in r.eras:
		if not e["done"]:
			continue
		var minutes: float = e["end"] - e["start"]
		var first := r.first_use(e["era"])
		parts.append(
			"%s %.1f min, first use %s" % [_name(e["era"]), minutes, "none" if first < 0.0 else "%.1f" % first]
		)
		judged = true
		ok = ok and minutes >= 12.0 and minutes <= 25.0 and first >= 0.0 and first <= 3.0
	return _row(
		7,
		"Era minutes and first use",
		"; ".join(parts) if judged else "no era finished",
		"era 12 to 25 min, first use 3 min or less",
		("PASS" if ok else "MISS") if judged else "N/A",
		(
			"game minutes from an era's start to the next one (finished eras only); first use is the first sign"
			+ " of the era's new mechanic, in minutes from its start"
		)
	)


static func _m8(r: _Run, base: _Run) -> Dictionary:
	if base == null:
		return _row(
			8,
			"Run 2 speed-up",
			"needs a run 1 log (--base=)",
			"20% or more faster",
			"N/A",
			"each finished era's minutes against the same era in the run 1 log; known techs researched are counted"
		)
	var parts: Array = []
	var ok := true
	var judged := false
	for e in r.eras:
		if not e["done"]:
			continue
		for b in base.eras:
			if b["era"] == e["era"] and b["done"]:
				var was: float = b["end"] - b["start"]
				var now: float = e["end"] - e["start"]
				var gain := 1.0 - now / maxf(was, 0.01)
				parts.append("%s %d%%" % [_name(e["era"]), roundi(gain * 100.0)])
				ok = ok and gain >= 0.2
				judged = true
	var known := r.entries.filter(func(x): return x["k"] == "tech" and x.get("known", false)).size()
	return _row(
		8,
		"Run 2 speed-up",
		("%s; %d known techs used" % [", ".join(parts), known]) if judged else "no era finished in both",
		"20% or more faster",
		("PASS" if ok else "MISS") if judged else "N/A",
		"each finished era's minutes against the same era in the run 1 log; known techs researched are counted"
	)


static func _m9(r: _Run) -> Dictionary:
	var losses := r.entries.filter(func(x): return x["k"] == "loss")
	var warned := losses.filter(func(x): return x["warned"]).size()
	var share := float(warned) / maxf(float(losses.size()), 1.0)
	return _row(
		9,
		"Bloom losses",
		(
			"%d lost, %d warned (%d%%)" % [losses.size(), warned, roundi(share * 100.0)]
			if not losses.is_empty()
			else "none lost"
		),
		"70% or more warned",
		("PASS" if share >= 0.7 else "MISS") if not losses.is_empty() else "N/A",
		"buildings the Bloom took; warned means the game had told the player the tide was coming for that building (Tide Watch) first"
	)


static func _m10(r: _Run) -> Dictionary:
	var n := r.count("quiet")
	var failed := {}
	for a in r.acts:
		if a["kind"] == "build_failed":
			var key := "%s/%s" % [a["what"], str(a.get("pos", ""))]
			failed[key] = failed.get(key, 0) + 1
	for key in failed:
		if failed[key] >= NEAR_QUIT_PLACEMENTS:
			n += 1
	for sp in _spells(r):
		if sp["minutes"] > LONG_STUCK_MINUTES:
			n += 1
	var open_at := -1.0
	var acted := false
	for x in r.entries:
		if x["k"] == "menu" and x["open"]:
			open_at = x["m"]
			acted = false
		elif x["k"] == "act" and open_at >= 0.0:
			acted = true
		elif x["k"] == "menu" and not x["open"] and open_at >= 0.0:
			if not acted:
				n += 1
			open_at = -1.0
	var per_hour := n / maxf(r.minutes / 60.0, 0.01)
	return _row(
		10,
		"Near-quit moments",
		"%d (%.1f an hour)" % [n, per_hour],
		"0 to 1 per hour",
		"PASS" if per_hour <= 1.0 else "MISS",
		(
			"2 real minutes with no click or key, the same placement failing 3 times, the pause menu opened and shut with no act"
			+ " between, or a stuck spell over 5 game minutes"
		)
	)


static func _m11(r: _Run) -> Dictionary:
	var scenes := r.entries.filter(func(x): return x["k"] == "cutscene")
	var watched := scenes.filter(func(x): return not x["skipped"]).size()
	var chronicle := r.count("chronicle")
	var lore := r.entries.filter(func(x): return x["k"] == "chronicle" and x["page"] == "lore").size()
	var ok := chronicle >= 1 and (scenes.is_empty() or watched * 2 >= scenes.size())
	var seen := not scenes.is_empty() or r.count("click") > 0
	return _row(
		11,
		"Story reach",
		"%d of %d scenes watched, %d Chronicle opens, %d Lore opens" % [watched, scenes.size(), chronicle, lore],
		"50% or more watched, 1 or more Chronicle visit",
		("PASS" if ok else "MISS") if seen else "N/A",
		"cutscenes not skipped over all that played; times the Chronicle book was opened or changed page; Lore page opens"
	)


static func _m12(r: _Run) -> Dictionary:
	var stops := r.entries.filter(func(x): return x["k"] == "stopped")
	var counts: Array = []
	var never := 0
	for s in stops:
		var clicks := 0
		var opened := false
		for x in r.entries:
			if x["m"] < s["m"]:
				continue
			if x["k"] == "click":
				clicks += 1
			elif x["k"] == "panel" and x["pos"] == s["pos"]:
				opened = true
				break
		if opened:
			counts.append(clicks)
		else:
			never += 1
	if counts.is_empty():
		return _row(
			12,
			"Answer clicks",
			"%d stopped, no card opened" % stops.size(),
			"2 or fewer",
			"N/A",
			"clicks from a building showing it stopped to its card opening"
		)
	var total := 0
	for c in counts:
		total += c
	var mean := float(total) / counts.size()
	return _row(
		12,
		"Answer clicks",
		"%.1f clicks (%d opened, %d never)" % [mean, counts.size(), never],
		"2 or fewer",
		"PASS" if mean <= 2.0 else "MISS",
		"clicks from a building first showing it stopped (an alert up) to its card opening, the click on the building included"
	)


static func _m13(r: _Run) -> Dictionary:
	var shut := r.entries.filter(func(x): return x["k"] == "endings" and not x["open"])
	if shut.is_empty():
		return _row(
			13,
			"Endings card dwell",
			"card never opened",
			"20 s or more, 2 or more details",
			"N/A",
			"real seconds the endings card was up, and the ending details (the confirm card) opened"
		)
	var longest := 0.0
	for x in shut:
		longest = maxf(longest, x["secs"])
	var seen := {}
	for x in r.entries:
		if x["k"] == "detail":
			seen[x["ending"]] = true
	return _row(
		13,
		"Endings card dwell",
		"%.0f s, %d details" % [longest, seen.size()],
		"20 s or more, 2 or more details",
		"PASS" if longest >= 20.0 and seen.size() >= 2 else "MISS",
		"real seconds the endings card was up (the longest visit) and how many different endings' details (the confirm card) were opened"
	)


static func _m14(r: _Run) -> Dictionary:
	var snaps := r.entries.filter(func(x): return x["k"] == "snap")
	if snaps.size() < 2:
		return _row(
			14,
			"Growth curve",
			"under 10 minutes of snapshots",
			"rises in every era, no flat 10 min",
			"N/A",
			"buildings and output per minute every 5 game minutes"
		)
	var flat := 0
	var falls: Array = []
	for i in range(1, snaps.size()):
		var a: Dictionary = snaps[i - 1]
		var b: Dictionary = snaps[i]
		if b["era"] == a["era"] and b["buildings"] <= a["buildings"] and b["out_min"] <= a["out_min"]:
			flat += 1
			falls.append("%s at %.0f min" % [_name(b["era"]), b["m"]])
	var first: Dictionary = snaps[0]
	var last: Dictionary = snaps[snaps.size() - 1]
	return _row(
		14,
		"Growth curve",
		(
			"%d to %d buildings, %.0f to %.0f goods a min, %d flat spells%s"
			% [
				first["buildings"],
				last["buildings"],
				first["out_min"],
				last["out_min"],
				flat,
				" (%s)" % "; ".join(falls.slice(0, 3)) if flat > 0 else ""
			]
		),
		"rises in every era, no flat 10 min",
		"PASS" if flat == 0 and last["buildings"] > first["buildings"] else "MISS",
		"a flat spell is a snapshot in the same era with no more buildings and no more output a minute than the one 5 game minutes before"
	)


static func _m15(r: _Run) -> Dictionary:
	var builds := r.acts.filter(func(a): return a["kind"] == "build")
	var regrets := r.entries.filter(func(x): return x["k"] == "regret")
	var half := r.minutes / 2.0
	var early_b := builds.filter(func(a): return a["m"] < half).size()
	var late_b := builds.size() - early_b
	var early_r := regrets.filter(func(x): return x["m"] < half).size()
	var late_r := regrets.size() - early_r
	var rate := float(regrets.size()) / maxf(float(builds.size()), 1.0)
	var falling := float(late_r) / maxf(float(late_b), 1.0) <= float(early_r) / maxf(float(early_b), 1.0)
	return _row(
		15,
		"Regret",
		(
			"%d of %d builds (%d%%), %s"
			% [regrets.size(), builds.size(), roundi(rate * 100.0), "falling" if falling else "rising"]
		),
		"low and falling over the run",
		"PASS" if rate <= 0.1 and falling else "MISS",
		"buildings torn down within 60 s of being put up, over all builds; low is 10% or less, falling is a second half no worse than the first"
	)


static func _row(id: int, name: String, result: String, target: String, verdict: String, how: String) -> Dictionary:
	return {"id": id, "name": name, "result": result, "target": target, "verdict": verdict, "how": how}


static func _name(era: int) -> String:
	return ERA_NAMES[clampi(era - 1, 0, ERA_NAMES.size() - 1)]


## A log sorted into what the rows read: tick lines, acts and eras (each {era, start, end, done}, minutes).
class _Run:
	var entries: Array
	var ticks: Array = []
	var acts: Array = []
	var eras: Array = []
	var minutes := 0.0
	var telling := 1

	func _init(list: Array) -> void:
		entries = list
		for x in list:
			minutes = maxf(minutes, float(x.get("m", 0.0)))
			match x["k"]:
				"run":
					telling = int(x.get("telling", 1))
				"tick":
					ticks.append(x)
				"act":
					acts.append(x)
				"era":
					if not eras.is_empty():
						eras[eras.size() - 1]["end"] = x["m"]
						eras[eras.size() - 1]["done"] = true
					eras.append({"era": int(x["era"]), "start": x["m"], "end": x["m"], "done": false})
		if not eras.is_empty() and not eras[eras.size() - 1]["done"]:
			eras[eras.size() - 1]["end"] = minutes

	func count(kind: String) -> int:
		return entries.filter(func(x): return x["k"] == kind).size()

	## The era a game minute fell in.
	func era_at(m: float) -> int:
		var era := 1
		for e in eras:
			if e["start"] <= m:
				era = e["era"]
		return era

	## Minutes from an era's start to its first_use line, -1 when it was never used.
	func first_use(era: int) -> float:
		for x in entries:
			if x["k"] == "first_use" and int(x["era"]) == era:
				for e in eras:
					if e["era"] == era:
						return x["m"] - e["start"]
		return -1.0
