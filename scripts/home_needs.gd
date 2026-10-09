extends VBoxContainer
## The needs of the selected home, in its card (scripts/building_panel.gd): the state in a line, then one line per need
## (food kinds, each good) in green while met and red while short, what it houses and what the next tier costs. Hidden for
## anything that is not a home. The words and numbers are in scripts/home_text.gd.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")
const HomeText = preload("res://scripts/home_text.gd")
const Homes = preload("res://scripts/homes.gd")

var state: Sim
var state_label: Label
var need_box: VBoxContainer
var housing_label: Label
var next_label: Label


func setup(game: Sim) -> void:
	state = game
	visible = false
	add_theme_constant_override("separation", 3)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_label = _wrapped(Ui.TEXT)
	add_child(state_label)
	need_box = VBoxContainer.new()
	need_box.add_theme_constant_override("separation", 1)
	add_child(need_box)
	housing_label = _wrapped(Ui.TEXT_DIM)
	add_child(housing_label)
	next_label = _wrapped(Ui.TEXT_DIM)
	add_child(next_label)


func _wrapped(color: Color) -> Label:
	var l := Ui.label("", Ui.MIN_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(60, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", color)
	return l


## Show the needs of building b (hidden unless it is a home).
func show_for(b: Dictionary) -> void:
	visible = Homes.is_home(b)
	if not visible:
		return
	state_label.text = HomeText.state_line(state, b)
	var st := Homes.status(state, b)
	state_label.add_theme_color_override("font_color", Ui.GOOD if st["met"] else Ui.SHORT)
	var lines := HomeText.need_lines(state, b)
	while need_box.get_child_count() < lines.size():
		need_box.add_child(_wrapped(Ui.TEXT))
	for i in need_box.get_child_count():
		var l: Label = need_box.get_child(i)
		l.visible = i < lines.size()
		if i < lines.size():
			l.text = ("OK  " if lines[i]["ok"] else "Short  ") + lines[i]["text"]
			l.add_theme_color_override("font_color", Ui.GOOD if lines[i]["ok"] else Ui.SHORT)
	housing_label.text = HomeText.housing_line(b)
	next_label.text = HomeText.next_line(b)
	next_label.visible = next_label.text != ""
