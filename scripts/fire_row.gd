extends VBoxContainer
## The Hearth card's fire (scripts/hearthfire.gd): "Hearthfire: tier 2 of 5, +6% work speed. 1,200 worth to the next." and a switch for
## feeding it what the stores would spill. On by default: nobody has to click to light it. Plain widgets, like the other rows.

signal changed

const Data = preload("res://scripts/data.gd")
const Hearthfire = preload("res://scripts/hearthfire.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")

const TIP := (
	"The fire takes goods the stores would spill over their cap, at their worth. Each tier is +3% work speed. "
	+ "It never takes a good the goal or the next gate asks for."
)
const SWITCH := "Feed it what would spill"

var state: Sim
var line: Label
var switch: CheckButton


func setup(game: Sim) -> void:
	state = game
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	line = Ui.label("", Ui.MIN_TEXT)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(60, 0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.tooltip_text = TIP
	line.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(line)
	switch = CheckButton.new()
	switch.text = SWITCH
	switch.tooltip_text = TIP
	switch.toggled.connect(
		func(on: bool) -> void:
			state.economy.fire["auto"] = on
			changed.emit()
	)
	add_child(switch)


## Show the fire for building b (only the Hearth has one).
func show_for(b: Dictionary) -> void:
	visible = Data.BUILDINGS[b["type"]]["kind"] == "camp"
	if not visible:
		return
	line.text = Hearthfire.text(state)
	switch.set_pressed_no_signal(bool(state.economy.fire["auto"]))
