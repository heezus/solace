extends Control
## A plain card over a dimmed map: a title, some words and one button per choice. It puts itself up for the run's first famine and for
## each season of strain (design-system/24-balance.md): `poll` is asked every frame, opens the card when one is due and says so, and
## the owner pauses while it is up and resumes on `closed`. A season's answer goes to the Seasons block from here. A run that
## begins after an ending opens with that ending's card ("A new land" for the Exodus, "The ruins", "Another valley"), once.
## Signal: closed(look) fires once when a button is pressed; `look` is true when the player asked to see the Hearth.

signal closed(look: bool)

const Data = preload("res://scripts/data.gd")
const TopBar = preload("res://scripts/top_bar.gd")
const Ui = preload("res://scripts/ui.gd")

const WIDTH := 460.0

var _box: VBoxContainer
var _state  # the Sim, kept while a season's card is up so the answer can reach its Seasons block
var _season := false  # the card now up is a season's


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
	_box.add_theme_constant_override("separation", 14)
	_box.custom_minimum_size = Vector2(WIDTH, 0)
	card.add_child(_box)


## Lay the card over `area` (the map view), as the other cards do.
func place(area: Rect2) -> void:
	position = area.position
	size = area.size


## Put the card up if one is due in `s` and nothing else is up (`blocked`). True when it opened, so the owner can pause.
func poll(s, blocked: bool) -> bool:
	if blocked or visible:
		return false
	if s.carry.exodus > 0 and not s.carry.told:
		s.carry.told = true
		_season = false
		var ending: Dictionary = Data.ENDINGS[s.carry.ending] if Data.ENDINGS.has(s.carry.ending) else {}
		open(ending.get("next_title", Data.EXODUS["land_title"]), _land_text(s), [Data.EXODUS["land_button"]])
		return true
	if s.seasons.phase == "pending":
		var def: Dictionary = Data.SEASONS[s.seasons.kind]
		var labels: Array = []
		var notes: Array = []
		for o in def["options"]:
			labels.append(o["label"])
			notes.append(o["note"])
		_state = s
		_season = true
		open(def["title"], def["text"] % [Data.SEASON_LENGTH, Data.PEOPLE["many"]], labels, notes)
		return true
	if s.economy.take_famine_card():
		_season = false
		var left := minf(s.economy.seconds_of_food(), 3600.0)
		var words: String = Data.FAMINE_TEXT % [TopBar.duration_text(left), Data.PEOPLE["many"]]
		open(Data.FAMINE_TITLE, words, [Data.FAMINE_LOOK, Data.FAMINE_CARRY_ON])
		return true
	return false


## What the Kith carry, one line each: the techs, the marks and the echoes (the Lumen building each opens).
func _land_text(s) -> String:
	var ending: Dictionary = Data.ENDINGS[s.carry.ending] if Data.ENDINGS.has(s.carry.ending) else {}
	var lines: Array = [ending.get("next_text", Data.EXODUS["land_text"]), ""]
	if not s.carry.techs.is_empty():
		lines.append(Data.EXODUS["land_techs"] % s.carry.techs.size())
	if not s.carry.marks.is_empty():
		lines.append(Data.EXODUS["land_marks"] % s.carry.marks.size())
	for id in Data.ROAD_ORDER:
		if s.carry.has_echo(id):
			var card: Dictionary = Data.LUMEN["cards"][id]
			lines.append(Data.EXODUS["land_echoes"] % [card["set"], Data.BUILDINGS[card["building"]]["name"]])
	return "\n".join(lines)


## Put the card up with `title`, `text` and a button for each of `labels`, each with its `notes` line under it when given.
func open(title: String, text: String, labels: Array, notes := []) -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_box.add_child(_words(title, 28, Ui.HIGHLIGHT))
	_box.add_child(_words(text, 18, Ui.TEXT))
	for i in labels.size():
		var b := Ui.button(labels[i])
		Ui.action_button(b)
		b.text = labels[i]
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_pick.bind(i))
		_box.add_child(b)
		if i < notes.size():
			_box.add_child(_words(notes[i], Ui.MIN_TEXT, Ui.TEXT_DIM))
	visible = true


func _words(text: String, font_size: int, color: Color) -> Label:
	var l := Ui.label(text, font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	return l


func _pick(index: int) -> void:
	if not visible:
		return
	visible = false
	if _season:
		_state.seasons.choose(_state, index)
	closed.emit(not _season and index == 0)
