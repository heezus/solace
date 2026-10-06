extends VBoxContainer
## The Expedition Post's panel (scripts/expedition.gd): where the next party goes, which pack it carries, how long the trip
## takes against the day, a Send button and a Keep sending switch. A click on the target or pack line moves it to the next
## choice. Plain buttons and labels, so it fits any panel layout.

signal changed

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Ui = preload("res://scripts/ui.gd")
const Expedition = preload("res://scripts/expedition.gd")

var state: Sim
var key := ""  # what the rows were built from, so they are built again only when it changes


func setup(game: Sim) -> void:
	state = game
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)


## Show the rows for building b (hidden unless it is an Expedition Post).
func show_for(b: Dictionary) -> void:
	visible = Data.BUILDINGS[b["type"]]["kind"] == "post"
	if not visible:
		key = ""
		return
	var plan := Expedition.plan(state)
	var o: Dictionary = state.starfall.orders
	var now := "%s|%s|%s|%s" % [o, plan["ok"], plan["why"], roundi(plan["seconds"])]
	if now == key:
		return
	key = now
	for c in get_children():
		c.queue_free()
		remove_child(c)
	add_child(_line_button(target_text(state), Callable(self, "_next_target")))
	add_child(_line_button(pack_text(state), Callable(self, "_next_pack")))
	var trip := trip_text(plan)
	if trip != "":
		add_child(_wrapped(trip, Ui.SHORT if plan["late"] else Ui.TEXT_DIM))
	if not plan["ok"]:
		add_child(_wrapped(plan["why"], Ui.SHORT))
	var send := Ui.button(Data.POST_SEND)
	send.disabled = not plan["ok"]
	send.pressed.connect(
		func():
			state.events.append(Expedition.send(state))
			changed.emit()
	)
	add_child(send)
	add_child(_line_button(keep_text(state), Callable(self, "_toggle_keep")))
	add_child(_wrapped(Data.POST_HINT, Ui.TEXT_DIM))


## "Going to: The crash site (east)".
static func target_text(s: Sim) -> String:
	return Data.POST_TARGET % Data.TARGETS[s.starfall.orders["target"]]


## "Pack: Standard pack (16 Berries, 4 Rope), 2 marks".
static func pack_text(s: Sim) -> String:
	var id: String = s.starfall.orders["pack"]
	return Data.POST_PACK % [Data.PACKS[id]["name"], Expedition.cost_text(id), Data.PACKS[id]["finds"]]


## "About 90 s there and back, before dusk at 220 s." or the too-far warning, "" when there is no trip to speak of.
static func trip_text(plan: Dictionary) -> String:
	if plan["seconds"] <= 0.0:
		return ""
	if plan["late"]:
		return Data.POST_LATE
	return Data.POST_TRIP % [roundi(plan["seconds"]), roundi(Data.DAYLIGHT_SECONDS)]


## "Keep sending: on".
static func keep_text(s: Sim) -> String:
	return Data.POST_KEEP % (Data.POST_ON if s.starfall.orders["keep"] else Data.POST_OFF)


func _next_target() -> void:
	_cycle("target", Data.TARGET_ORDER)


func _next_pack() -> void:
	_cycle("pack", Data.PACK_ORDER)


func _toggle_keep() -> void:
	state.starfall.orders["keep"] = not state.starfall.orders["keep"]
	changed.emit()


func _cycle(field: String, order: Array) -> void:
	var at: int = order.find(state.starfall.orders[field])
	state.starfall.orders[field] = order[(at + 1) % order.size()]
	changed.emit()


func _wrapped(text: String, color: Color) -> Label:
	var l := Ui.label(text, Ui.MIN_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(60, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", color)
	return l


func _line_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a long line wraps instead of widening the side panel
	b.custom_minimum_size = Vector2(60, 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = text
	b.add_theme_font_size_override("font_size", Ui.MIN_TEXT)
	b.add_theme_color_override("font_color", Ui.TEXT)
	b.add_theme_color_override("font_hover_color", Ui.HIGHLIGHT)
	b.pressed.connect(on_press)
	return b
