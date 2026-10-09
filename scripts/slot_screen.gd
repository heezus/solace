extends Control
## The save and load screen, one card over the dimmed view. In "load" mode it lists the player's saves (the filled slots)
## and, below them, the stage starts (scripts/dev_starts.gd): a start begins a new run at that stage and is never written to,
## because Save only ever writes to a slot. In "save" mode it lists every slot, filled or empty, with what is in it; picking
## a filled slot asks once more ("Click again to replace") before it is written. Used by the title screen and the pause menu.
## A stage start is built on demand by the pacing bots, which takes a while: the screen says so, and builds on a thread
## (where there are threads) so the window stays alive. It only chooses; the owner does the loading and saving.
## Signals: slot_picked(slot), start_picked(dump) (a run dump to begin from), closed.

signal slot_picked(slot: int)
signal start_picked(dump: Dictionary)
signal closed

const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")
const MenuFonts = preload("res://scripts/menu_fonts.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const DevStarts = preload("res://scripts/dev_starts.gd")
const RunSave = preload("res://scripts/run_save.gd")

const WIDTH := 460.0
const LIST_HEIGHT := 360.0

var mode := "load"  # "load" or "save"
var dir := SaveSlots.DIR
var use_thread := not OS.has_feature("web")  # a web build has no threads: the bots run on the main one
var status: Label
var _title: Label
var _list: VBoxContainer
var _buttons: Array = []  # every pick button, off while a stage builds
var _armed := 0  # the filled slot whose replace is waiting for a second click (save mode)
var _thread: Thread
var _building := ""  # the id of the stage being built, "" for none
var _built_at := 0
var _dump: Dictionary = {}  # what the thread built


func setup() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP  # the view behind it takes no clicks while it is up
	var dim := ColorRect.new()
	dim.color = Ui.SCRIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.panel_style(Ui.PANEL, 14))
	centre.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size = Vector2(WIDTH, 0)
	card.add_child(v)
	_title = Ui.label("", 30)
	MenuFonts.style_display(_title, 30)
	_title.add_theme_color_override("font_color", Ui.HIGHLIGHT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(WIDTH, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	status = Ui.label("", Ui.MIN_TEXT)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuFonts.style_caption(status)
	v.add_child(status)
	var back := _button(Data.LOAD_BACK, false, close)
	back.name = "Back"
	v.add_child(back)


func _button(text: String, primary: bool, on_press: Callable) -> Button:
	var b := Ui.button(text)
	Ui.action_button(b, primary)
	b.text = text
	MenuFonts.style_button(b, 17)
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(on_press)
	return b


## Lay the screen over `area` (the map view), as the cards do.
func place(area: Rect2) -> void:
	position = area.position
	size = area.size


## Show the screen in `new_mode` ("load" or "save") with the slots as they are now.
func open(new_mode: String) -> void:
	mode = new_mode
	_armed = 0
	status.text = Data.SAVE_HINT if mode == "save" else ""
	status.add_theme_color_override("font_color", Ui.TEXT_DIM)
	_title.text = Data.SAVE_TITLE if mode == "save" else Data.LOAD_TITLE
	_fill()
	visible = true


## Put the screen away (a stage that is still being built is dropped when it finishes).
func close() -> void:
	if visible:
		visible = false
		closed.emit()


## Rebuild the list for the current mode.
func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
		_list.remove_child(c)
	_buttons.clear()
	if mode == "save":
		for slot in range(1, SaveSlots.COUNT + 1):
			_add_slot(slot)
		return
	_list.add_child(_heading(Data.LOAD_SAVES))
	var filled := SaveSlots.filled(dir)
	if filled.is_empty():
		_list.add_child(_note(Data.LOAD_NO_SAVES))
	for slot in filled:
		_add_slot(slot)
	_list.add_child(_heading(Data.LOAD_STARTS))
	_list.add_child(_note(Data.LOAD_STARTS_NOTE))
	for row in DevStarts.list():
		var b := _button(row["label"], false, pick_start.bind(row["id"]))
		b.name = "Start_" + row["id"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list.add_child(b)
		_buttons.append(b)


func _add_slot(slot: int) -> void:
	var b := _button(_slot_text(slot), false, pick_slot.bind(slot))
	b.name = "Slot_%d" % slot
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_list.add_child(b)
	_buttons.append(b)


func _slot_text(slot: int) -> String:
	return "%s: %s" % [Data.SLOT_NAME % slot, SaveSlots.summary(slot, dir)]


func _heading(text: String) -> Label:
	var l := Ui.label(text, Ui.LABEL_TEXT)
	MenuFonts.style_display(l, Ui.LABEL_TEXT + 2)
	l.add_theme_color_override("font_color", Ui.HIGHLIGHT)
	return l


func _note(text: String) -> Label:
	var l := Ui.label(text, Ui.MIN_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MenuFonts.style_caption(l)
	l.add_theme_color_override("font_color", Ui.TEXT_DIM)
	return l


## A slot was clicked. Loading picks it at once; saving over a filled slot waits for a second click.
func pick_slot(slot: int) -> void:
	if _building != "":
		return
	if mode == "save" and not SaveSlots.read(slot, dir).is_empty() and _armed != slot:
		_armed = slot
		_fill()
		var b: Button = find_child("Slot_%d" % slot, true, false)
		b.text = "%s: %s" % [Data.SLOT_NAME % slot, Data.SLOT_OVERWRITE]
		return
	_armed = 0
	slot_picked.emit(slot)


## A stage start was clicked: build it (the status line says so) and hand over its run dump.
func pick_start(id: String) -> void:
	if _building != "":
		return
	_building = id
	_built_at = Time.get_ticks_msec()
	status.text = Data.LOAD_BUILDING
	status.add_theme_color_override("font_color", Ui.HIGHLIGHT)
	for b in _buttons:
		b.disabled = true
	_dump = {}
	if use_thread:
		_thread = Thread.new()
		_thread.start(_build.bind(id))
	else:
		await get_tree().process_frame  # let the line above be drawn before the bots take over
		await get_tree().process_frame
		_dump = _build(id)
		_finish()


## Build the start `id` and give back its run dump ({} when there is no such start).
func _build(id: String) -> Dictionary:
	var s := DevStarts.build(id)
	return RunSave.dump(s) if s != null else {}


func _process(_delta: float) -> void:
	if _building == "" or not visible:
		return
	if _thread != null:
		if _thread.is_alive():
			status.text = "%s %d s" % [Data.LOAD_BUILDING, floori((Time.get_ticks_msec() - _built_at) / 1000.0)]
			return
		_dump = _thread.wait_to_finish()
		_thread = null
		_finish()


func _finish() -> void:
	_building = ""
	if _dump.is_empty():
		status.text = Data.LOAD_BUILD_FAILED
		status.add_theme_color_override("font_color", Ui.BAD)
		for b in _buttons:
			b.disabled = false
		return
	start_picked.emit(_dump)


## True while a stage is being built.
func building() -> bool:
	return _building != ""
