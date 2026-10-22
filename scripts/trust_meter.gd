extends VBoxContainer
## How the Lumen stand with the Kith, as a word ("The Lumen are: Friendly") and a small bar, on the Lumen Market's panel. The number
## behind it stays hidden (Starfall.trust). A step of trust also floats over the Hearth as "+6 trust" (scripts/pop_feed.gd).

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")

var state: Sim
var _word: Label
var _bar: ProgressBar


func setup(game: Sim) -> void:
	state = game
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 2)
	_word = Ui.label("", Ui.MIN_TEXT)
	add_child(_word)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = Data.TRUST_MAX
	_bar.custom_minimum_size = Vector2(60, 8)
	add_child(_bar)


## Show the meter for building b (hidden unless it is a Lumen Market, and the Lumen are known by name).
func show_for(b: Dictionary) -> void:
	visible = b["type"] == "lumen_market" and state.starfall.trust_known()
	if visible:
		_word.text = Data.TRUST_LINE % state.starfall.trust_word()
		_bar.value = state.starfall.trust
