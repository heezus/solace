extends Control
## The Chronicle (Step 7G): the book of every telling of Solace, over the dimmed view. Four pages: Tellings (a sky, one constellation per
## ended telling, a star for each choice, with the Embers found; picking one reads its entry, the voices wondering about the road not
## taken, the telling's numbers and a small map of its land), Lore (the four layers, the nine sets of marks and every scene to watch
## again), People (the Hearthkeeper, Sela, the Bloom) and Endings (the three reached or not, the three true endings and what they
## need). What it shows is worked out from the profile (scripts/chronicle.gd); the words are scripts/chronicle_words.gd.
## Opened from the title screen and the pause menu, and between tellings, after the fireside, with a button that begins the next one.
## Every page can play its scenes again: the book keeps its own cutscene player over a stand-in run (nothing is recorded).
## `open(profile, page, after_ending)` puts it up; Esc or Close puts it away. Signal: closed.

signal closed

const Chronicle = preload("res://scripts/chronicle.gd")
const CutscenePlayer = preload("res://scripts/cutscene_player.gd")
const Data = preload("res://scripts/data.gd")
const GlyphMark = preload("res://scripts/glyph_mark.gd")
const MenuFonts = preload("res://scripts/menu_fonts.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")
const Words = preload("res://scripts/chronicle_words.gd")

const ROW_HEIGHT := 112.0  # one constellation's row of the sky
const SKY_WIDTH := 540.0
const DETAIL_WIDTH := 330.0
const MAP_BOX := 150.0
const SKY_COLOR := Color("0d1a22")
const STAR_COLOR := Color("eee7d6")
const EMBER_COLOR := Color("ffd27a")
const CELL_COLORS := {
	"#": Color("dcc08a"),
	"b": Color("b24a9a"),
	"=": Color("8d7b5c"),
	"r": Color("6e665c"),
	"~": Color("3a86c8"),
	"t": Color("3d6b34"),
	"^": Color("7a7a78"),
	".": Color("56784a"),
}

var page := "tellings"
var after_ending := false
var star_buttons: Array = []  # {run, kind, button}: every star of the sky, for a test to press
var watch_buttons: Array = []  # {page, scene, button}: every "Watch" on the pages
var player: CutscenePlayer  # plays the scenes again
var profile  # the Profile being shown
var _pages := {}  # page name -> its Control
var _tabs := {}  # page name -> its tab Button
var _sky: Control
var _detail: VBoxContainer
var _selected := {}  # {run, kind}
var _close: Button
var _sim: Sim


func setup() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP  # the view behind it takes no clicks while it is up
	var dim := ColorRect.new()
	dim.color = Ui.SCRIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Ui.panel_style(Ui.PANEL, 16))
	margin.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var title := Ui.label(Words.TITLE, 30)
	MenuFonts.style_display(title, 30)
	title.add_theme_color_override("font_color", Ui.HIGHLIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := Ui.label(Words.SUBTITLE, Ui.MIN_TEXT)
	MenuFonts.style_caption(sub)
	sub.add_theme_color_override("font_color", Ui.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	for tab_name in Words.TABS:
		var id: String = String(tab_name).to_lower()
		var tab := _button(tab_name, false, show_page.bind(id))
		tabs.add_child(tab)
		_tabs[id] = tab
		var scroll := ScrollContainer.new()
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body.add_child(scroll)
		_pages[id] = scroll
	_close = _button(Words.BACK, true, close)
	_close.name = "Close"
	v.add_child(_close)
	_sim = Sim.new()
	player = CutscenePlayer.new()
	add_child(player)
	player.setup(_sim, null, [])
	player.queue.clear()


func _button(text: String, primary: bool, on_press: Callable) -> Button:
	var b := Ui.button(text)
	Ui.action_button(b, primary)
	b.text = text
	MenuFonts.style_button(b, 17)
	b.custom_minimum_size = Vector2(120, 38)
	b.pressed.connect(on_press)
	return b


## Lay the book over `area` (the map view), as the cards do.
func place(area: Rect2) -> void:
	position = area.position
	size = area.size


## Put the book up showing `new_profile` (a Profile) on `new_page`. `ending` is true between tellings: the sky opens on the telling
## that just ended and the button closes with "Begin the next telling".
func open(new_profile, new_page := "tellings", ending := false) -> void:
	profile = new_profile
	after_ending = ending
	player.prior = profile.chronicle.duplicate()
	_close.text = Words.BEGIN if ending else Words.BACK
	star_buttons.clear()
	watch_buttons.clear()
	_selected = {}
	for id in _pages:
		var scroll: ScrollContainer = _pages[id]
		for c in scroll.get_children():
			scroll.remove_child(c)
			c.queue_free()
		scroll.add_child(call("_build_" + id))
	show_page(new_page)
	visible = true


## Show page `id` ("tellings", "lore", "people" or "endings").
func show_page(id: String) -> void:
	page = id
	for key in _pages:
		_pages[key].visible = key == id
		Ui.action_button(_tabs[key], key == id)


## Put the book away and say so.
func close() -> void:
	if player.active:
		player.skip()
	if visible:
		visible = false
		closed.emit()


func _input(event: InputEvent) -> void:
	if visible and not player.active and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


# --- Tellings ---------------------------------------------------------------


func _build_tellings() -> Control:
	var sky: Array = Chronicle.sky(profile.tellings)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sky.is_empty():
		box.add_child(_wrapped(Words.EMPTY_SKY, Ui.TEXT_DIM, 520.0))
		return box
	_sky = Control.new()
	_sky.custom_minimum_size = Vector2(SKY_WIDTH, ROW_HEIGHT * sky.size() + 20.0)
	_sky.draw.connect(_draw_sky.bind(sky))
	box.add_child(_sky)
	for row in sky.size():
		_add_stars(sky, row)
	_detail = VBoxContainer.new()
	_detail.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	_detail.add_theme_constant_override("separation", 6)
	box.add_child(_detail)
	var last: Dictionary = sky[sky.size() - 1]
	_select(last["run"], "ending")
	return box


## The stars of constellation `row` as buttons over the sky, and the Embers it lit above them.
func _add_stars(sky: Array, row: int) -> void:
	var telling: Dictionary = sky[row]
	for i in telling["stars"].size():
		var star: Dictionary = telling["stars"][i]
		_star(telling["run"], star["kind"], _star_at(row, i, telling["stars"].size()), star["name"], false)
	for i in telling["embers"].size():
		var id: String = telling["embers"][i]
		_star(
			telling["run"],
			"ember_" + id,
			_star_at(row, i, telling["embers"].size()) - Vector2(0, 40),
			Words.EMBERS[id]["name"],
			true
		)


func _star(run: int, kind: String, at: Vector2, tip: String, ember: bool) -> void:
	var b := StarButton.new()
	b.ember = ember
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(32, 32)
	b.size = Vector2(32, 32)
	b.position = at - Vector2(16, 16)
	b.tooltip_text = tip
	b.pressed.connect(_select.bind(run, kind))
	_sky.add_child(b)
	star_buttons.append({"run": run, "kind": kind, "button": b})


## Where star `i` of `n` in constellation `row` sits: along a gentle wave across the sky.
func _star_at(row: int, i: int, n: int) -> Vector2:
	var span := SKY_WIDTH - 110.0
	var x := 70.0 + (span * i / float(maxi(n - 1, 1)) if n > 1 else span * 0.5)
	return Vector2(x, 62.0 + row * ROW_HEIGHT + sin(i * 1.7 + row) * 16.0)


func _draw_sky(sky: Array) -> void:
	_sky.draw_rect(Rect2(Vector2.ZERO, _sky.size), SKY_COLOR)
	var font := ThemeDB.fallback_font
	for dust in 60:
		var p := Vector2(fposmod(dust * 97.0, SKY_WIDTH), fposmod(dust * 53.0, _sky.size.y))
		_sky.draw_circle(p, 1.0, Color(STAR_COLOR, 0.25))
	for row in sky.size():
		var n: int = sky[row]["stars"].size()
		_sky.draw_string(
			font,
			Vector2(14, 22.0 + row * ROW_HEIGHT),
			Words.OPEN_TELLING % sky[row]["run"],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			Ui.MIN_TEXT,
			Ui.TEXT_DIM
		)
		for i in range(1, n):
			_sky.draw_line(_star_at(row, i - 1, n), _star_at(row, i, n), Color(STAR_COLOR, 0.55), 1.5, true)
		var embers: int = sky[row]["embers"].size()
		for i in embers:
			_sky.draw_line(
				_star_at(row, i, embers) - Vector2(0, 40),
				_star_at(row, mini(i, n - 1), n),
				Color(EMBER_COLOR, 0.25),
				1.0,
				true
			)
		if row + 1 < sky.size() and n > 0 and sky[row + 1]["stars"].size() > 0:  # a line of light from this ending to the next telling
			_sky.draw_line(
				_star_at(row, n - 1, n),
				_star_at(row + 1, 0, sky[row + 1]["stars"].size()),
				Color(EMBER_COLOR, 0.45),
				2.0,
				true
			)


## Read star `kind` of telling `run` into the panel beside the sky.
func _select(run: int, kind: String) -> void:
	_selected = {"run": run, "kind": kind}
	for entry in star_buttons:
		entry["button"].lit = entry["run"] == run and entry["kind"] == kind
		entry["button"].queue_redraw()
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var telling := _telling(run)
	if kind.begins_with("ember_"):
		var ember: Dictionary = Words.EMBERS[kind.trim_prefix("ember_")]
		_detail.add_child(_heading(ember["name"]))
		_detail.add_child(_voiced(ember["voice"], ember["text"]))
	else:
		for star in Chronicle.stars_of(telling):
			if star["kind"] != kind:
				continue
			_detail.add_child(_heading("%s: %s" % [star["name"], star["label"]]))
			_detail.add_child(_voiced(star["voice"], star["text"]))
			for whisper in star["whispers"]:
				_detail.add_child(_voiced(whisper["voice"], whisper["text"], true))
			if star["bloom"] != "":
				_detail.add_child(_voiced("bloom", star["bloom"], true))
	var numbers := Chronicle.numbers_line(telling)
	if numbers != "":
		_detail.add_child(_wrapped(numbers, Ui.TEXT_DIM, DETAIL_WIDTH))
	if telling.get("map", {}).has("rows"):
		var map := MiniMap.new()
		map.map = telling["map"]
		map.custom_minimum_size = Vector2(MAP_BOX, MAP_BOX)
		_detail.add_child(map)
	var began := _ending_before(run)
	_detail.add_child(
		_watch("Watch the ending", "fireside", "tellings", began, telling.get("ending", ""), telling.get("lean", ""))
	)
	if run > 1:
		_detail.add_child(_watch("Watch the next land", "next_telling", "tellings", began, "", telling.get("lean", "")))
	_detail.add_child(_wrapped(Words.EMBERS_FOUND % profile.embers.size(), Ui.TEXT_DIM, DETAIL_WIDTH))


func _telling(run: int) -> Dictionary:
	for t in profile.tellings:
		if int(t.get("run", 0)) == run:
			return t
	return {}


## The ending that began telling `run`, "" for the first.
func _ending_before(run: int) -> String:
	var before := _telling(run - 1)
	return String(before.get("ending", ""))


# --- Lore -------------------------------------------------------------------


func _build_lore() -> Control:
	var v := _column()
	v.add_child(_heading("Lore"))
	for layer in Chronicle.layers(profile.chronicle):
		v.add_child(
			_wrapped(
				"%s: %s" % [layer["title"], layer["text"] if layer["open"] else Words.LAYER_LOCKED],
				Ui.TEXT if layer["open"] else Ui.TEXT_DIM,
				880.0
			)
		)
	v.add_child(_heading(Words.DICTIONARY_TITLE))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for gset in Chronicle.dictionary(profile.marks):
		grid.add_child(_set_card(gset))
	v.add_child(_heading(Words.SCENES_TITLE))
	var flow := HFlowContainer.new()
	flow.custom_minimum_size = Vector2(880, 0)
	v.add_child(flow)
	for scene in Chronicle.scenes(profile.chronicle, profile.runs):
		flow.add_child(
			_watch(scene["name"], scene["id"], "lore", _ending_before(profile.runs), _last_ending(), _last_lean())
		)
	return v


func _set_card(gset: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.panel_style(Ui.CARD if gset["read"] else Ui.CARD_LOCKED, 8))
	var v := VBoxContainer.new()
	card.add_child(v)
	v.add_child(Ui.label("%d. %s" % [gset["n"], gset["name"] if gset["read"] else Words.MARK_UNREAD], Ui.MIN_TEXT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for g in gset["glyphs"]:
		var cell := VBoxContainer.new()
		if g["read"]:
			var mark := GlyphMark.new()
			mark.setup(g["id"])
			mark.read = gset["read"]
			cell.add_child(mark)
			cell.add_child(Ui.label(g["word"], Ui.MIN_TEXT))
		else:
			cell.add_child(Ui.label(Words.MARK_UNREAD, 22))
		row.add_child(cell)
	return card


# --- People -----------------------------------------------------------------


func _build_people() -> Control:
	var v := _column()
	for id in ["elder", "sela", "bloom"]:
		var def: Dictionary = Words.PEOPLE[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		v.add_child(row)
		var face := TextureRect.new()
		face.texture = load(CutscenePlayer.PORTRAIT_DIR + def["portrait"] + ".png")
		face.custom_minimum_size = Vector2(120, 150)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(face)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 4)
		row.add_child(text)
		text.add_child(_heading(def["name"]))
		var words: String = def["text_later"] if id == "bloom" and profile.runs >= Words.BLOOM_FROM - 1 else def["text"]
		text.add_child(_wrapped(words, Ui.TEXT, 700.0))
		if id == "sela":
			for t in profile.tellings:
				text.add_child(
					_wrapped(
						(
							Words.SELA_TRUST
							% [int(t.get("run", 0)), t.get("lean", ""), roundi(float(t.get("trust", 0.0)))]
						),
						Ui.TEXT_DIM,
						700.0
					)
				)
		var scene: String = {"elder": "fireside", "sela": "first_contact", "bloom": "bloom_sign"}[id]
		if Chronicle.scenes(profile.chronicle, profile.runs).any(func(s): return s["id"] == scene):
			text.add_child(
				_watch(Words.SCENES[scene], scene, "people", _ending_before(profile.runs), _last_ending(), _last_lean())
			)
	return v


# --- Endings ----------------------------------------------------------------


func _build_endings() -> Control:
	var v := _column()
	v.add_child(_heading(Words.ENDINGS_OPEN))
	for ending in Data.ENDINGS["order"]:
		var def: Dictionary = Data.ENDINGS[ending]
		var n := Chronicle.times_reached(profile.tellings, ending)
		var line := (
			"%s: %s  (%s)"
			% [def["name"], def["line"], Words.NEVER if n == 0 else Words.ENDINGS_TIMES % n + ("s" if n > 1 else "")]
		)
		v.add_child(_wrapped(line, Ui.TEXT if n > 0 else Ui.TEXT_DIM, 880.0))
		if n > 0:
			v.add_child(_watch("Watch the ending", "fireside", "endings", "", ending, ""))
	v.add_child(_heading(Words.ENDINGS_TRUE))
	for true_ending in Words.TRUE_ENDINGS:
		v.add_child(
			_wrapped(
				"%s: %s  Needs: %s" % [true_ending["name"], true_ending["line"], true_ending["needs"]],
				Ui.TEXT_DIM,
				880.0
			)
		)
	return v


# --- Pieces -----------------------------------------------------------------


func _column() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


func _heading(text: String) -> Label:
	var l := Ui.label(text, 20)
	MenuFonts.style_display(l, 20)
	l.add_theme_color_override("font_color", Ui.HIGHLIGHT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(DETAIL_WIDTH - 20.0, 0)
	return l


func _wrapped(text: String, color: Color, width: float) -> Label:
	var l := Ui.label(text, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.add_theme_color_override("font_color", color)
	return l


## A line spoken by `voice`, dimmer and in quotation when it is a whisper or a fragment.
func _voiced(voice: String, text: String, soft := false) -> Label:
	var spoken := '%s: "%s"' % [Chronicle.voice_name(voice), text]
	var color := Ui.TEXT_DIM if soft else Ui.TEXT
	if voice == "bloom":
		color = Color("d98ad0")
	return _wrapped(spoken, color, DETAIL_WIDTH - 20.0)


## A "Watch" button that plays `scene` again: `began` is the ending that began the telling shown, `ended` the one that ended it.
func _watch(text: String, scene: String, on_page: String, began: String, ended: String, lean: String) -> Button:
	var b := _button(text, false, func(): player.play(scene, began, ended, lean))
	b.custom_minimum_size = Vector2(0, 34)
	watch_buttons.append({"page": on_page, "scene": scene, "button": b})
	return b


func _last_ending() -> String:
	return (
		String(profile.tellings[profile.tellings.size() - 1].get("ending", ""))
		if not profile.tellings.is_empty()
		else ""
	)


func _last_lean() -> String:
	return (
		String(profile.tellings[profile.tellings.size() - 1].get("lean", "")) if not profile.tellings.is_empty() else ""
	)


## A star of the sky: a flat button that draws a point of light, brighter when it is the one being read.
class StarButton:
	extends Button
	var lit := false
	var ember := false

	func _draw() -> void:
		var core := Color("ffd27a") if ember else Color("eee7d6")
		var at := size / 2.0
		if lit:
			draw_circle(at, 15.0, Color(core, 0.3))
		draw_circle(at, 9.0, Color(core, 0.16))
		draw_circle(at, 3.0 if ember else 4.5, core)


## A telling's land at its end, one small square a cell (Chronicle.map_of).
class MiniMap:
	extends Control
	var map: Dictionary = {}

	func _draw() -> void:
		var rows: Array = map.get("rows", [])
		if rows.is_empty():
			return
		var cols: int = String(rows[0]).length()
		var cell := minf(size.x / cols, size.y / rows.size())
		draw_rect(Rect2(Vector2.ZERO, Vector2(cols, rows.size()) * cell), Color("0b1618"))
		for y in rows.size():
			for x in cols:
				var mark := String(rows[y])[x]
				draw_rect(Rect2(Vector2(x, y) * cell, Vector2(cell, cell)), CELL_COLORS.get(mark, CELL_COLORS["."]))
