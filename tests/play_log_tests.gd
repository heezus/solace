extends RefCounted
## The play log (scripts/play_log.gd, design-system/25-playtesting.md): what it writes, that it never changes a game, the era-end
## card and the pause menu's switch, and the summary tool that reads a log back. Run from tests/run_tests.gd.

const Autoplay = preload("res://tests/autoplay.gd")
const Data = preload("res://scripts/data.gd")
const GoldenTests = preload("res://tests/golden_tests.gd")
const PlayAskCard = preload("res://scripts/play_ask_card.gd")
const PlayLog = preload("res://scripts/play_log.gd")
const PlayLogSettings = preload("res://scripts/play_log_settings.gd")
const PlaySummary = preload("res://tests/tools/play_summary.gd")
const Sim = preload("res://scripts/sim.gd")

const DIR := "user://test_playlogs/"

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_a_log_has_a_run_samples_and_what_the_bot_did()
	test_the_log_does_not_change_the_game()
	test_cards_and_the_era_end_answers()
	test_the_question_card_gives_the_answers()
	test_the_switch_is_on_until_turned_off()
	test_the_summary_reads_a_log_back()


## A bot plays `seconds` of a map while the log watches: its lines, and the game's state hash after them.
func _played(map_seed: int, seconds: float, with_log: bool) -> Dictionary:
	var game := Sim.new()
	game.generate(map_seed)
	var bot := Autoplay.new()
	bot.attach(game)
	var journal := PlayLog.new()
	journal.keep = true
	if with_log:
		journal.begin(game, DIR, "test", Vector2i(1280, 720), "test build")
	while bot.clock < seconds:
		bot.step(true)
		if with_log:
			journal.note(game, {"speed": 1, "paused": false, "cards": []}, Autoplay.DT)
	if with_log:
		journal.end(game, "test")
	return {"lines": journal.lines, "hash": GoldenTests.new().state_hash(game)}


func test_a_log_has_a_run_samples_and_what_the_bot_did() -> void:
	var lines: Array = _played(3, 150.0, true)["lines"]
	var entries: Array = []
	for l in lines:
		entries.append(JSON.parse_string(l))
	t.check(entries.size() > 10, "the log has lines (%d)" % entries.size())
	t.check(entries[0]["k"] == "run" and entries[0]["seed"] == 3 and entries[0]["v"] == 1, "it opens with a run line")
	t.check(
		entries[entries.size() - 1]["k"] == "end" and entries[entries.size() - 1]["why"] == "test",
		"and closes with an end line"
	)
	var samples := entries.filter(func(e): return e["k"] == "sample")
	t.check(
		samples.size() >= 13 and samples.size() <= 16, "a sample every 10 game seconds (%d in 150 s)" % samples.size()
	)
	var rising := true
	for i in range(1, samples.size()):
		rising = rising and samples[i]["t"] > samples[i - 1]["t"]
	t.check(rising, "the samples run forward in time")
	var first: Dictionary = samples[0]
	for key in ["era", "kith", "idle", "food", "inv", "buildings", "goal", "quiet", "inputs", "season"]:
		t.check(first.has(key), "a sample says %s" % key)
	t.check(
		entries.any(func(e): return e["k"] == "act" and e["did"] == "built"), "an act line for each thing the bot built"
	)
	t.check(
		FileAccess.file_exists(entries[0].get("path", PlayLog.new().path) if false else DIR + "test-seed3.jsonl"),
		"the file is on disk"
	)


func test_the_log_does_not_change_the_game() -> void:
	var with_log := _played(3, 150.0, true)
	var without := _played(3, 150.0, false)
	t.check(with_log["hash"] == without["hash"], "the game ends the same with the log on or off (state hash)")


func test_cards_and_the_era_end_answers() -> void:
	var game := Sim.new()
	game.generate(5)
	var journal := PlayLog.new()
	journal.keep = true
	journal.begin(game, DIR, "cards", Vector2i(1280, 720), "test build")
	journal.note(game, {"cards": ["notice"]}, 0.3)
	journal.note(game, {"cards": ["notice"]}, 3.0)
	journal.note(game, {"cards": []}, 0.3)
	journal.era_end(game, "2", {"feel": "Good", "block": "Nothing", "onward": "Yes"})
	var closed: Dictionary = {}
	var ended: Dictionary = {}
	for l in journal.lines:
		var e: Dictionary = JSON.parse_string(l)
		if e["k"] == "card" and e["state"] == "closed":
			closed = e
		if e["k"] == "era_end":
			ended = e
	t.check(
		closed.get("id") == "notice" and closed.get("waited", 0.0) >= 3.0,
		"a card line says how long the card waited (%s)" % closed
	)
	t.check(
		ended.get("feel") == "Good" and ended.get("id") == "2" and ended.get("onward") == "Yes",
		"the era_end line carries the answers"
	)
	journal.end(game, "test")


func test_the_question_card_gives_the_answers() -> void:
	var card := PlayAskCard.new()
	card.setup()
	var got: Array = []
	card.answered.connect(func(a): got.append(a))
	card.open()
	card._choose("feel", "Dull")
	card._choose("feel", "Good")
	card._choose("onward", "Not now")
	card._finish(card._answers())
	t.check(
		got.size() == 1 and got[0]["feel"] == "Good" and got[0]["block"] == "" and got[0]["onward"] == "Not now",
		"Done gives the last pick of each row and '' for the rest (%s)" % [got]
	)
	card.open()
	card._finish({})
	t.check(got.size() == 2 and got[1].is_empty(), "Skip gives no answers")
	card._finish({})
	t.check(got.size() == 2, "a card put away answers once")
	card.free()


func test_the_switch_is_on_until_turned_off() -> void:
	var was := PlayLogSettings.path
	PlayLogSettings.path = "user://test_playlog.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayLogSettings.path))
	PlayLogSettings.reset()
	t.check(PlayLogSettings.on(), "the play log is on with no file")
	PlayLogSettings.set_on(false)
	PlayLogSettings.reset()
	t.check(not PlayLogSettings.on(), "and stays off once turned off")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayLogSettings.path))
	PlayLogSettings.path = was
	PlayLogSettings.reset()


func test_the_summary_reads_a_log_back() -> void:
	var entries := PlaySummary.read(DIR + "test-seed3.jsonl")
	var s := PlaySummary.summarize(entries)
	t.check(s["minutes"] > 2.0 and s["decisions"] > 3, "the summary counts minutes and decisions (%s)" % [s])
	t.check(s["ended"] == "test" and s["era"] >= 1, "and how it ended")
	t.check(PlaySummary.report(entries).contains("measured:"), "and prints the measured line")
