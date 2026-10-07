extends Control
## The game's menu: the pause menu card and what its buttons do. Resume puts it away, Save writes the run save, Load starts
## the game scene again from it (so nothing of this run is left behind), Quit to title goes back to the first screen. The
## owner (scripts/main.gd) pauses while it is open and resumes when it closes, through `paused_changed`.
## Signal: paused_changed(on) fires when the menu opens (true) or closes (false).

signal paused_changed(on: bool)

const Data = preload("res://scripts/data.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const Launch = preload("res://scripts/launch.gd")
const RunSave = preload("res://scripts/run_save.gd")

const TITLE_SCENE := "res://scenes/title.tscn"

var state  # the Sim being played
var save_path := RunSave.PATH
var menu: PauseMenu


func setup(game) -> void:
	state = game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu = PauseMenu.new()
	menu.save_path = save_path
	add_child(menu)
	menu.setup()
	menu.resumed.connect(func(): paused_changed.emit(false))
	menu.save_pressed.connect(save_game)
	menu.load_pressed.connect(load_game)
	menu.quit_pressed.connect(quit_to_title)


## Lay the menu over `area` (the map view), as the cards do.
func place(area: Rect2) -> void:
	menu.place(area)


func is_open() -> bool:
	return menu.visible


## Put the menu up and pause the game behind it.
func open() -> void:
	menu.open()
	paused_changed.emit(true)


## Put the menu away and let the game go on.
func close() -> void:
	menu.resume()


## Save game: the whole run into the one save file.
func save_game() -> bool:
	var ok := RunSave.save(state, save_path)
	menu.say(Data.SAVE_DONE if ok else Data.SAVE_FAILED, ok)
	return ok


## Load game: start the game scene again from the save. False, with a word on the menu, when there is none.
func load_game() -> bool:
	if not RunSave.exists(save_path):
		menu.say(Data.LOAD_NONE, false)
		return false
	Launch.ask_to_load()
	get_tree().reload_current_scene()
	return true


## Quit to title: anything not saved is lost, as the menu says.
func quit_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
