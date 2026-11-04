extends RefCounted
## The playtest log (scripts/playtest_log.gd, design-system/25-playtesting.md "The playtest log") and its summary (M1 to M15): off
## unless asked for, no change to the game when on, the lines it writes, and the table a log gives back. Run from tests/run_tests.gd.

const Autoplay = preload("res://tests/autoplay.gd")
const Data = preload("res://scripts/data.gd")
const GoldenTests = preload("res://tests/golden_tests.gd")
const PlaytestLog = preload("res://scripts/playtest_log.gd")
const PlaytestSummary = preload("res://scripts/playtest_summary.gd")
const Sim = preload("res://scripts/sim.gd")

const DIR := "user://test_playtest_logs/"

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	PlaytestLog.folder = DIR
	test_the_log_is_off_unless_asked_for()
	test_the_log_does_not_change_the_game()
	test_a_short_scripted_run_gives_a_log_and_fifteen_rows()
	test_what_the_player_does_is_logged()
	test_a_stopped_building_needs_ten_seconds()
	test_the_rows_read_a_log_by_their_rules()
	PlaytestLog.reset()


## A bot plays `seconds` of a map: the log's lines (empty when off) and the game's state hash after them.
func _played(map_seed: int, seconds: float, with_log: bool) -> Dictionary:
	var game := Sim.new()
	game.generate(map_seed)
	var journal := PlaytestLog.new()
	journal.keep = true
	if with_log:
		game.seasons.watcher = journal
	var bot := Autoplay.new()
	bot.attach(game)
	while bot.clock < seconds:
		bot.step(true)
	if with_log:
		journal.end(game, "test")
	return {"lines": journal.lines, "hash": GoldenTests.new().state_hash(game)}


## A building type that can go down now and a free tile near the Hearth for it ({"type", "pos"}), with the stock to pay for it.
func _site(game: Sim) -> Dictionary:
	for type in Data.BUILDINGS:
		if (
			Data.BUILDINGS[type]["kind"] in ["camp", "road", "bridge", "field", "depot", "pole"]
			or not game.town.unlocked(type)
		):
			continue
		for id in Data.BUILDINGS[type]["cost"]:
			game.economy.add(id, 500)
		for r in range(2, 9):
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					var p: Vector2i = game.world.camp_pos + Vector2i(dx, dy)
					if game.town.placement_error(type, p) == "":
						return {"type": type, "pos": p}
	return {"type": "", "pos": Vector2i(-1, -1)}


func _parsed(lines: Array) -> Array:
	var out: Array = []
	for l in lines:
		out.append(JSON.parse_string(l))
	return out


func test_the_log_is_off_unless_asked_for() -> void:
	PlaytestLog.reset()
	t.check(not PlaytestLog.wanted(), "no flag and no setting: the playtest log is off")
	t.check(Sim.new().seasons.watcher == null, "so a Sim has no log")
	PlaytestLog.folder = DIR


func test_the_log_does_not_change_the_game() -> void:
	var on := _played(3, 240.0, true)
	var off := _played(3, 240.0, false)
	t.check(
		on["lines"].size() > 20 and off["lines"].is_empty(), "the log wrote lines with the log on, none with it off"
	)
	t.check(on["hash"] == off["hash"], "the game ends the same with the log on or off (state hash)")


func test_a_short_scripted_run_gives_a_log_and_fifteen_rows() -> void:
	var entries := _parsed(_played(3, 600.0, true)["lines"])
	t.check(
		entries[0]["k"] == "run" and entries[0]["seed"] == 3 and entries[0]["v"] == 1, "the log opens with a run line"
	)
	t.check(entries[entries.size() - 1]["k"] == "end", "and closes with an end line")
	var kinds := {}
	for e in entries:
		kinds[e["k"]] = true
	for k in ["era", "act", "goal", "tech", "tick", "first_use"]:
		t.check(kinds.has(k), "a 10-minute bot game writes %s lines" % k)
	var ticks := entries.filter(func(e): return e["k"] == "tick")
	t.check(ticks.size() >= 55 and ticks.size() <= 61, "a tick line every 10 game seconds (%d in 600 s)" % ticks.size())
	var table := PlaytestSummary.rows(entries)
	var ids: Array = table.map(func(r): return r["id"])
	t.check(ids == range(1, 16), "the summary has all 15 rows, M1 to M15")
	var verdicts := table.filter(func(r): return r["verdict"] in ["PASS", "MISS", "N/A"])
	t.check(verdicts.size() == 15, "each with PASS, MISS or N/A")
	var text := PlaytestSummary.markdown(table, "test")
	t.check(
		text.contains("| M1 |") and text.contains("| M15 |") and text.contains("PASS"), "and prints as a markdown table"
	)
	t.check(table[6]["result"].contains("Stone Age") or table[6]["result"] == "no era finished", "M7 reads the eras")


func test_what_the_player_does_is_logged() -> void:
	var game := Sim.new()
	game.generate(5)
	var journal := PlaytestLog.new()
	journal.keep = true
	game.seasons.watcher = journal
	game.tick(0.1)
	var site := _site(game)
	var spot: Vector2i = site["pos"]
	t.check(game.place(site["type"], spot), "a %s went down" % site["type"])
	t.check(not game.place(site["type"], spot), "the same tile refuses a second building")
	game.demolish(spot)
	game.tick(0.1)  # the log writes what the town announced at the next tick
	var entries := _parsed(journal.lines)
	var did := func(kind: String) -> Array: return entries.filter(func(e): return e["k"] == "act" and e["kind"] == kind)
	t.check(did.call("build").size() >= 1 and did.call("build")[0]["decision"], "a build is an act and a decision")
	t.check(
		did.call("build_failed").size() == 1 and not did.call("build_failed")[0]["decision"],
		"a refused placement is upkeep"
	)
	t.check(did.call("demolish").size() == 1, "a demolish is an act")
	var regret := entries.filter(func(e): return e["k"] == "regret")
	t.check(regret.size() == 1 and regret[0]["age"] <= 60.0, "taking a building down inside a minute is regret")
	var run_before := journal.lines.size()
	var line: Array = []
	for i in 4:
		line.append(game.world.camp_pos + Vector2i(8 + i, 8))
	var laid := game.place_line("road", line)
	game.tick(0.1)
	var roads := _parsed(journal.lines.slice(run_before)).filter(
		func(e): return e["k"] == "act" and e["kind"] == "build"
	)
	t.check(
		laid == 0 or (roads.size() == 1 and roads[0]["n"] == laid), "a dragged line of roads is one act with its tiles"
	)
	t.check(game.place(site["type"], spot), "the site is free again")
	game.set_paused(game.town.building_at[spot], true)
	game.tick(1.5)
	game.set_paused(game.town.building_at[spot], false)
	game.tick(1.5)
	var pauses := _parsed(journal.lines).filter(func(e): return e["k"] == "act" and e["kind"] in ["pause", "resume"])
	t.check(pauses.size() == 2, "a pause and a resume are read from the building (%d)" % pauses.size())
	game.tide._told[Vector2i(3, 3)] = true
	journal.lost(game, "gatherers_hut", Vector2i(3, 3))
	journal.lost(game, "gatherers_hut", Vector2i(4, 4))
	var losses := _parsed(journal.lines).filter(func(e): return e["k"] == "loss")
	t.check(
		losses.size() == 2 and losses[0]["warned"] and not losses[1]["warned"],
		"a Bloom loss says whether the tide was announced"
	)


func test_a_stopped_building_needs_ten_seconds() -> void:
	var game := Sim.new()
	game.generate(5)
	var journal := PlaytestLog.new()
	journal.keep = true
	game.seasons.watcher = journal
	var site := _site(game)
	var spot: Vector2i = site["pos"]
	game.place(site["type"], spot)
	var b: Dictionary = game.town.buildings[game.town.building_at[spot]]
	journal.begin(game)
	b["alert"] = "Needs Wood"
	journal._watch_alert(game, b, 100.0)
	journal._watch_alert(game, b, 106.0)
	var early := _parsed(journal.lines).filter(func(e): return e["k"] == "stopped").size()
	journal._watch_alert(game, b, 111.0)
	journal._watch_alert(game, b, 140.0)
	var later := _parsed(journal.lines).filter(func(e): return e["k"] == "stopped").size()
	b["alert"] = ""
	journal._watch_alert(game, b, 141.0)  # a flicker is not the end of it
	b["alert"] = "Needs Wood"
	journal._watch_alert(game, b, 142.0)
	journal._watch_alert(game, b, 160.0)
	var flicker := _parsed(journal.lines).filter(func(e): return e["k"] == "stopped").size()
	b["alert"] = ""
	journal._watch_alert(game, b, 170.0)
	journal._watch_alert(game, b, 181.0)  # gone for 10 s: over
	b["alert"] = "Needs Wood"
	journal._watch_alert(game, b, 190.0)
	journal._watch_alert(game, b, 201.0)
	var again := _parsed(journal.lines).filter(func(e): return e["k"] == "stopped").size()
	t.check(
		early == 0 and later == 1 and flicker == 1 and again == 2,
		"a stop is an alert up 10 s, once, until it has been gone 10 s (%d %d %d %d)" % [early, later, flicker, again]
	)


func test_the_rows_read_a_log_by_their_rules() -> void:
	var entries: Array = [
		{"k": "run", "m": 0.0, "telling": 1},
		{"k": "era", "m": 0.0, "era": 1},
		{"k": "stopped", "m": 5.0, "what": "kiln", "pos": [1, 1]},
		{"k": "click", "m": 5.1},
		{"k": "click", "m": 5.2},
		{"k": "panel", "m": 5.2, "what": "kiln", "pos": [1, 1]},
		{"k": "loss", "m": 6.0, "what": "hut", "pos": [2, 2], "warned": true},
		{"k": "loss", "m": 6.1, "what": "hut", "pos": [3, 3], "warned": false},
		{"k": "endings", "m": 7.0, "open": true},
		{"k": "endings", "m": 7.5, "open": false, "secs": 30.0},
		{"k": "detail", "m": 7.2, "ending": "heal"},
		{"k": "detail", "m": 7.3, "ending": "seal"},
		{"k": "cutscene", "m": 7.6, "id": "a", "skipped": false, "secs": 12.0},
		{"k": "cutscene", "m": 7.7, "id": "b", "skipped": true, "secs": 1.0},
		{"k": "chronicle", "m": 8.0, "page": "lore"},
		{"k": "era", "m": 14.0, "era": 2},
		{"k": "end", "m": 20.0, "why": "test"}
	]
	var by := {}
	for r in PlaytestSummary.rows(entries):
		by[r["id"]] = r
	t.check(
		by[12]["verdict"] == "PASS" and by[12]["result"].begins_with("2.0 clicks"),
		"M12 counts the clicks to the card (%s)" % by[12]["result"]
	)
	t.check(
		by[9]["verdict"] == "MISS" and by[9]["result"].contains("50%"),
		"M9: one of two losses warned is a MISS (%s)" % by[9]["result"]
	)
	t.check(
		by[13]["verdict"] == "PASS" and by[13]["result"].contains("2 details"),
		"M13: 30 s and two details is a PASS (%s)" % by[13]["result"]
	)
	t.check(
		by[11]["verdict"] == "PASS" and by[11]["result"].contains("1 of 2"),
		"M11: one of two scenes watched, a Chronicle visit (%s)" % by[11]["result"]
	)
	t.check(by[7]["result"].contains("Stone Age 14.0 min"), "M7: the stone age ran 14 minutes (%s)" % by[7]["result"])
	t.check(by[8]["verdict"] == "N/A", "M8 needs a run 1 log")
	var again := PlaytestSummary.rows(entries, entries)
	t.check(
		again[7]["verdict"] == "MISS" and again[7]["result"].contains("0%"),
		"M8 with the same run as its baseline is no speed-up"
	)
