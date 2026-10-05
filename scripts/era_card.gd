extends Control
## The end of the era: a card, centred over a dimmed map view, shown once when The Falling Star is discovered. It is a cliffhanger,
## not the crash: the words are in Data (ERA_END_*), the button puts the card away, and the game goes on. The owner
## pauses while it is up and resumes on `closed`.
## Signal: closed fires when the player puts the card away.

signal closed

const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")

const WIDTH := 460.0


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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(WIDTH, 0)
	card.add_child(v)
	var title := Ui.label(Data.ERA_END_TITLE, 28)
	title.add_theme_color_override("font_color", Ui.HIGHLIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var body := Ui.label(Data.ERA_END_TEXT, 18)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	var note := Ui.label(Data.ERA_END_NOTE, Ui.MIN_TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Ui.TEXT_DIM)
	v.add_child(note)
	var go := Ui.button(Data.ERA_END_BUTTON)
	Ui.action_button(go)
	go.text = Data.ERA_END_BUTTON
	go.add_theme_font_size_override("font_size", 18)
	go.pressed.connect(close)
	v.add_child(go)


## Lay the card over `area` (the map view): the dim covers just the map, the card sits in its middle, and the top bar
## and the side panel stay clear. The owner calls this every frame, with the view.
func place(area: Rect2) -> void:
	position = area.position
	size = area.size


## Put the card up.
func open() -> void:
	visible = true


## Put the card away and say so.
func close() -> void:
	if visible:
		visible = false
		closed.emit()
