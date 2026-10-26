extends ScrollContainer
## The tech panel's Lumen tab: four cards, one for each glyph set that opens a Lumen building (Data.LUMEN, Starfall.opens). A card is
## shut until its marks are read ("Read the Light marks to open this"); an open one names the building, what it does, what it
## costs against the stockpile, how many stand and where on the build bar to find it. Reading changes nothing in the Sim.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")

const CARD_W := 396.0

var state: Sim
var cards := {}  # set id -> its card
var key := ""  # what the cards were built from: they are rebuilt only when it changes
var box: VBoxContainer


func setup(game: Sim) -> void:
	state = game
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)


## Rebuild the cards when what they show has changed (a set read, a building raised, the stockpile counts).
func refresh() -> void:
	var parts: Array = []
	for id in Data.ROAD_ORDER:
		var def: Dictionary = Data.BUILDINGS[Data.LUMEN["cards"][id]["building"]]
		parts.append(
			[
				id,
				state.starfall.opens(id),
				standing(id),
				def["cost"].keys().map(func(c): return state.economy.inv.get(c, 0))
			]
		)
	var now := str(parts)
	if now == key:
		return
	key = now
	_build()


## How many buildings of set `id`'s card stand.
func standing(id: String) -> int:
	var type: String = Data.LUMEN["cards"][id]["building"]
	return state.town.buildings.filter(func(b): return b["type"] == type).size()


func _build() -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	cards = {}
	box.add_child(Ui.label(Data.LUMEN["title"], 22))
	box.add_child(_wrapped(Data.LUMEN["explain"], Ui.TEXT_DIM))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 14)
	box.add_child(flow)
	for id in Data.ROAD_ORDER:
		var card := _card(id)
		flow.add_child(card)
		cards[id] = card


## One set's card.
func _card(id: String) -> PanelContainer:
	var info: Dictionary = Data.LUMEN["cards"][id]
	var def: Dictionary = Data.BUILDINGS[info["building"]]
	var open: bool = state.starfall.opens(id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var style := Ui.panel_style(Ui.CARD, 12)
	style.border_color = Ui.HIGHLIGHT if open else Ui.EDGE
	style.bg_color = Ui.GLASS_ON if open else Ui.GLASS_CARD
	card.add_theme_stylebox_override("panel", style)
	card.set_meta("set", id)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	top.add_child(_icon(info["building"]))
	var name_label := Ui.label(def["name"] if open else info["set"], 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_label)
	if not open:
		v.add_child(_wrapped(Data.LUMEN["closed"] % info["set"], Ui.TEXT_DIM))
		return card
	if state.starfall.roads.get(id, "") == "refuse":
		v.add_child(_wrapped(Data.LUMEN["own_way"][id], Ui.ACTION))
	v.add_child(_wrapped(info["does"], Ui.TEXT))
	v.add_child(_cost_row(def["cost"]))
	var n := standing(id)
	var where: String = Data.LUMEN["standing"] % n if n > 0 else Data.LUMEN["none_standing"]
	v.add_child(_wrapped("%s. %s" % [where, Data.LUMEN["build_on"] % info["tab"]], Ui.GOOD if n > 0 else Ui.TEXT_DIM))
	return card


func _wrapped(text: String, col: Color) -> Label:
	var l := Ui.label(text, Ui.MIN_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", col)
	return l


## The building's picture, drawn by the same code as on the map.
func _icon(type: String, side := 40.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(side, side)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): Art.map_building(c, type, Rect2(Vector2.ZERO, c.size), false, 0.0))
	return c


## The price, one chip per item: its picture and "Wood 12 of 20", green when you have enough of it, red when short.
func _cost_row(cost: Dictionary) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 4)
	var head := Ui.label(Data.NEXT_COST_HEAD, Ui.MIN_TEXT)
	head.add_theme_color_override("font_color", Ui.TEXT_DIM)
	flow.add_child(head)
	for id in cost:
		var have: int = state.economy.inv.get(id, 0)
		var need: int = cost[id]
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)
		chip.add_child(Ui.item_icon(id, 20))
		var l := Ui.label(Data.NEXT_COST_ITEM % [Data.ITEMS[id]["name"], mini(have, need), need], Ui.MIN_TEXT)
		l.add_theme_color_override("font_color", Ui.GOOD if have >= need else Ui.SHORT)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(l)
		flow.add_child(chip)
	return flow
