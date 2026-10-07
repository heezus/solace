extends VBoxContainer
## The Glyph Wall's panel: each mark the scribes have copied, where it was found, and the word the player has set on it. A
## click on a mark's word moves it on to the next word in the list. The Kith say nothing until all three marks of a set are
## right (Starfall.check), so a guess costs only time. Plain buttons and labels, so it fits any panel layout.

signal changed

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")
const GlyphMark = preload("res://scripts/glyph_mark.gd")

var state: Sim
var key := ""  # what the rows were built from, so they are built again only when it changes


func setup(game: Sim) -> void:
	state = game
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)


## Show the rows for building b (hidden unless it is a Glyph Wall).
func show_for(b: Dictionary) -> void:
	visible = Data.BUILDINGS[b["type"]]["kind"] == "wall"
	if not visible:
		key = ""
		return
	var f := state.starfall
	var now := (
		"%s|%s|%s|%s|%s" % [f.copied, f.guesses, f.locked, f.guests or f.trust >= Data.CONTEXT_TRUST, f.answered.size()]
	)
	if now == key:
		return
	key = now
	for c in get_children():
		c.queue_free()
		remove_child(c)
	for n in Data.GLYPH_SETS:
		var gset: Dictionary = Data.GLYPH_SETS[n]
		if gset["source"] == "wreck" and f.progress(gset["id"]).x == 0 and not f.locked.has(gset["id"]):
			continue  # a set the Wreck holds shows once its first mark is home
		add_child(_wrapped(header_text(state, gset), Ui.TEXT))
		if f.locked.has(gset["id"]) and Data.LUMEN_GIFTS.has(gset["id"]):
			var gift: Dictionary = Data.LUMEN_GIFTS[gset["id"]]
			add_child(_wrapped(Data.GIFT_LINE % [gift["name"], gift["note"]], Ui.GOOD))
		for g in gset["glyphs"]:
			if f.copied.has(g):
				add_child(_row(g, f.locked.has(gset["id"])))
	var end: Vector2i = f.progress(Data.ENDING_SET)
	if end.x == end.y and not f.locked.has(Data.ENDING_SET) and not f.may_end():
		add_child(_wrapped(Data.WARNING_NEEDS, Ui.TEXT_DIM))
	if f.locked.has("name") and f.wreck_has_more():
		add_child(_wrapped(Data.WALL_WRECK_HINT, Ui.TEXT_DIM))
	add_child(_wrapped(Data.WALL_HINT, Ui.TEXT_DIM))


## "The Name: 2 of 3 marks copied", or "The Name: read".
static func header_text(s: Sim, gset: Dictionary) -> String:
	if s.starfall.locked.has(gset["id"]):
		return Data.WALL_SET_LOCKED % gset["name"]
	var have: Vector2i = s.starfall.progress(gset["id"])
	return Data.WALL_SET_LINE % [gset["name"], have.x, have.y]


## Where the mark was found, in one line.
static func found_text(s: Sim, glyph: String) -> String:
	return Data.WALL_FOUND % ", ".join(s.starfall.found_lines(glyph))


## The word set on the mark ("?" for none yet).
static func guess_text(s: Sim, glyph: String) -> String:
	return s.starfall.guesses.get(glyph, Data.NO_GUESS)


func _wrapped(text: String, color: Color) -> Label:
	var l := Ui.label(text, Ui.MIN_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(60, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", color)
	return l


func _row(glyph: String, read: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	box.add_child(line)
	var mark := GlyphMark.new()
	mark.setup(glyph)
	mark.read = read
	line.add_child(mark)
	var b := Button.new()
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = "Means: %s" % guess_text(state, glyph)
	b.disabled = read
	b.add_theme_font_size_override("font_size", Ui.MIN_TEXT)
	b.add_theme_color_override("font_color", Ui.GOOD if read else Ui.TEXT)
	b.add_theme_color_override("font_hover_color", Ui.HIGHLIGHT)
	b.pressed.connect(
		func():
			if state.starfall.cycle_guess(glyph) != "":
				changed.emit()
	)
	line.add_child(b)
	box.add_child(_wrapped(found_text(state, glyph), Ui.TEXT_DIM))
	return box
