extends VBoxContainer
## A Trading Post swaps one good for another: this is the panel's two lines that say which ("Gives: Wood",
## "Gets: Copper"). A click on a line moves it on to the next good the stockpile has held. Plain text, so it fits any
## panel layout. Static helpers word a line and pick the next good.

signal changed

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")

var state: Sim
var index := -1  # the Trading Post's place in the building list, -1 for none
var _lines := {}  # "give" or "get" -> its Button


func setup(game: Sim) -> void:
	state = game
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for which in ["give", "get"]:
		var b := Button.new()
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(60, 0)
		b.add_theme_font_size_override("font_size", Ui.MIN_TEXT)
		b.add_theme_color_override("font_color", Ui.TEXT)
		b.add_theme_color_override("font_hover_color", Ui.HIGHLIGHT)
		b.tooltip_text = Data.TRADE_TIP
		b.pressed.connect(cycle.bind(which))
		add_child(b)
		_lines[which] = b


## Show the lines for building b (hidden unless it is a Trading Post).
func show_for(b: Dictionary) -> void:
	visible = Data.BUILDINGS[b["type"]].get("trade", false)
	if not visible:
		index = -1
		return
	index = state.town.building_at[b["pos"]]
	_lines["give"].text = label_text(Data.TRADE_GIVES, b["give"])
	_lines["get"].text = label_text(Data.TRADE_GETS, b["get"])


## Move the line `which` ("give" or "get") on to the next good, and say so.
func cycle(which: String) -> void:
	if index < 0:
		return
	var b: Dictionary = state.town.buildings[index]
	var other: String = b["get" if which == "give" else "give"]
	var next := next_good(state.economy.seen, b[which], other)
	if next == "":
		return
	var done := (
		state.town.set_trade(index, next, other) if which == "give" else state.town.set_trade(index, other, next)
	)
	if done:
		changed.emit()


## "Gives: Wood", or the line with TRADE_NONE for a good not chosen yet.
static func label_text(line: String, item: String) -> String:
	return line % (Data.ITEMS[item]["name"] if item != "" else Data.TRADE_NONE)


## The good after `current` among the ones held before (`seen`), in Data.ITEM_ORDER, skipping `other`: "" when there is
## none to choose.
static func next_good(seen: Dictionary, current: String, other: String) -> String:
	var goods: Array = Data.ITEM_ORDER.filter(func(id): return seen.has(id) and id != other)
	if goods.is_empty():
		return ""
	return goods[(goods.find(current) + 1) % goods.size()]
