extends Control
## The pause menu: Resume, Save game, Load game and Quit to title, on a card over the dimmed map. The owner (scripts/main.gd)
## pauses while it is up and does the real work; this only shows the buttons and a one-line status ("Game saved.").
## Signals: resumed, save_pressed, load_pressed, quit_pressed.

signal resumed
signal save_pressed
signal load_pressed
signal quit_pressed

const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")
const RunSave = preload("res://scripts/run_save.gd")

const WIDTH := 300.0

var save_path := RunSave.PATH
var load_button: Button
var status: Label


func setup() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP  # the map behind it takes no clicks while it is up
	var dim := ColorRect.new()
	dim.color = Ui.SCRIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.panel_style(Ui.PANEL, 14))
	centre.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(WIDTH, 0)
	card.add_child(v)
	var title := Ui.label(Data.PAUSE_TITLE, 28)
	title.add_theme_color_override("font_color", Ui.HIGHLIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_button(Data.PAUSE_RESUME, true, func(): resume()))
	v.add_child(_button(Data.PAUSE_SAVE, false, func(): save_pressed.emit()))
	load_button = _button(Data.PAUSE_LOAD, false, func(): load_pressed.emit())
	v.add_child(load_button)
	v.add_child(_button(Data.PAUSE_QUIT, false, func(): quit_pressed.emit()))
	status = Ui.label("", Ui.MIN_TEXT)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Ui.GOOD)
	v.add_child(status)
	var hint := Ui.label(Data.PAUSE_HINT, Ui.MIN_TEXT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Ui.TEXT_DIM)
	v.add_child(hint)


func _button(text: String, primary: bool, on_press: Callable) -> Button:
	var b := Ui.button(text)
	Ui.action_button(b, primary)
	b.text = text
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(on_press)
	return b


## Lay the menu over `area` (the map view), as the cards do.
func place(area: Rect2) -> void:
	position = area.position
	size = area.size


## Put the menu up with a clean status line. Load is only offered when a save exists.
func open() -> void:
	status.text = ""
	load_button.disabled = not RunSave.exists(save_path)
	visible = true


## Say something under the buttons (a good line is green, a bad one is not).
func say(text: String, good := true) -> void:
	status.text = text
	status.add_theme_color_override("font_color", Ui.GOOD if good else Ui.BAD)
	load_button.disabled = not RunSave.exists(save_path)


## Put the menu away and say so.
func resume() -> void:
	if visible:
		visible = false
		resumed.emit()
