extends Control
## A plain card over a dimmed map: a title, some words and one button per choice. The owner pauses while it is up and resumes
## on `chose`. Same look as the moment card (scripts/moment_card.gd), which reads its words from the Starfall block; this one is
## told them, for the first famine (design-system/24-balance.md) and the seasons to come.
## Signal: chose(index) fires once when a button is pressed.

signal chose(index: int)

const Data = preload("res://scripts/data.gd")
const TopBar = preload("res://scripts/top_bar.gd")
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


## Lay the card over `area` (the map view), as the other cards do.
func place(area: Rect2) -> void:
	position = area.position
	size = area.size


## Put the card up with `title`, `text` and a button for each of `labels`.
func open(title: String, text: String, labels: Array) -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var head := Ui.label(title, 28)
	head.add_theme_color_override("font_color", Ui.HIGHLIGHT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(head)
	var body := Ui.label(text, 18)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_color_override("font_color", Ui.TEXT)
	_box.add_child(body)
	for i in labels.size():
		var b := Ui.button(labels[i])
		Ui.action_button(b)
		b.text = labels[i]
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_pick.bind(i))
		_box.add_child(b)
	visible = true


## The run's first famine: how long the food lasts, and a button to look at the Hearth (index 0) or carry on (index 1).
func open_famine(eco) -> void:
	var left := minf(eco.seconds_of_food(), 3600.0)
	var words: String = Data.FAMINE_TEXT % [TopBar.duration_text(left), Data.PEOPLE["many"]]
	open(Data.FAMINE_TITLE, words, [Data.FAMINE_LOOK, Data.FAMINE_CARRY_ON])


func _pick(index: int) -> void:
	if visible:
		visible = false
		chose.emit(index)
