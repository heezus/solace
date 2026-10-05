extends SceneTree
const Bot = preload("res://tests/autoplay_bronze.gd")
const Autoplay = preload("res://tests/autoplay.gd")
var main: Node
var pointer_locked := false
var bot: Bot
var frame := 0
var ticks := 0
var stage := 0
var wait_frames := 0


func _init() -> void:
	seed(7)
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	main = scene.instantiate()
	main.ground = (
		load("res://docs/art/overhaul/misty-highlands/grounding-studies/sculpted-native-study/study-ground.gd").new()
	)
	root.add_child(main)
	root.size = Vector2i(1280, 800)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		main.paused = true
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 800)
		bot = Bot.new()
		bot.attach(main.state)
	if frame <= 3:
		return false
	if wait_frames > 0:
		wait_frames -= 1
		if wait_frames == 0:
			capture.call_deferred()
		return false
	var target := 900.0
	if ticks * Autoplay.DT < target:
		for i in 20:
			main.state.tick(Autoplay.DT)
			bot.step(false)
			ticks += 1
		main.ui_refresh = 0.0
	else:
		main.messages.active.clear()
		main.messages.changed.emit()
		main.hover = Vector2i(-1, -1)
		if not pointer_locked:
			Input.warp_mouse(Vector2(20, 20))
			pointer_locked = true
		wait_frames = 8
	return false


func capture() -> void:
	var name := "settlement-48px" if stage == 0 else "settlement-64px"
	if stage == 2:
		name = "settlement-64px-comparison"
	var path := "/tmp/solace-sculpted-native/%s.png" % name
	var err := root.get_texture().get_image().save_png(path)
	print("Actual Godot capture: ", path, " error=", err)
	stage += 1

	if stage == 1:
		main.zoom_step = 2
		main.center_on(main.state.world.camp_pos + Vector2i(3, 0))
		wait_frames = 8
	elif stage == 2:
		quit(0)
