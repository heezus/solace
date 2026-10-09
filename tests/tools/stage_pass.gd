extends SceneTree
## Observer pass over stage starts (the Load screen's starts): builds each start in $STAGE_IDS (comma list), starts the real
## main scene from it, runs 3x for a few game minutes and saves screenshots plus a log of the goals, info and toasts.
## Nothing plays, so it shows what a newcomer sees on arriving at the stage. Output goes to $NEWBIE_OUT.
## Run under a display: xvfb-run godot --rendering-driver opengl3 --path . -s tests/tools/stage_pass.gd

const DevStarts = preload("res://scripts/dev_starts.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Launch = preload("res://scripts/launch.gd")

const SHOT_EVERY := 45.0  # game seconds between shots
const SHOTS := 4

var main: Node
var game_time := 0.0
var shot_n := 0
var out_dir := "user://stages"
var log_lines: Array = []


func _init() -> void:
	var o := OS.get_environment("NEWBIE_OUT")
	if o != "":
		out_dir = o
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _process(delta: float) -> bool:
	game_time += delta
	return false


func _say(text: String) -> void:
	var line := "[%6.1fs] %s" % [game_time, text]
	print(line)
	log_lines.append(line)
	var f := FileAccess.open(out_dir + "/log.txt", FileAccess.WRITE)
	f.store_string("\n".join(log_lines))


func _wait(sec: float) -> void:
	var until := game_time + sec
	while game_time < until:
		await process_frame


func _run() -> void:
	var ids := OS.get_environment("STAGE_IDS").split(",", false)
	if ids.is_empty():
		ids = PackedStringArray(DevStarts.ids())
	for id in ids:
		_say("STAGE %s: building (a bot may play to it)" % id)
		var sim = DevStarts.build(id)
		if sim == null:
			_say("STAGE %s: unknown id" % id)
			continue
		Launch.ask_stage(RunSave.dump(sim))
		main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		await _wait(2.0)
		await _shot(id + "_arrive")
		main._set_speed(3)
		for i in SHOTS:
			await _wait(SHOT_EVERY / 3.0)
			await _shot("%s_t%d" % [id, int((i + 1) * SHOT_EVERY)])
		main.queue_free()
		await process_frame
	_say("DONE")
	quit(0)


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	shot_n += 1
	root.get_texture().get_image().save_png("%s/%02d_%s.png" % [out_dir, shot_n, name])
	_say("SHOT %02d %s\n    %s" % [shot_n, name, _screen_text()])


func _screen_text() -> String:
	var goals: Array = []
	for g in main.side_panel.goal_labels:
		if g.text != "":
			goals.append(g.text)
	var toasts: Array = []
	for m in main.messages.active:
		toasts.append(m["text"])
	var s = main.state
	var inv := []
	for k in s.economy.inv:
		if s.economy.inv[k] > 0:
			inv.append("%s %d" % [k, s.economy.inv[k]])
	return (
		"GOALS: %s\n    INFO: %s\n    TOAST: %s\n    CARD: era=%s moment=%s\n    HAVE: %s\n    KITH: %d"
		% [
			" | ".join(goals), main.side_panel.info_label.text.replace("\n", " / "), " || ".join(toasts),
			str(main.era_card.visible), str(main.moment_card.visible), ", ".join(inv), s.people.kith.size(),
		]
	)
