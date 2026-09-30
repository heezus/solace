extends SceneTree
## The map's fit scale over a long run: the bot plays to Bronze Dawn with the UI refreshing every frame,
## and the map's scale may change only when the window size does (the bars must keep steady heights).
## Run: godot --headless --path . -s tests/tools/layout_pass.gd   (exits 1 on a problem)

const Autoplay = preload("res://tests/autoplay.gd")

const BOT_STEPS_PER_FRAME := 20
const MAX_FRAMES := 9000
const RESIZE_AT := 400  # frame: the window is resized once, and the map must refit

var main: Node
var bot: Autoplay
var frame := 0
var last_vp := Vector2.ZERO
var last_scale := Vector2.ZERO
var last_bars := Vector2.ZERO
var problems: Array = []
var changes := 0
var refit_due := 0  # the frame by which the map must have refit after a resize


func _init() -> void:
	seed(7)
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	main = scene.instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		main.paused = true
		bot = Autoplay.new()
		bot.attach(main.state)
	if frame > 3:
		for i in BOT_STEPS_PER_FRAME:
			if main.state.won:
				break
			main.state.tick(Autoplay.DT)
			bot.step(false)
		main.ui_refresh = 0.0  # refresh the bars every frame, so any wobble shows
	if frame == RESIZE_AT:
		root.size = Vector2i(1600, 800)  # wider: the map (fit to the width) must grow
	if frame > 5:
		_check()
	if main.state.won or frame > MAX_FRAMES:
		_finish()
	return false


func _check() -> void:
	var vp: Vector2 = main.get_viewport_rect().size
	var bars := Vector2(main.top_bar.size.y, main.bottom_bar.size.y)
	if last_scale != Vector2.ZERO and main.scale != last_scale:
		changes += 1
		if vp == last_vp and refit_due == 0:
			problems.append(
				(
					"frame %d: the map scale went %.4f -> %.4f with the window unchanged (bars %s -> %s)"
					% [frame, last_scale.x, main.scale.x, last_bars, bars]
				)
			)
	if last_vp != Vector2.ZERO and vp != last_vp:
		refit_due = frame + 2
	if refit_due > 0 and main.scale != last_scale:
		refit_due = 0
	elif refit_due > 0 and frame > refit_due:
		problems.append("frame %d: the window went to %s but the map didn't refit" % [frame, vp])
		refit_due = 0
	last_vp = vp
	last_scale = main.scale
	last_bars = bars


func _finish() -> void:
	if not main.state.won:
		problems.append("the bot didn't reach Bronze Dawn in %d frames" % MAX_FRAMES)
	for p in problems.slice(0, 20):
		printerr("LAYOUT PROBLEM: " + p)
	print(
		(
			"Layout pass: %d frames, %.1f simulated minutes, %d scale changes, %d problems"
			% [frame, bot.clock / 60.0, changes, problems.size()]
		)
	)
	quit(1 if not problems.is_empty() else 0)
