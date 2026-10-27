extends Control
## The card that ends a telling (Step 7): "Choose an ending", three rows over the dimmed map, each with its name, a line of story,
## what it gives and, when the Lumen lean shuts it, why (Data.ENDINGS, scripts/endings.gd). Exodus is always open; the
## Cataclysm needs the Lumen as enemies and the Time loop as allies. "Keep building" puts the card away and changes nothing.
## `open(run, lean)` puts it up for the run's number and lean; the owner (scripts/game_menu.gd) lays it over the map with `place`
## and asks "Leave this land?" for the row that was chosen. Signals: chosen(ending) when an open row is pressed (the card goes);
## kept when the player keeps building.

signal chosen(ending: String)
signal kept

const Data = preload("res://scripts/data.gd")
const Endings = preload("res://scripts/endings.gd")
const MenuFonts = preload("res://scripts/menu_fonts.gd")
const Ui = preload("res://scripts/ui.gd")

const WIDTH := 480.0

var _title: Label
var _text: Label
var _rows := {}  # ending id -> {"button", "line", "gives", "why"}
var _keep: Button


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
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(WIDTH, 0)
	card.add_child(v)
	_title = _words(v, "", 26, Ui.HIGHLIGHT)
	_text = _words(v, Data.ENDINGS["text"], 17, Ui.TEXT)
	for id in Data.ENDINGS["order"]:
		v.add_child(_row(id))
	_keep = Ui.button(Data.ENDINGS["keep"])
	Ui.action_button(_keep, false)
	_keep.text = Data.ENDINGS["keep"]
	_keep.add_theme_font_size_override("font_size", 18)
	_keep.pressed.connect(cancel)
	v.add_child(_keep)


func _words(into: Control, text: String, font: int, color: Color) -> Label:
	var l := Ui.label(text, font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	into.add_child(l)
	return l


## One ending's row: its button (the name), the line of story, what it gives and why it is shut.
func _row(id: String) -> Control:
	var def: Dictionary = Data.ENDINGS[id]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Ui.panel_style(Ui.CARD, 10))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var b := Ui.button(def["name"])
	Ui.action_button(b)
	b.text = def["name"]
	MenuFonts.style_button(b, 20)
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(func(): _pick(id))
	box.add_child(b)
	var line := _words(box, def["line"], 16, Ui.TEXT)
	var gives := _words(box, Data.ENDINGS["gives"] % def["gives"], Ui.MIN_TEXT, Ui.TEXT_DIM)
	var why := _words(box, "", Ui.MIN_TEXT, Ui.SHORT)
	_rows[id] = {"button": b, "line": line, "gives": gives, "why": why}
	return panel


## Lay the card over `area` (the map view), as the other cards do.
func place(area: Rect2) -> void:
	position = area.position
	size = area.size


## Put the card up for telling number `run` and the Lumen lean `lean`: a row the lean shuts is greyed, with its reason.
func open(run: int, lean: String) -> void:
	_title.text = Data.ENDINGS["title_first"] if run <= 1 else Data.ENDINGS["title_later"] % run
	for id in _rows:
		var reason := Endings.why_locked(id, lean)
		var row: Dictionary = _rows[id]
		row["button"].disabled = reason != ""
		row["why"].text = reason
		row["why"].visible = reason != ""
	visible = true


## "Keep building": put the card away and say so.
func cancel() -> void:
	if visible:
		visible = false
		kept.emit()


func _pick(id: String) -> void:
	if not visible or _rows[id]["button"].disabled:
		return
	visible = false
	chosen.emit(id)


## The button of ending `id` (a test presses it).
func button_of(id: String) -> Button:
	return _rows[id]["button"]


## What a row says of why it is shut: "" when it is open.
func why_of(id: String) -> String:
	return _rows[id]["why"].text
