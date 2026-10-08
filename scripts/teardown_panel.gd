extends VBoxContainer
## The Teardown Bench's panel (scripts/teardown.gd): the part on the Bench and the short queue behind it, then the parts in the
## pack, each a card that names the Lesson it holds (so the player picks what to learn first). A click on a pack part moves it
## to the front, where haulers carry it next; a button carries it by hand. The Lessons list (scripts/lessons_list.gd) sits under
## it. Plain buttons and labels, so it fits any panel layout.

signal changed

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")
const Roads = preload("res://scripts/roads.gd")

var state: Sim
var key := ""  # what the rows were built from, so they are built again only when it changes


func setup(game: Sim) -> void:
	state = game
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)


## Show the rows for building b (hidden unless it is the Teardown Bench).
func show_for(b: Dictionary) -> void:
	visible = Data.BUILDINGS[b["type"]]["kind"] == "bench"
	if not visible:
		key = ""
		return
	var t = state.teardown
	var now := "%s|%s|%s|%s|%s" % [t.pack, t.bench, ceili(t.seconds_left()), t.lessons, Roads.linked(state, b)]
	if now == key:
		return
	key = now
	for c in get_children():
		c.queue_free()
		remove_child(c)
	add_child(Ui.heading(Data.BENCH_HEADING))
	if t.bench.is_empty():
		add_child(_wrapped(Data.BENCH_IDLE, Ui.TEXT_DIM))
	for i in t.bench.size():
		add_child(_card(t.bench[i], Ui.GOOD if i == 0 else Ui.TEXT, i == 0))
	if t.bench.size() < Data.BENCH_SLOTS:
		add_child(_wrapped(Data.BENCH_ROOM % (Data.BENCH_SLOTS - t.bench.size()), Ui.TEXT_DIM))
	else:
		add_child(_wrapped(Data.BENCH_FULL, Ui.TEXT_DIM))
	if not Roads.linked(state, b):
		add_child(_wrapped(Data.BENCH_NEEDS_ROAD, Ui.SHORT))
	add_child(Ui.heading(Data.PACK_HEADING))
	if t.pack.is_empty():
		add_child(_wrapped(Data.PACK_EMPTY, Ui.TEXT_DIM))
	for id in t.pack:
		add_child(_pack_row(id))
	if not t.pack.is_empty():
		add_child(_wrapped(Data.PACK_HINT, Ui.TEXT_DIM))
		var carry := Ui.button(Data.CARRY_BUTTON % Data.PARTS[t.pack[0]]["name"])
		carry.disabled = t.bench.size() >= Data.BENCH_SLOTS
		carry.pressed.connect(_carry.bind(t.pack[0]))
		add_child(carry)


## What a part's card says: its name, the Lesson it holds and what that teaches, or that it is only scrap now.
static func card_text(s: Sim, id: String) -> String:
	var lesson: Dictionary = Data.LESSONS[id]
	if s.teardown.knows(id):
		return Data.PART_CARD_KNOWN % Data.PARTS[id]["name"]
	return Data.PART_CARD % [Data.PARTS[id]["name"], lesson["name"], lesson["teaches"]]


func _carry(id: String) -> void:
	state.teardown.prioritize(id)
	state.teardown.deliver(id)
	changed.emit()


func _pack_row(id: String) -> Control:
	var b := Button.new()
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(60, 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = card_text(state, id)
	b.icon = Ui.swatch_texture(Data.PARTS[id]["color"])
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 18)
	b.add_theme_font_size_override("font_size", Ui.MIN_TEXT)
	b.add_theme_color_override("font_color", Ui.TEXT_DIM if state.teardown.knows(id) else Ui.TEXT)
	b.add_theme_color_override("font_hover_color", Ui.HIGHLIGHT)
	b.tooltip_text = Data.PARTS[id]["name"] + " · from " + Data.PARTS[id]["from"]
	b.pressed.connect(
		func():
			state.teardown.prioritize(id)
			changed.emit()
	)
	return b


func _card(id: String, color: Color, working: bool) -> Control:
	var text := card_text(state, id)
	if working:
		var line: String = Data.BENCH_STRIPPING if state.teardown.scrapping() else Data.BENCH_WORKING
		text = line % [Data.PARTS[id]["name"], ceili(state.teardown.seconds_left())] + "\n" + text
	return _wrapped(text, color)


func _wrapped(text: String, color: Color) -> Label:
	var l := Ui.label(text, Ui.MIN_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(60, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", color)
	return l
