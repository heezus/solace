extends SceneTree
## The game scene as a player drives it: the title screen's New game, then the camera (wheel, trackpad scroll and the + and -
## keys), Esc for the pause menu, Save, and Load (which starts the scene again from the save). It fails the run on any wrong
## step. Run in CI under xvfb: godot --rendering-driver opengl3 --path . -s tests/tools/menu_pass.gd

const Data = preload("res://scripts/data.gd")
const RunSave = preload("res://scripts/run_save.gd")

var frame := 0
var problems: Array = []
var title: Node
var main: Node
var saved_wood := 0
var before := 0


func _init() -> void:
	if FileAccess.file_exists(RunSave.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RunSave.PATH))  # a clean slate
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title


func _expect(ok: bool, what: String) -> void:
	if not ok:
		problems.append(what)


func _mouse_to(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	Input.parse_input_event(m)


func _wheel(button: MouseButton, at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)


func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		5:
			_expect(title.get_class() == "Control" and title.has_method("start"), "the game opens on the title screen")
			title.start(false)
		12:
			main = current_scene
			_expect(main != null and main.has_method("_zoom"), "New game opens the game scene")
			if main == null or not main.has_method("_zoom"):
				return _done()
			main.era_card.close()
			main.paused = false
			_mouse_to(main.view.get_center())
		14:
			before = main.zoom_step
			_wheel(MOUSE_BUTTON_WHEEL_UP, main.view.get_center())
		16:  # input events reach the game a frame after they are sent
			_expect(main.zoom_step == before + 1, "the wheel zooms in")
			before = main.zoom_step
			_wheel(MOUSE_BUTTON_WHEEL_DOWN, main.view.get_center())
		18:
			_expect(main.zoom_step == before - 1, "the wheel zooms out")
			before = main.zoom_step
			main.zoom_wait = 0.0
			var e := InputEventPanGesture.new()
			e.position = main.view.get_center()
			e.delta = Vector2(0, -1.5)
			Input.parse_input_event(e)
		20:
			_expect(main.zoom_step == before + 1, "a trackpad scroll up zooms in")
			before = main.zoom_step
			_key(KEY_MINUS)
		21:
			_expect(main.zoom_step == before - 1, "the minus key zooms out")
		22:
			_key(KEY_ESCAPE)
		25:
			_expect(main.game_menu.is_open() and main.paused, "Esc opens the menu and pauses")
			saved_wood = 41
			main.state.economy.inv["wood"] = saved_wood
			main.game_menu.save_game()
			_expect(RunSave.exists(), "Save writes the run")
			main.state.economy.inv["wood"] = 5
		27:
			main.game_menu.load_game()
		33:
			var again: Node = current_scene
			_expect(again != main and again != null, "Load starts the scene again")
			if again != null and again != main:
				_expect(again.state.economy.inv["wood"] == saved_wood, "and the loaded game has what was saved")
		40:
			return _done()
	return false


func _done() -> bool:
	if FileAccess.file_exists(RunSave.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RunSave.PATH))
	if problems.is_empty():
		print("MENU PASS OK")
		quit(0)
	else:
		for p in problems:
			printerr("MENU PASS FAILED: ", p)
		quit(1)
	return true
