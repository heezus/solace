extends SceneTree
## The game scene with its play recorder on (design-system/25-playtesting.md): it writes a log while the game runs, shows the
## three-question card once after an era card is put away and holds the game behind it, writes the answers, and closes the log
## with a reason when the scene goes. The recorder is off in a headless run, so this pass turns it on.
## Run: godot --headless --fixed-fps 60 --path . -s tests/tools/play_log_pass.gd   (exits 1 on a problem)

const CutscenePlayer = preload("res://scripts/cutscene_player.gd")
const PlayRecorder = preload("res://scripts/play_recorder.gd")
const PlaySummary = preload("res://tests/tools/play_summary.gd")

const DIR := "user://test_playlogs_scene/"

var frame := 0
var problems: Array = []
var main: Node
var recorder: Node
var log_path := ""


func _init() -> void:
	Engine.max_fps = 60  # a headless run has no vsync (CI passes --fixed-fps 60, which fixes each frame at 1/60 s however fast they run)
	CutscenePlayer.suppress = true
	PlayRecorder.allow_headless = true
	PlayRecorder.dir = DIR
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main


func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		5:
			for n in main.find_children("*", "Node", true, false):
				if n.get_script() == PlayRecorder:
					recorder = n
			_expect(recorder != null, "the game scene has a recorder")
			if recorder == null:
				return _finish()
			_expect(
				FileAccess.file_exists(recorder.journal.path), "it opened its log file (%s)" % recorder.journal.path
			)
		20:
			main.era_card.open("star_falling")  # an era card goes up...
		25:
			main.era_card.close()
		30:
			_expect(recorder.ask.visible, "the question card is up after the era card is put away")
			_expect(main.paused, "and the game waits behind it")
		60:  # long enough for the log to look at the card (it looks every quarter second)
			recorder.ask._choose("feel", "Good")
			recorder.ask._finish(recorder.ask._answers())
		65:
			_expect(not recorder.ask.visible and not main.paused, "answered, the card goes and the game goes on")
			var asked: int = recorder.journal.lines.size()
			recorder._on_era_card_closed()  # the same era closing again is not asked twice
			_expect(not recorder.ask.visible, "an era is asked about once")
			_expect(recorder.journal.lines.size() == asked, "and nothing more is written for it")
		75:
			log_path = recorder.journal.path
			main.queue_free()
		80:
			_check_after(log_path)
	return false


func _check_after(path: String) -> void:
	var entries := PlaySummary.read(path)
	_expect(entries.size() >= 3, "the log has lines (%d)" % entries.size())
	_expect(
		entries.any(func(e): return e.get("k") == "era_end" and e.get("feel") == "Good"), "it holds the era-end answers"
	)
	_expect(
		entries.any(func(e): return e.get("k") == "card" and e.get("id") == "ask"), "and the question card's own wait"
	)
	_expect(
		entries[entries.size() - 1].get("k") == "end" and entries[entries.size() - 1].get("why") == "left",
		"and closes with 'left'"
	)
	_finish()


func _expect(ok: bool, what: String) -> void:
	if not ok:
		problems.append(what)


func _finish() -> bool:
	for p in problems:
		print("PLAY LOG PROBLEM: ", p)
	print("Play log pass: %d frames, %d problems" % [frame, problems.size()])
	quit(1 if not problems.is_empty() else 0)
	return true
