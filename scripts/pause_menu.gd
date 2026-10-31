extends Control
## The pause menu: Resume, Save game, Load game and Quit to title, on a card over the dimmed map, and two switches: Cutscenes
## (on unless the player turns it off: scripts/cutscene_settings.gd) and Debug keys (off unless turned on: scripts/debug_keys.gd).
## The owner (scripts/main.gd) pauses while it is up and does the real work; this only shows the buttons and a one-line
## status ("Saved to slot 2."). Save and Load open the slot screen. "Choose an ending" is greyed until Skyward stands, and
## "Forget past runs" clears the profile; both ask first (scripts/game_menu.gd).
## Signals: resumed, save_pressed, load_pressed, chronicle_pressed, quit_pressed, set_out_pressed, forget_pressed.

signal resumed
signal save_pressed
signal load_pressed
signal chronicle_pressed
signal quit_pressed
signal set_out_pressed
signal forget_pressed

const ChronicleWords = preload("res://scripts/chronicle_words.gd")
const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")
const MenuFonts = preload("res://scripts/menu_fonts.gd")
const BuildInfo = preload("res://scripts/build_info.gd")
const Hotkeys = preload("res://scripts/hotkeys.gd")
const DebugKeys = preload("res://scripts/debug_keys.gd")
const CutsceneSettings = preload("res://scripts/cutscene_settings.gd")
const HintSettings = preload("res://scripts/hint_settings.gd")
const PlayLogSettings = preload("res://scripts/play_log_settings.gd")

const WIDTH := 300.0
const ROOM_MARGIN := 18.0  # space kept free above and below the card

var load_button: Button
var set_out_button: Button
var debug_toggle: CheckButton
var cutscene_toggle: CheckButton
var hints_toggle: CheckButton
var playlog_toggle: CheckButton
var status: Label
var scroll: ScrollContainer  # holds the column of buttons; as tall as the column, or as tall as the window allows
var v: VBoxContainer
var _room := 0.0  # the height the menu may take, set by place()


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
	card.add_theme_stylebox_override("panel", Ui.panel_style(Ui.PANEL, 14))
	centre.add_child(card)
	scroll = ScrollContainer.new()  # a window shorter than the menu scrolls it (see _fit), never cuts it off
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(WIDTH, 0)
	scroll.add_child(v)
	var title := Ui.label(Data.PAUSE_TITLE, 28)
	MenuFonts.style_display(title, 30)
	title.add_theme_color_override("font_color", Ui.HIGHLIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_button(Data.PAUSE_RESUME, true, func(): resume()))
	v.add_child(_button(Data.PAUSE_SAVE, false, func(): save_pressed.emit()))
	load_button = _button(Data.PAUSE_LOAD, false, func(): load_pressed.emit())
	v.add_child(load_button)
	v.add_child(_button(ChronicleWords.TITLE, false, func(): chronicle_pressed.emit()))
	v.add_child(_button(Data.PAUSE_QUIT, false, func(): quit_pressed.emit()))
	var exodus := HBoxContainer.new()  # the two small ones: leaving this land, and forgetting the past ones
	exodus.add_theme_constant_override("separation", 8)
	set_out_button = _small_button(exodus, Data.ENDINGS["choose"], func(): set_out_pressed.emit())
	_small_button(exodus, Data.EXODUS["forget"], func(): forget_pressed.emit()).tooltip_text = Data.EXODUS["forget_tip"]
	v.add_child(exodus)
	cutscene_toggle = _switch(Data.CUTSCENES_LABEL, Data.CUTSCENES_HELP, CutsceneSettings.set_on)
	v.add_child(cutscene_toggle)
	hints_toggle = _switch(Data.HINTS_LABEL, Data.HINTS_HELP, HintSettings.set_on)
	v.add_child(hints_toggle)
	playlog_toggle = _switch(Data.PLAYLOG_LABEL, Data.PLAYLOG_HELP, PlayLogSettings.set_on)
	v.add_child(playlog_toggle)
	debug_toggle = _switch(Data.DEBUG_KEYS_LABEL, Data.DEBUG_HELP, DebugKeys.set_on)
	v.add_child(debug_toggle)
	var keys := Ui.label("\n".join(Hotkeys.LIST.map(func(row): return "%s: %s" % row)), Ui.MIN_TEXT)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.visible = false
	MenuFonts.style_caption(keys)
	v.add_child(_button("Keys", false, _toggle_keys.bind(keys)))
	v.add_child(keys)
	status = Ui.label("", Ui.MIN_TEXT)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuFonts.style_caption(status)
	status.add_theme_color_override("font_color", Ui.GOOD)
	v.add_child(status)
	var hint := Ui.label(Data.PAUSE_HINT, Ui.MIN_TEXT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuFonts.style_caption(hint)
	hint.add_theme_color_override("font_color", Ui.TEXT_DIM)
	v.add_child(hint)
	var build := BuildInfo.label(Ui.MIN_TEXT)
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(build)


## The Keys button: show or hide the list of hotkeys (and refit the card around it).
func _toggle_keys(keys: Label) -> void:
	keys.visible = not keys.visible
	_fit.call_deferred()


## An on/off switch under the buttons, in the caption face; `on_toggle` is told the new state.
func _switch(text: String, help: String, on_toggle: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.tooltip_text = help
	c.add_theme_font_override("font", MenuFonts.caption())
	c.add_theme_font_size_override("font_size", Ui.MIN_TEXT)
	c.toggled.connect(func(on): on_toggle.call(on))
	return c


func _small_button(row: HBoxContainer, text: String, on_press: Callable) -> Button:
	var b := _button(text, false, on_press)
	b.custom_minimum_size = Vector2(0, 32)
	MenuFonts.style_button(b, 15)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	return b


func _button(text: String, primary: bool, on_press: Callable) -> Button:
	var b := Ui.button(text)
	Ui.action_button(b, primary)
	b.text = text
	MenuFonts.style_button(b, 19)
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(on_press)
	return b


## Lay the menu over `area` (the map view), as the cards do.
func place(area: Rect2) -> void:
	position = area.position
	size = area.size
	_room = area.size.y - 2.0 * ROOM_MARGIN
	_fit()


## The scroll is as tall as the column of buttons when the window has the room, else as tall as the room (and the column scrolls).
func _fit() -> void:
	if scroll == null:
		return
	var want: float = v.get_combined_minimum_size().y
	var bar: float = 12.0 if _room > 0.0 and want > _room else 0.0  # the scroll bar's width, when there is one
	scroll.custom_minimum_size = Vector2(WIDTH + bar, minf(want, _room) if _room > 0.0 else want)


## Put the menu up with a clean status line.
func open() -> void:
	status.text = ""
	_fit()
	debug_toggle.set_pressed_no_signal(DebugKeys.on())
	cutscene_toggle.set_pressed_no_signal(CutsceneSettings.on())
	hints_toggle.set_pressed_no_signal(HintSettings.on())
	playlog_toggle.set_pressed_no_signal(PlayLogSettings.on())
	visible = true


## Say something under the buttons (a good line is green, a bad one is not).
func say(text: String, good := true) -> void:
	status.text = text
	status.add_theme_color_override("font_color", Ui.GOOD if good else Ui.BAD)
	_fit.call_deferred()


## Put the menu away and say so.
func resume() -> void:
	if visible:
		visible = false
		resumed.emit()
