extends VBoxContainer
## A depot's hauler places on its card (scripts/hauling.gd): "Haulers 6 of 9 wanted" with - and + to set the number below or above
## what the roads' load asks for, and Auto to go back to it. Shown for the Hearth and every Storehouse once haulers are known.
## Plain widgets, like the other pickers, so it fits any panel layout.

signal changed

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")

var state: Sim
var line: Label
var lever: Label
var minus: Button
var plus: Button
var auto: Button
var _depot := Vector2i(-1, -1)  # the tile of the depot being shown


func setup(game: Sim) -> void:
	state = game
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	line = Ui.label("", Ui.MIN_TEXT)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(60, 0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.tooltip_text = Data.HAULER_ROW_TIP
	line.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(line)
	lever = Ui.label("", Ui.MIN_TEXT)
	lever.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lever.custom_minimum_size = Vector2(60, 0)
	lever.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(lever)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	minus = Ui.button("-")
	plus = Ui.button("+")
	auto = Ui.button("Auto")
	for b in [minus, plus, auto]:
		b.custom_minimum_size = Vector2(0, 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = Data.HAULER_ROW_TIP
		row.add_child(b)
	minus.pressed.connect(func(): _nudge(-1))
	plus.pressed.connect(func(): _nudge(1))
	auto.pressed.connect(_reset)


## Show the places of building b (hidden unless it is the Hearth or a Storehouse with places to fill).
func show_for(b: Dictionary) -> void:
	_depot = b["pos"]
	var places: Dictionary = state.hauling.auto
	visible = Data.BUILDINGS[b["type"]]["kind"] in ["camp", "depot"] and places.has(_depot)
	if not visible:
		return
	var h = state.hauling
	var off: int = h.offset.get(_depot, 0)
	var now: int = h.wanted(_depot)
	line.text = (
		Data.HAULER_ROW % [h.have(_depot), now]
		if off == 0
		else Data.HAULER_ROW_SET % [h.have(_depot), now, places[_depot]]
	)
	lever.text = h.lever_note(_depot)
	lever.visible = lever.text != ""
	minus.disabled = now <= 0
	auto.disabled = off == 0


func _nudge(dir: int) -> void:
	state.hauling.nudge(_depot, dir)
	changed.emit()


func _reset() -> void:
	state.hauling.reset(_depot)
	changed.emit()
