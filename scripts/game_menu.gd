extends Control
## The game's menu: the pause menu card and what its buttons do. Resume puts it away; Save game opens the slot screen to
## pick a slot and writes the run there; Load game opens it to pick a save (or a stage start, which begins a new run) and
## starts the game scene again from it, so nothing of this run is left behind; Quit to title goes back to the first screen.
## The owner (scripts/main.gd) pauses while it is open and resumes when it closes, through `paused_changed`.
## Signal: paused_changed(on) fires when the menu opens (true) or closes (false).

signal paused_changed(on: bool)

const Data = preload("res://scripts/data.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const SlotScreen = preload("res://scripts/slot_screen.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const Launch = preload("res://scripts/launch.gd")

const TITLE_SCENE := "res://scenes/title.tscn"

var state  # the Sim being played
var slot_dir := SaveSlots.DIR
var menu: PauseMenu
var slots: SlotScreen


func setup(game) -> void:
	state = game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu = PauseMenu.new()
	add_child(menu)
	menu.setup()
	slots = SlotScreen.new()
	slots.dir = slot_dir
	add_child(slots)
	slots.setup()
	menu.resumed.connect(func(): paused_changed.emit(false))
	menu.save_pressed.connect(func(): slots.open("save"))
	menu.load_pressed.connect(func(): slots.open("load"))
	menu.quit_pressed.connect(quit_to_title)
	slots.slot_picked.connect(_on_slot)
	slots.start_picked.connect(start_stage)


## Lay the menu over `area` (the map view), as the cards do.
func place(area: Rect2) -> void:
	menu.place(area)
	slots.place(area)


func is_open() -> bool:
	return menu.visible


## Put the menu up and pause the game behind it.
func open() -> void:
	menu.open()
	paused_changed.emit(true)


## Esc: put the slot screen away if it is up, else the menu and let the game go on.
func close() -> void:
	if slots.visible:
		slots.close()
	else:
		menu.resume()


func _on_slot(slot: int) -> void:
	if slots.mode == "save":
		save_game(slot)
		slots.close()
	else:
		load_game(slot)


## Save game: the whole run into slot `slot`.
func save_game(slot: int) -> bool:
	var ok := SaveSlots.save(state, slot, slot_dir)
	menu.say(Data.SAVE_SLOT_DONE % slot if ok else Data.SAVE_FAILED, ok)
	return ok


## Load game: start the game scene again from slot `slot`. False, with a word on the menu, when it holds nothing.
func load_game(slot: int) -> bool:
	if SaveSlots.read(slot, slot_dir).is_empty():
		menu.say(Data.LOAD_BAD_SLOT, false)
		slots.close()
		return false
	Launch.ask_to_load(slot)
	get_tree().reload_current_scene()
	return true


## Begin a new run from a stage start (`dump`, built by the slot screen): the game scene starts again from it.
func start_stage(dump: Dictionary) -> void:
	Launch.ask_stage(dump)
	get_tree().reload_current_scene()


## Quit to title: anything not saved is lost, as the menu says.
func quit_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
