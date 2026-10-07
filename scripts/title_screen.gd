extends Control
## The title screen: the first thing the game shows. A backdrop (painted art when `art/rendered/title.png` exists, else a
## stand-in drawn here: a dusk over misty highland with a Kith fire, a falling star and a faint glow in the east), the name,
## and the buttons: Continue (the newest save, when there is one), New game, Load game (the Load screen: every save slot and
## the stage starts) and Quit. It starts the game scene and says, through `Launch`, what to start from. The hint of other
## peoples is in the art, not the words.
## The art slot and what it should show: docs/art/starfall-art-brief.md.

const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")
const Art = preload("res://scripts/art.gd")
const MenuFonts = preload("res://scripts/menu_fonts.gd")
const Launch = preload("res://scripts/launch.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const SlotScreen = preload("res://scripts/slot_screen.gd")

const GAME_SCENE := "res://scenes/main.tscn"
const ART_PATH := "res://art/rendered/title.png"
const ALT_ART_PATH := "res://art/rendered/title_alt.png"  # an alternate painting: the lead stranger
const BUTTON_WIDTH := 300.0
const TITLE_SIZE := 136  # the name, in the display face: about 570 px wide, inside the dark of the left band
const BUTTON_SIZE := 21
const MENU_LEFT := 80.0  # where the menu column starts
const BAND_SOLID := 440.0  # the left band stays this dark (alpha BAND_ALPHA) for the menu to read over the art...
const BAND_FADE := 520.0  # ...then fades to nothing over this many more pixels
const BAND_ALPHA := 0.8
const BAND_STEPS := 40

var slot_dir := SaveSlots.DIR
var time := 0.0
var slots: SlotScreen
var _art: Texture2D
var _stars: Array = []  # [x share, y share, twinkle offset], fixed
var _continue: Button
var _new_game: Button
var _load: Button
var _quit: Button


## Which painting to show: one of the `found` paths, picked by `roll` (0 up to 1), or "" when there is none. With both
## paintings on disk each is as likely as the other; with one, that one.
static func art_choice(found: Array, roll: float) -> String:
	if found.is_empty():
		return ""
	return found[clampi(int(roll * found.size()), 0, found.size() - 1)]


func _ready() -> void:
	Ui.apply_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var found := [ART_PATH, ALT_ART_PATH].filter(func(path): return ResourceLoader.exists(path))
	var chosen := art_choice(found, randf())
	if chosen != "":
		_art = load(chosen)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		_stars.append([rng.randf(), rng.randf() * 0.55, rng.randf() * TAU])
	_build_menu()


func _build_menu() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size = Vector2(BUTTON_WIDTH, 0)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	column.offset_left = MENU_LEFT
	column.offset_right = MENU_LEFT + BUTTON_WIDTH
	column.offset_top = -240.0
	add_child(column)
	var title := Ui.label(Data.TITLE_NAME, TITLE_SIZE)
	MenuFonts.style_display(title, TITLE_SIZE)
	title.add_theme_color_override("font_color", Ui.HIGHLIGHT)
	title.add_theme_color_override("font_outline_color", Ui.LINE)
	title.add_theme_constant_override("outline_size", 8)
	column.add_child(title)
	column.add_child(_caption(Data.TITLE_TAGLINE))
	column.add_child(_spacer(14.0))
	var latest := SaveSlots.latest(slot_dir)
	var has_save := latest > 0
	_continue = _button(Data.TITLE_CONTINUE if has_save else Data.TITLE_NO_SAVE, has_save)
	_continue.disabled = not has_save
	_continue.pressed.connect(func(): start(latest))
	column.add_child(_continue)
	_new_game = _button(Data.TITLE_NEW, not has_save)
	_new_game.pressed.connect(start.bind(0))
	column.add_child(_new_game)
	_load = _button(Data.TITLE_LOAD, false)
	_load.pressed.connect(func(): slots.open("load"))
	column.add_child(_load)
	if not OS.has_feature("web"):
		_quit = _button(Data.TITLE_QUIT, false)
		_quit.pressed.connect(func(): get_tree().quit())
		column.add_child(_quit)
	slots = SlotScreen.new()
	slots.dir = slot_dir
	add_child(slots)
	slots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slots.setup()
	slots.slot_picked.connect(start)
	slots.start_picked.connect(start_stage)


func _button(text: String, primary: bool) -> Button:
	var b := Ui.button(text)
	Ui.action_button(b, primary)
	b.text = text
	MenuFonts.style_button(b, BUTTON_SIZE)
	b.custom_minimum_size = Vector2(BUTTON_WIDTH, 48)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # the name above is wider than the buttons
	return b


func _caption(text: String) -> Label:
	var l := Ui.label(text, Ui.LABEL_TEXT)
	MenuFonts.style_caption(l)
	l.add_theme_color_override("font_color", Ui.TEXT)
	l.add_theme_color_override("font_outline_color", Ui.LINE)
	l.add_theme_constant_override("outline_size", 4)
	return l


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


## Start the game: from save slot `slot`, or on a new map for 0.
func start(slot := 0) -> void:
	if slot > 0:
		Launch.ask_to_load(slot)
	get_tree().change_scene_to_file(GAME_SCENE)


## Start a new run from a stage start (`dump`, built by the Load screen).
func start_stage(dump: Dictionary) -> void:
	Launch.ask_stage(dump)
	get_tree().change_scene_to_file(GAME_SCENE)


func _process(delta: float) -> void:
	time += delta
	if _art == null:
		queue_redraw()  # the stand-in's stars twinkle


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	if _art != null:
		_draw_cover(_art, area)
	else:
		_draw_standin(area)
	_draw_band(area)


## A dark band down the left, under the menu, that fades out smoothly to the right with no edge: dark for BAND_SOLID px, then
## eased to clear over BAND_FADE.
func _draw_band(area: Rect2) -> void:
	var end := BAND_SOLID + BAND_FADE
	for i in BAND_STEPS:
		var x0 := end * i / BAND_STEPS
		var x1 := end * (i + 1) / BAND_STEPS
		var a0 := BAND_ALPHA * (1.0 - smoothstep(BAND_SOLID * 0.5, end, x0))
		var a1 := BAND_ALPHA * (1.0 - smoothstep(BAND_SOLID * 0.5, end, x1))
		var pts := PackedVector2Array(
			[Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, area.size.y), Vector2(x0, area.size.y)]
		)
		var cols := PackedColorArray([Color(Ui.LINE, a0), Color(Ui.LINE, a1), Color(Ui.LINE, a1), Color(Ui.LINE, a0)])
		draw_polygon(pts, cols)


## `tex` scaled to cover `area`, centred, with nothing left uncovered.
func _draw_cover(tex: Texture2D, area: Rect2) -> void:
	var k := maxf(area.size.x / tex.get_width(), area.size.y / tex.get_height())
	var s := Vector2(tex.get_width(), tex.get_height()) * k
	draw_texture_rect(tex, Rect2(area.position + (area.size - s) / 2.0, s), false)


## The stand-in backdrop until Codex paints the real one.
func _draw_standin(area: Rect2) -> void:
	var w := area.size.x
	var h := area.size.y
	var bands := 24
	for i in bands:
		var f := float(i) / (bands - 1)
		var col := Color("0f2029").lerp(Color("2f4d52"), minf(f * 1.4, 1.0)).lerp(
			Color("7a634e"), maxf(f - 0.65, 0.0) * 2.2
		)
		draw_rect(Rect2(0, h * f * 0.78, w, h * 0.78 / bands + 2.0), col)
	for st in _stars:
		var a := 0.45 + 0.4 * sin(time * 1.3 + st[2])
		draw_circle(Vector2(st[0] * w, st[1] * h), 1.4, Color(0.93, 0.95, 0.9, a))
	# The Lumen: a falling star with a cyan tail, upper right.
	var head := Vector2(w * 0.74, h * 0.2)
	for i in 14:
		var f := float(i) / 13.0
		var p := head - Vector2(1.0, -0.55) * 160.0 * f
		draw_circle(p, lerpf(5.0, 1.0, f), Color(0.62, 0.85, 0.9, lerpf(0.9, 0.0, f)))
	draw_circle(head, 18.0, Color(0.62, 0.85, 0.9, 0.18))
	# The Bloom: a faint magenta and green glow low on the eastern horizon, with thin reaching growth.
	var east := Vector2(w * 0.93, h * 0.7)
	draw_circle(east, 110.0, Color(0.75, 0.29, 0.62, 0.10 + 0.03 * sin(time * 0.8)))
	for i in 5:
		var a := -PI * 0.5 + (i - 2) * 0.35
		var tip := east + Vector2.from_angle(a) * (70.0 + 12.0 * sin(time + i))
		draw_line(east, tip, Color(0.43, 0.66, 0.29, 0.5), 3.0)
		draw_circle(tip, 4.0, Color(0.75, 0.29, 0.62, 0.6))
	# Misty hills, far to near.
	for layer in 3:
		var base := h * (0.68 + 0.08 * layer)
		var pts := PackedVector2Array([Vector2(0, h)])
		for x in range(0, int(w) + 40, 40):
			pts.append(Vector2(x, base - 40.0 * sin(x * 0.004 + layer * 1.7) - 18.0 * sin(x * 0.011 + layer)))
		pts.append(Vector2(w, h))
		draw_colored_polygon(pts, Color("1e3a3d").lerp(Color("0b1618"), layer / 2.0))
	# The Kith: a hearth fire with its glow, lower left of the middle.
	var fire := Vector2(w * 0.52, h * 0.86)
	draw_circle(fire, 70.0, Color(1.0, 0.6, 0.25, 0.12))
	draw_circle(fire, 34.0, Color(1.0, 0.6, 0.25, 0.18))
	var flick := 0.5 + 0.5 * sin(time * 6.0)
	draw_colored_polygon(
		PackedVector2Array([fire + Vector2(-9, 0), fire + Vector2(0, -22 - 6 * flick), fire + Vector2(9, 0)]),
		Color("f2a444")
	)
	draw_circle(fire + Vector2(0, -4), 5.0, Color("ffe08a"))
