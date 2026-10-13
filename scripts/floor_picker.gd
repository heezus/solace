extends VBoxContainer
## The Factory Floor's recipe (design-system/23-livewire.md): one button on its card that steps through the workshops it can copy
## (the ones the Kith can build), and a line of what it makes. The choice is the building's `make`. Plain widgets, like the other
## pickers, so it fits any panel layout.

signal changed

const Data = preload("res://scripts/data.gd")
const FloorRecipe = preload("res://scripts/floor_recipe.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")

var state: Sim
var button: Button
var line: Label
var _at := -1  # the index of the Floor being shown


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
	button.tooltip_text = Data.FLOOR_RECIPE_TIP
	button.pressed.connect(_step)
	add_child(button)


## Show the recipe of building b (hidden unless it is a Factory Floor).
func show_for(b: Dictionary) -> void:
	visible = Data.BUILDINGS[b["type"]].has("floor")
	if not visible:
		_at = -1
		return
	_at = state.town.buildings.find(b)
	var made: String = Data.ITEMS[Data.BUILDINGS[b["make"]]["out"].keys()[0]]["name"]
	button.text = Data.FLOOR_RECIPE_BUTTON % made
	button.disabled = FloorRecipe.options(state.town, b).size() < 2
	line.text = Data.FLOOR_MAKING % [made.to_lower(), int(Data.FLOOR_SPEED)]


func _step() -> void:
	if state.town.cycle_floor(_at):
		changed.emit()
