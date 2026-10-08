extends VBoxContainer
## The Lessons list (design-system/19-ironfall.md): the eight Lessons of the era, each locked (no part yet), found (a part is in the
## pack or on the Bench) or learned (what it gave), with a swatch of its part until Codex paints the icons. It sits in the Teardown
## Bench's panel and beside the Glyph Wall's marks, once Teardown is learned. Plain labels, so it fits any panel layout.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")

var state: Sim
var key := ""  # what the rows were built from, so they are built again only when it changes


func setup(game: Sim) -> void:
	state = game
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)


## Show the list for building b: under a Glyph Wall or a Teardown Bench, once Teardown is learned.
func show_for(b: Dictionary) -> void:
	var kind: String = Data.BUILDINGS[b["type"]]["kind"]
	visible = kind in ["wall", "bench"] and state.tech_tree.researched.has("teardown")
	if not visible:
		key = ""
		return
	var now := "%s|%s|%s" % [state.teardown.lessons, state.teardown.pack, state.teardown.bench]
	if now == key:
		return
	key = now
	for c in get_children():
		c.queue_free()
		remove_child(c)
	add_child(Ui.heading(Data.LESSONS_HEADING))
	for id in Data.LESSON_ORDER:
		add_child(_row(id))
	add_child(_wrapped(Data.LESSON_HINT, Ui.TEXT_DIM))


## What a Lesson's state line says: where its part comes from, that it is on its way, or what it gave.
static func state_text(s: Sim, id: String) -> String:
	var lesson: Dictionary = Data.LESSONS[id]
	match s.teardown.lesson_state(id):
		"learned":
			return lesson["note"] if lesson["live"] else Data.LESSON_WAITS % lesson["teaches"]
		"found":
			return Data.LESSON_FOUND % Data.PARTS[id]["name"]
	return Data.LESSON_LOCKED % Data.PARTS[id]["from"]


## The colour a state is shown in.
static func state_color(s: Sim, id: String) -> Color:
	match s.teardown.lesson_state(id):
		"learned":
			return Ui.GOOD
		"found":
			return Ui.HIGHLIGHT
	return Ui.TEXT_DIM


func _row(id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pic := TextureRect.new()
	pic.texture = Ui.swatch_texture(Data.PARTS[id]["color"])
	pic.custom_minimum_size = Vector2(18, 18)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pic.modulate = Color.WHITE if state.teardown.lesson_state(id) != "locked" else Color(1, 1, 1, 0.35)
	pic.tooltip_text = Data.PARTS[id]["name"]
	pic.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(pic)
	var lesson: Dictionary = Data.LESSONS[id]
	var text := "%s: %s\n%s" % [lesson["name"], lesson["teaches"], state_text(state, id)]
	row.add_child(_wrapped(text, state_color(state, id)))
	return row


func _wrapped(text: String, color: Color) -> Label:
	var l := Ui.label(text, Ui.MIN_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(60, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", color)
	return l
