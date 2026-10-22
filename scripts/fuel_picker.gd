extends VBoxContainer
## The fuel of a Bloomery, a Forge or a Factory Floor copying one (scripts/fuel.gd): one button on its card that steps Auto, Coal,
## Charcoal, and a line saying what it burns now. Plain widgets, like the other pickers.

signal changed

const Data = preload("res://scripts/data.gd")
const Fuel = preload("res://scripts/fuel.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")

var state: Sim
var button: Button
var line: Label
var _at := -1  # the index of the building being shown


func setup(game: Sim) -> void:
	state = game
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	line = Ui.label("", Ui.MIN_TEXT)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(60, 0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(line)
	button = Ui.button("")
	button.tooltip_text = Data.FUEL_TIP
	button.pressed.connect(_step)
	add_child(button)


## Show the fuel of building b (hidden unless it burns fuel).
func show_for(b: Dictionary) -> void:
	visible = Fuel.burns(b)
	if not visible:
		_at = -1
		return
	_at = state.town.buildings.find(b)
	button.text = Data.FUEL_BUTTON % Data.FUEL_NAMES[b["fuel"]]
	line.text = Fuel.line(b)


func _step() -> void:
	if _at >= 0 and _at < state.town.buildings.size() and Fuel.burns(state.town.buildings[_at]):
		Fuel.cycle(state.economy, state.town.buildings[_at])
		changed.emit()
