extends Control
## A moment of the Starfall era (Data.MOMENTS) or its ending: a card over a dimmed map, with one button per choice. It reads
## what to say from the Starfall block (`pending`, `pending_options`) and gives the player's pick back as `chose(index)`. The
## owner pauses while it is up and resumes on `chose`. Same look as the era card (scripts/era_card.gd).
## Signal: chose(index) fires once when a button is pressed.

signal chose(index: int)

const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")

const WIDTH := 460.0

var _box: VBoxContainer


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
	card.add_theme_stylebox_override("panel", Ui.panel_style(Ui.PANEL, 12))
	centre.add_child(card)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	_box.custom_minimum_size = Vector2(WIDTH, 0)
	card.add_child(_box)


## Lay the card over `area` (the map view), as the era card does.
func place(area: Rect2) -> void:
	position = area.position
	size = area.size


## Put the card up for what the Starfall block `f` is waiting on. Does nothing when nothing waits.
func open(f) -> void:
	if f.pending == "":
		return
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var ending: bool = f.pending == "ending"
	var title := Ui.label(Data.ENDING_TITLE if ending else Data.MOMENTS[f.pending]["title"], 28)
	title.add_theme_color_override("font_color", Ui.HIGHLIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_box.add_child(_wrapped(Data.ENDING_TEXT if ending else Data.MOMENTS[f.pending]["text"], 18, Ui.TEXT))
	if ending:
		_box.add_child(_wrapped(Data.ENDING_NOTE, Ui.MIN_TEXT, Ui.TEXT_DIM))
	var options: Array = f.pending_options()
	for i in options.size():
		_box.add_child(_option(i, options[i]))
	visible = true


func _option(index: int, opt: Dictionary) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var b := Ui.button(opt["label"])
	Ui.action_button(b)
	b.text = opt["label"]
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(_pick.bind(index))
	v.add_child(b)
	if opt["note"] != "":
		v.add_child(_wrapped(opt["note"], Ui.MIN_TEXT, Ui.TEXT_DIM))
	return v


func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var l := Ui.label(text, font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	return l


func _pick(index: int) -> void:
	if visible:
		visible = false
		chose.emit(index)
