extends Control
## A small question on a card over the dimmed map: some words and two buttons, "yes" and "no". Used where a choice cannot be taken
## back (Set out, Forget past runs). `ask` puts it up with the words and what "yes" does; "no" (or Esc, through `cancel`) puts it
## away and changes nothing. The owner (scripts/game_menu.gd) lays it over the map with `place`.

const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")
const MenuFonts = preload("res://scripts/menu_fonts.gd")

const WIDTH := 400.0

var _on_yes := Callable()
var _on_no := Callable()
var _text: Label
var _yes: Button
var _no: Button


func setup() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP  # the map and the cards behind it take no clicks while it is up
	var dim := ColorRect.new()
	dim.color = Ui.SCRIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.panel_style(Ui.PANEL, 12))
	centre.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(WIDTH, 0)
	card.add_child(v)
	_text = Ui.label("", 18)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_yes = _button(row, true)
	_yes.pressed.connect(_yes_pressed)
	_no = _button(row, false)
	_no.pressed.connect(cancel)


func _button(row: HBoxContainer, primary: bool) -> Button:
	var b := Ui.button("")
	Ui.action_button(b, primary)
	MenuFonts.style_button(b, 19)
	b.custom_minimum_size = Vector2(0, 42)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	return b


## Lay the card over `area` (the map view), as the other cards do.
func place(area: Rect2) -> void:
	position = area.position
	size = area.size


## Put the question up: `text`, a "yes" button saying `yes_text` that runs `on_yes`, and a "no" button saying `no_text`
## (which runs `on_no`).
func ask(text: String, yes_text: String, no_text: String, on_yes: Callable, on_no := Callable()) -> void:
	_text.text = text
	_yes.text = yes_text
	_no.text = no_text
	_on_yes = on_yes
	_on_no = on_no
	visible = true


## "No": put the question away, and nothing else happens (but what `ask` was given to run on "no").
func cancel() -> void:
	var action := _on_no
	visible = false
	_on_yes = Callable()
	_on_no = Callable()
	if action.is_valid():
		action.call()


func _yes_pressed() -> void:
	var action := _on_yes
	visible = false
	_on_yes = Callable()
	_on_no = Callable()
	if action.is_valid():
		action.call()
