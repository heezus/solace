extends Control
## The cutscene player (design-system/20-cutscenes.md): a full-window control that plays the sequences of Data.CUTSCENES.
## It listens to Story.recorded (era changes are story moments too), so no gameplay code changes: when a sequence's trigger
## is recorded it joins a queue, and the queue plays one at a time, in the order of Data.CUTSCENES. A fresh run plays
## `opening` when the player is attached. While a sequence plays the owner (`host`, the game scene) is kept paused, and put
## back as it was after. Esc, Space or a click skips the sequence in hand. A skip changes nothing in the run: the trigger is
## a story id the Story block has already recorded, so watching or skipping leave the same story behind.
## A still whose picture is not painted shows its line over a dark panel, so the story ships before the art.
## The on/off switch is CutsceneSettings (the pause menu). Tools and tests that build the game scene set `suppress`.
## Repeat runs: variant lines and memory overlays are chosen from the profile as it stood when the run began (`prior`),
## so a run never echoes itself. Signal: finished(id, skipped) fires when a sequence ends.

signal finished(id: String, skipped: bool)

const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")
const MenuFonts = preload("res://scripts/menu_fonts.gd")
const Profile = preload("res://scripts/profile.gd")
const CutsceneSettings = preload("res://scripts/cutscene_settings.gd")

static var suppress := false  # play nothing: set by the scripted play-through tools, which drive the game scene headless

var active := false  # a sequence is on screen: the owner's simulation waits
var current := ""  # the id playing now, "" when none
var played: Array = []  # ids that have been watched or skipped this run, in order
var queue: Array = []  # ids waiting, in the order of Data.CUTSCENES
var prior: Array = []  # story ids of earlier runs (the profile when the run began)
var stills: Array = []  # the resolved stills of the sequence playing: {art, line}
var overlays: Array = []  # the memory overlays (names) drawn over every still of it
var index := 0  # the still showing
var still_time := 0.0  # seconds into it
var total_time := 0.0  # seconds into the sequence
var state  # the Sim
var host  # the game scene: it has `paused`, and is held paused while a sequence plays
var _was_paused := false
var _textures := {}  # art name -> Texture2D, or null when it is not painted
var _caption: Label
var _hint: Label


## Build a player over `layer` (the game scene's CanvasLayer, as the last child so it is on top) for the game in `s`, with
## `owner_node` as the host to pause. Returns null when `suppress` is set.
static func attach(layer: Node, s, owner_node = null, prior_ids = null):
	if suppress:
		return null
	var p = new()
	layer.add_child(p)
	p.setup(s, owner_node, prior_ids)
	return p


## Hook the player to the game in `s`. `prior_ids` (story ids) stands in for the profile file, which is read when null.
func setup(s, owner_node = null, prior_ids = null) -> void:
	state = s
	host = owner_node
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP  # the game behind it takes no clicks while it plays
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption = Ui.label("", 28)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override("font_color", Ui.TEXT)
	_caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_caption.add_theme_constant_override("shadow_offset_x", 2)
	_caption.add_theme_constant_override("shadow_offset_y", 2)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuFonts.style_caption(_caption)
	add_child(_caption)
	_hint = Ui.label(Data.CUTSCENE_SKIP_HINT, Ui.MIN_TEXT)
	_hint.add_theme_color_override("font_color", Color(Ui.TEXT_DIM, 0.7))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	if prior_ids == null:
		var profile := Profile.new()
		profile.load_file()
		prior_ids = profile.chronicle
	# What this run has already recorded is not an echo of an earlier one (a game loaded part-way).
	prior = prior_ids.filter(func(id): return not s.story.has_event(id))
	s.story.recorded.connect(_on_story)
	if is_fresh_run(s):
		enqueue("opening")


## True for a run that has not begun: nothing recorded, one building (the Hearth), nothing learned.
static func is_fresh_run(s) -> bool:
	return s.story.events.is_empty() and s.town.buildings.size() <= 1 and s.tech_tree.researched.is_empty()


func _on_story(id: String) -> void:
	for seq in Data.CUTSCENES:
		if id in Data.CUTSCENES[seq]["triggers"]:
			enqueue(seq)


## Put sequence `id` in the queue (once per run, and not at all with cutscenes switched off).
func enqueue(id: String) -> void:
	if not CutsceneSettings.on() or id in played or id in queue or id == current:
		return
	queue.append(id)
	var order := Data.CUTSCENES.keys()
	queue.sort_custom(func(a, b): return order.find(a) < order.find(b))


## The stills of sequence `id` as they play now: the variant for how the strangers came or how the era ended, and one line
## swapped when an earlier run holds a matching echo (Data.CUTSCENE_VARIANT_LINES). Each is {art, line}.
func resolve(id: String) -> Array:
	var def: Dictionary = Data.CUTSCENES[id]
	var key := variant_key(def.get("by", ""))
	var out: Array = []
	for still in def["stills"]:
		var v: Dictionary = still.get("variants", {}).get(key, {})
		out.append({"art": v.get("art", still["art"]), "line": v.get("line", still["line"])})
	for row in Data.CUTSCENE_VARIANT_LINES:
		if row["seq"] == id and row["still"] < out.size() and row["needs"] in prior:
			out[row["still"]]["line"] = row["line"]
			break  # never more than one line swapped
	return out


## What picks a still's variant: "guests" when a Cairn stood before the star fell (else ""), the lean when the era ends.
func variant_key(by: String) -> String:
	match by:
		"arrival":
			return "guests" if state.starfall.guests else ""
		"lean":
			return state.starfall.lean
	return ""


## The memory overlays an earlier run earned (Data.CUTSCENE_MEMORY), by name.
func memory_overlays() -> Array:
	return Data.CUTSCENE_MEMORY.filter(func(m): return m["needs"] in prior).map(func(m): return m["overlay"])


func _process(delta: float) -> void:
	if not active:
		start_next()
	if active:
		advance(delta)
		_layout()
		queue_redraw()


## Start the first queued sequence whose `after` moment has happened. False when none is ready.
func start_next() -> bool:
	if not CutsceneSettings.on():
		queue.clear()
		return false
	for id in queue:
		var after: String = Data.CUTSCENES[id].get("after", "")
		if after == "" or state.story.has_event(after):
			queue.erase(id)
			_start(id)
			return true
	return false


func _start(id: String) -> void:
	current = id
	stills = resolve(id)
	overlays = memory_overlays()
	index = 0
	still_time = 0.0
	total_time = 0.0
	active = true
	visible = true
	_was_paused = host != null and bool(host.paused)
	_hold_pause()
	_show_line()


## Move the clock on. A still stays Data.CUTSCENE_STILL_SECONDS, then the next fades in; the last one ends the sequence.
func advance(delta: float) -> void:
	if not active:
		return
	_hold_pause()
	still_time += delta
	total_time += delta
	if still_time >= Data.CUTSCENE_STILL_SECONDS:
		still_time = 0.0
		index += 1
		if index >= stills.size():
			_finish(false)
			return
		_show_line()


## Skip the rest of the sequence in hand.
func skip() -> void:
	if active:
		_finish(true)


func _finish(skipped: bool) -> void:
	var id := current
	active = false
	visible = false
	current = ""
	played.append(id)
	if host != null:
		host.paused = _was_paused
	finished.emit(id, skipped)


func _hold_pause() -> void:
	if host != null:
		host.paused = true


func _show_line() -> void:
	_caption.text = stills[index]["line"]


## How visible the still showing is: it fades in from black, holds, and fades out to black.
func envelope() -> float:
	var f: float = Data.CUTSCENE_FADE_SECONDS
	return clampf(minf(still_time / f, (Data.CUTSCENE_STILL_SECONDS - still_time) / f), 0.0, 1.0)


func _input(event: InputEvent) -> void:
	if not active:
		return
	var go := false
	if event is InputEventKey and event.pressed and not event.echo:
		go = event.keycode in [KEY_ESCAPE, KEY_SPACE]
	elif event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		go = total_time >= Data.CUTSCENE_SKIP_GRACE
	if (
		get_viewport() != null
		and (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch)
	):
		get_viewport().set_input_as_handled()  # the game behind it hears nothing
	if go:
		skip()


## The painted still `art`, or null when it is not painted yet.
func texture(art: String) -> Texture2D:
	if not _textures.has(art):
		var path: String = Data.CUTSCENE_ART_DIR + art + ".png"
		_textures[art] = load(path) if ResourceLoader.exists(path) else null
	return _textures[art]


## The caption in the calm bottom third (or in the middle of the panel when there is no picture), and the skip hint.
func _layout() -> void:
	var has_art := texture(stills[index]["art"]) != null
	var h := size.y
	var share: float = Data.CUTSCENE_CAPTION_SHARE
	_caption.add_theme_font_size_override("font_size", clampi(roundi(h * 0.036), 20, 44))
	_caption.position = Vector2(size.x * 0.12, h * (1.0 - share) if has_art else h * 0.3)
	_caption.size = Vector2(size.x * 0.76, h * share * 0.8 if has_art else h * 0.4)
	_caption.modulate.a = envelope()
	_hint.position = Vector2(size.x - _hint.size.x - 18.0, h - _hint.size.y - 12.0)
	_hint.modulate.a = envelope()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if not active:
		return
	var env := envelope()
	var tex := texture(stills[index]["art"])
	if tex == null:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Data.CUTSCENE_PANEL, env))
		return
	# Cover the window, pushed in slowly over the still; the picture keeps its subject in the middle.
	var k: float = 1.0 + Data.CUTSCENE_PUSH_IN * clampf(still_time / Data.CUTSCENE_STILL_SECONDS, 0.0, 1.0)
	var cover := maxf(size.x / tex.get_width(), size.y / tex.get_height()) * k
	var extent := tex.get_size() * cover
	var box := Rect2((size - extent) * 0.5, extent)
	draw_texture_rect(tex, box, false, Color(1, 1, 1, env))
	var opacity: float = Data.CUTSCENE_MEMORY_OPACITY / sqrt(maxf(overlays.size(), 1.0))
	for overlay in overlays:
		var memory := texture(overlay)
		if memory != null:
			draw_texture_rect(memory, box, false, Color(1, 1, 1, env * opacity))
	var top := size.y * (1.0 - Data.CUTSCENE_CAPTION_SHARE - 0.1)
	var dark := Color(0.04, 0.05, 0.07, 0.88 * env)
	var clear := Color(dark, 0.0)
	var points := PackedVector2Array([Vector2(0, top), Vector2(size.x, top), size, Vector2(0, size.y)])
	draw_polygon(points, PackedColorArray([clear, clear, dark, dark]))
