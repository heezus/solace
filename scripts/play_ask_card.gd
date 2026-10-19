extends Control
## The three questions after an era (Data.ASK_QUESTIONS): a card over the dimmed map with a row of buttons for each question and
## Done or Skip. Nothing is typed. The owner pauses the game while it is up. Signal: answered(answers) fires once, with the chosen
## option's text by question id ("" for a question left alone; an empty dictionary for Skip).

signal answered(answers: Dictionary)

const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")

const WIDTH := 480.0

var _box: VBoxContainer
var _rows := {}  # question id -> its option buttons
var _picked := {}  # question id -> the option text chosen


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
	_box.add_theme_constant_override("separation", 12)
	_box.custom_minimum_size = Vector2(WIDTH, 0)
	card.add_child(_box)
	var title := Ui.label(Data.ASK_TITLE, 26)
	title.add_theme_color_override("font_color", Ui.HIGHLIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	for q in Data.ASK_QUESTIONS:
		var words := Ui.label(q["text"], 18)
		words.add_theme_color_override("font_color", Ui.TEXT)
		_box.add_child(words)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		_box.add_child(row)
		_rows[q["id"]] = []
		for option in q["options"]:
			var b := Ui.button(option)
			Ui.action_button(b, false)
			b.text = option
			b.add_theme_font_size_override("font_size", 16)
			b.toggle_mode = true
			b.pressed.connect(_choose.bind(q["id"], option))
			row.add_child(b)
			_rows[q["id"]].append(b)
	var ends := HBoxContainer.new()
	ends.alignment = BoxContainer.ALIGNMENT_END
	ends.add_theme_constant_override("separation", 10)
	_box.add_child(ends)
	var skip := Ui.button(Data.ASK_SKIP)
	Ui.action_button(skip, false)
	skip.text = Data.ASK_SKIP
	skip.pressed.connect(_finish.bind({}))
	ends.add_child(skip)
	var done := Ui.button(Data.ASK_DONE)
	Ui.action_button(done)
	done.text = Data.ASK_DONE
	done.pressed.connect(func(): _finish(_answers()))
	ends.add_child(done)


## Lay the card over `area` (the map view), as the other cards do.
func place(area: Rect2) -> void:
	position = area.position
	size = area.size


## Put the card up with nothing chosen.
func open() -> void:
	_picked = {}
	for id in _rows:
		for b in _rows[id]:
			b.set_pressed_no_signal(false)
	visible = true


## One option for a question: the others in its row let go.
func _choose(id: String, option: String) -> void:
	_picked[id] = option
	for b in _rows[id]:
		b.set_pressed_no_signal(b.text == option)


## Every question's answer, "" where none was chosen.
func _answers() -> Dictionary:
	var out := {}
	for q in Data.ASK_QUESTIONS:
		out[q["id"]] = _picked.get(q["id"], "")
	return out


func _finish(answers: Dictionary) -> void:
	if not visible:
		return
	visible = false
	answered.emit(answers)
