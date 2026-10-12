extends Control
## The end of an era: a card, centred over a dimmed map view, shown once when The Falling Star is discovered (a cliffhanger,
## not the crash: the words are in Data, ERA_END_*) and once more when Livewire is (the end of Ironfall, Data.LIVEWIRE_*). The
## button puts the card away, and the game goes on. The owner pauses while it is up and resumes on `closed`.
## Signal: closed fires when the player puts the card away.

signal closed

const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")

const WIDTH := 460.0

var _words := {}  # the labels and the button, filled by setup and put in words by open


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
	_words["title"] = title
	title.add_theme_color_override("font_color", Ui.HIGHLIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var body := Ui.label(Data.ERA_END_TEXT, 18)
	_words["text"] = body
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	var note := Ui.label(Data.ERA_END_NOTE, Ui.MIN_TEXT)
	_words["note"] = note
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Ui.TEXT_DIM)
	v.add_child(note)
	var go := Ui.button(Data.ERA_END_BUTTON)
	Ui.action_button(go)
	go.text = Data.ERA_END_BUTTON
	_words["button"] = go
	go.add_theme_font_size_override("font_size", 18)
	go.pressed.connect(close)
	v.add_child(go)


## Lay the card over `area` (the map view): the dim covers just the map, the card sits in its middle, and the top bar
## and the side panel stay clear. The owner calls this every frame, with the view.
func place(area: Rect2) -> void:
	position = area.position
	size = area.size


## Put the card up: the Falling Star's, or (with the story id Data.LIVEWIRE_EVENT) the end of Ironfall's.
func open(story_id := "star_falling") -> void:
	var live: bool = story_id == Data.LIVEWIRE_EVENT
	_words["title"].text = Data.LIVEWIRE_TITLE if live else Data.ERA_END_TITLE
	_words["text"].text = Data.LIVEWIRE_TEXT if live else Data.ERA_END_TEXT
	_words["note"].text = Data.LIVEWIRE_NOTE if live else Data.ERA_END_NOTE
	_words["button"].text = Data.LIVEWIRE_BUTTON if live else Data.ERA_END_BUTTON
	visible = true


## Put the card away and say so.
func close() -> void:
	if visible:
		visible = false
		closed.emit()
