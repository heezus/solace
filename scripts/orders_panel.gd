extends VBoxContainer
## The Order Board's panel (scripts/livewire.gd): the standing orders, each a line of words ("When Coal is below 20: Pause Forges")
## with a row of buttons under it that step through short lists, so there is no typing: the good, below or above, the number
## with - and +, the verb, the kind of building, and Clear. Under each, when it last fired (marked when it has not for five
## minutes). A last button writes a new order while a slot is free. Plain buttons and labels, so it fits any panel layout.

signal changed

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")

var state: Sim
var key := ""  # what the rows were built from, so they are built again only when an order or a slot changes
var _status: Array = []  # each order's "last fired" label, kept current without building the rows again


func setup(game: Sim) -> void:
	state = game
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)


## Show the orders for building b (hidden unless it is the Order Board).
func show_for(b: Dictionary) -> void:
	visible = Data.BUILDINGS[b["type"]]["kind"] == "board"
	if not visible:
		key = ""
		return
	var lw = state.livewire
	var now := "%s|%d" % [lw.orders.map(func(o): return lw.text(o) + o["verb"] + o["target"]), lw.slots(state)]
	if now != key:
		key = now
		_build()
	for i in _status.size():
		if i < lw.orders.size():
			_status[i].text = lw.last_firing(lw.orders[i])
			_status[i].add_theme_color_override("font_color", Ui.SHORT if lw.is_stale(lw.orders[i]) else Ui.TEXT_DIM)


func _build() -> void:
	var lw = state.livewire
	for c in get_children():
		c.queue_free()
		remove_child(c)
	_status = []
	add_child(Ui.heading(Data.ORDER_HEADING))
	add_child(_wrapped(Data.ORDER_SLOTS_LINE % [lw.orders.size(), lw.slots(state)], Ui.TEXT_DIM))
	if lw.orders.is_empty():
		add_child(_wrapped(Data.ORDER_EMPTY, Ui.TEXT_DIM))
	for i in lw.orders.size():
		_add_order(i, lw.orders[i])
	if lw.orders.size() < lw.slots(state):
		var write := Ui.button(Data.ORDER_NEW)
		write.pressed.connect(func(): _do(func(): lw.add(state)))
		add_child(write)
	else:
		add_child(_wrapped(Data.ORDER_FULL % lw.slots(state), Ui.TEXT_DIM))


func _add_order(i: int, o: Dictionary) -> void:
	var lw = state.livewire
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.panel_style(Ui.PANEL, 6))
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	v.add_child(_wrapped(lw.text(o), Ui.TEXT))
	var row := HFlowContainer.new()  # wraps in a narrow panel
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	v.add_child(row)
	row.add_child(_pick(Data.ITEMS[o["item"]]["name"], Data.ORDER_ITEM_TIP, func(): lw.cycle_item(state, i)))
	row.add_child(_pick(o["compare"], Data.ORDER_COMPARE_TIP, func(): lw.toggle_compare(i)))
	row.add_child(_pick(Data.ORDER_NUMBER_LESS, Data.ORDER_NUMBER_TIP, func(): lw.step_number(i, -1), 28))
	var number := Ui.label(str(o["number"]), Ui.LABEL_TEXT)
	number.tooltip_text = Data.ORDER_NUMBER_TIP
	number.mouse_filter = Control.MOUSE_FILTER_PASS
	number.custom_minimum_size = Vector2(36, 26)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(number)
	row.add_child(_pick(Data.ORDER_NUMBER_MORE, Data.ORDER_NUMBER_TIP, func(): lw.step_number(i, 1), 28))
	row.add_child(
		_pick(Data.ORDER_VERBS[o["verb"]]["name"], Data.ORDER_VERBS[o["verb"]]["tip"], func(): lw.cycle_verb(i))
	)
	var target: String = Data.BUILDINGS[o["target"]]["name"] if o["target"] != "" else "Choose"
	row.add_child(_pick(target, Data.ORDER_TARGET_TIP, func(): lw.cycle_target(state, i)))
	row.add_child(_pick(Data.ORDER_CLEAR, Data.ORDER_CLEAR_TIP, func(): lw.clear(i)))
	var status := _wrapped("", Ui.TEXT_DIM)
	v.add_child(status)
	_status.append(status)


## A button that does `act` and then tells the owner to draw the card again.
func _pick(text: String, tip: String, act: Callable, width := 0) -> Button:
	var b := Ui.button(text)
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(width, 26)
	b.pressed.connect(func(): _do(act))
	return b


func _do(act: Callable) -> void:
	act.call()
	key = ""
	changed.emit()


func _wrapped(text: String, color: Color) -> Label:
	var l := Ui.label(text, Ui.MIN_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(60, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", color)
	return l
