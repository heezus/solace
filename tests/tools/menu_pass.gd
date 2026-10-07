extends SceneTree
## The game scene as a player drives it: the title screen's Load screen (its saves and stage starts), New game, then the camera
## (wheel, trackpad scroll and the + and -
## keys), Esc for the pause menu, Save into a slot, Load from it (which starts the scene again from the save), and a stage start
## from the pause menu's Load screen (a new run on the fixed map, built while the screen says so). It fails the run on any
## wrong step. The player's own saves are moved aside while it runs and put back at the end.
## Run in CI under xvfb: godot --rendering-driver opengl3 --path . -s tests/tools/menu_pass.gd

const Data = preload("res://scripts/data.gd")
const RunSave = preload("res://scripts/run_save.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const CutscenePlayer = preload("res://scripts/cutscene_player.gd")

const ASIDE := ".menu_pass_aside"

var frame := 0
var problems: Array = []
var title: Node
var main: Node
var saved_wood := 0
var before := 0
var again: Node
var stage_wait := -1  # the frame the stage start was asked for, -1 before


func _init() -> void:
	CutscenePlayer.suppress = true  # the scripted pass plays the game, not its cutscenes
	_move_saves(true)  # a clean slate
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title


## The save files the game keeps (the old single save and every slot): moved aside (`away`) or put back.
func _move_saves(away: bool) -> void:
	var paths := [RunSave.PATH]
	for slot in range(1, SaveSlots.COUNT + 1):
		paths.append(SaveSlots.path(slot))
	for p in paths:
		var from: String = p if away else p + ASIDE
		var to: String = p + ASIDE if away else p
		DirAccess.remove_absolute(ProjectSettings.globalize_path(to))  # whatever was there: an old aside, or the test's own
		if FileAccess.file_exists(from):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))


## The button under `node` named `name` or with the text `text`.
func _button(node: Node, name: String, text := "") -> Button:
	for c in node.find_children("*", "Button", true, false):
		if c.name == name or (text != "" and c.text == text):
			return c
	return null


func _press(node: Node, name: String, text := "") -> void:
	var b := _button(node, name, text)
	_expect(b != null, "there is a button %s%s" % [name, text])
	if b != null:
		b.pressed.emit()


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
			_press(title, "", Data.TITLE_LOAD)
		7:
			_expect(title.slots.visible and title.slots.mode == "load", "the title's Load game opens the Load screen")
			_expect(_button(title.slots, "Start_stone_age") != null, "it lists the stage starts")
			_expect(_button(title.slots, "Slot_1") == null, "and no saves yet")
			_press(title.slots, "Back")
		9:
			_expect(not title.slots.visible, "Back puts the Load screen away")
			title.start()
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
			_press(main.game_menu.menu, "", Data.PAUSE_SAVE)
		26:
			_expect(main.game_menu.slots.visible and main.game_menu.slots.mode == "save", "Save game opens the slots")
			_press(main.game_menu.slots, "Slot_2")
		27:
			_expect(not SaveSlots.read(2).is_empty(), "picking a slot writes the run there")
			_expect(SaveSlots.read(1).is_empty(), "and only there")
			_expect(not main.game_menu.slots.visible and main.game_menu.is_open(), "the slots go away, the menu stays")
			main.state.economy.inv["wood"] = 5
			_press(main.game_menu.menu, "", Data.PAUSE_LOAD)
		28:
			_expect(
				main.game_menu.slots.visible and main.game_menu.slots.mode == "load", "Load game opens the Load screen"
			)
			_expect(_button(main.game_menu.slots, "Slot_2") != null, "it lists the saved slot")
			_press(main.game_menu.slots, "Slot_2")
		34:
			again = current_scene
			_expect(again != main and again != null, "Load starts the scene again")
			if again != null and again != main:
				_expect(again.state.economy.inv["wood"] == saved_wood, "and the loaded game has what was saved")
				again.era_card.close()
				again.game_menu.open()
				_press(again.game_menu.menu, "", Data.PAUSE_LOAD)
		36:
			_press(again.game_menu.slots, "Start_stone_age")
			stage_wait = frame
	if stage_wait > 0 and frame > stage_wait and current_scene != again:
		var fresh: Node = current_scene
		_expect(fresh != null and fresh.has_method("_zoom"), "a stage start starts the game scene again")
		if fresh != null and fresh.has_method("_zoom"):
			_expect(fresh.state.town.buildings.size() == 1, "on the fresh fixed map")
			_expect(fresh.state.economy.inv["wood"] != saved_wood, "not the loaded run")
			_expect(not SaveSlots.read(2).is_empty() and SaveSlots.read(1).is_empty(), "and the saves are as they were")
		return _done()
	if stage_wait > 0 and frame > stage_wait + 600:
		_expect(false, "the stage start did not finish")
		return _done()
	return false


func _done() -> bool:
	_move_saves(false)  # the player's saves, back (and the test's gone)
	if problems.is_empty():
		print("MENU PASS OK")
		quit(0)
	else:
		for p in problems:
			printerr("MENU PASS FAILED: ", p)
		quit(1)
	return true
