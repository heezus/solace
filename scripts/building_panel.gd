extends PanelContainer
## The selected building's details, docked in the side panel's Info section (never floating over the map, so
## it can't cover the tiles you want next): status, what it does, its recipe or what it gathers, the worker and
## their tool in plain words (the exact numbers are in a tooltip), what it holds, the trip to the stockpile, and
## Collect and Pause buttons, with an x to close it. Tearing down is the one Demolish tool on the bottom bar.

signal closed

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Workers = preload("res://scripts/workers.gd")
const Roads = preload("res://scripts/roads.gd")
const Hands = preload("res://scripts/hands.gd")
const Kith = preload("res://scripts/kith.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Work = preload("res://scripts/work.gd")
const HutFocus = preload("res://scripts/hut_focus.gd")
const TradePicker = preload("res://scripts/trade_picker.gd")

const INSET := Color("3b2a24")  # the `ui-bar` cocoa, sunk into the `ui-panel` card

var state: Sim
var pos := Vector2i(-1, -1)  # the selected building's tile
var parts := {}


func setup(game: Sim) -> void:
	state = game
	visible = false
	add_theme_stylebox_override("panel", Ui.panel_style(Ui.CARD, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon)
	parts["icon"] = icon
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	parts["name"] = Ui.label("", Ui.LABEL_TEXT)
	names.add_child(parts["name"])
	parts["status"] = _wrapped(Ui.MIN_TEXT)
	names.add_child(parts["status"])
	var close := Ui.button("x")
	close.custom_minimum_size = Vector2(28, 28)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.tooltip_text = Data.CLOSE_TIP
	close.add_theme_stylebox_override("normal", _x_style(Ui.PANEL))
	close.add_theme_stylebox_override("hover", _x_style(Ui.BAD))
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)

	for key in ["desc", "recipe", "worker", "pace", "click"]:
		parts[key] = _wrapped(Ui.MIN_TEXT)
		v.add_child(parts[key])
	parts["pace"].add_theme_color_override("font_color", Ui.TEXT_DIM)
	parts["pace"].mouse_filter = Control.MOUSE_FILTER_STOP  # its tooltip has the exact numbers
	var focus := HutFocus.new()  # what a hut works: one line, one click to change (scripts/hut_focus.gd)
	focus.setup(game)
	focus.changed.connect(refresh)
	v.add_child(focus)
	v.move_child(focus, parts["recipe"].get_index())
	parts["focus"] = focus
	var trade := TradePicker.new()  # what a Trading Post swaps: two lines, a click on each changes it
	trade.setup(game)
	trade.changed.connect(refresh)
	v.add_child(trade)
	v.move_child(trade, parts["recipe"].get_index())
	parts["trade"] = trade
	parts["holding"] = Ui.label("", Ui.MIN_TEXT)
	v.add_child(parts["holding"])
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.show_percentage = false
	bar.modulate = Ui.HIGHLIGHT
	v.add_child(bar)
	parts["bar"] = bar

	var trip := PanelContainer.new()
	trip.add_theme_stylebox_override("panel", Ui.panel_style(INSET, 6))
	parts["trip_box"] = trip
	parts["trip"] = _wrapped(Ui.MIN_TEXT)
	trip.add_child(parts["trip"])
	v.add_child(trip)

	# The buttons are docked under the scrolling Info area (SidePanel moves them there), so they never scroll out of reach.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	v.add_child(buttons)
	parts["buttons"] = buttons
	visibility_changed.connect(_sync_buttons)
	var collect := _button("Collect", Ui.CARD, Ui.HIGHLIGHT)
	collect.pressed.connect(_on_collect)
	buttons.add_child(collect)
	parts["collect"] = collect
	var pause := _button("Pause", Ui.CARD, Ui.LINE)
	pause.pressed.connect(_on_pause)
	buttons.add_child(pause)
	parts["pause"] = pause


## The button row follows the card: shown while a building is selected, wherever it was docked.
func _sync_buttons() -> void:
	parts["buttons"].visible = visible


func _wrapped(font_size: int) -> Label:
	var l := Ui.label("", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(60, 0)  # it wraps to whatever width the side panel gives
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func _x_style(bg: Color) -> StyleBoxFlat:
	var style := Ui.panel_style(bg, 2)
	style.set_border_width_all(2)
	return style


func _button(text: String, bg: Color, border: Color) -> Button:
	var b := Ui.button(text)
	b.custom_minimum_size = Vector2(0, 28)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := Ui.panel_style(bg, 4)
	style.border_color = border
	style.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = bg.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	return b


func select(p: Vector2i) -> void:
	pos = p
	visible = state.town.building_at.has(p)
	refresh()


func selected() -> Dictionary:
	if not visible or not state.town.building_at.has(pos):
		return {}
	return state.town.buildings[state.town.building_at[pos]]


func _on_collect() -> void:
	if state.town.building_at.has(pos):
		state.town.haul(state.town.building_at[pos])
		refresh()


func _on_pause() -> void:
	if state.town.building_at.has(pos):
		var i: int = state.town.building_at[pos]
		state.set_paused(i, not state.town.buildings[i]["paused"])
		refresh()


func refresh() -> void:
	var b := selected()
	if b.is_empty():
		visible = false
		return
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	var tex := Art.building_sprite(b["type"])
	parts["icon"].texture = tex if tex != null else Ui.swatch_texture(def["color"])
	parts["name"].text = def["name"]
	var status: Label = parts["status"]
	status.text = b["status"]
	status.visible = b["status"] != def["desc"]  # a building with no status of its own says its blurb: show it once
	var col := Ui.TEXT
	if b["alert"] != "":
		col = Ui.SHORT
	elif b["status"].begins_with("Working") or b["status"].begins_with("Carrying"):
		col = Ui.GOOD
	status.add_theme_color_override("font_color", col)
	parts["desc"].text = def["desc"]
	parts["desc"].visible = def["kind"] not in ["gatherer", "processor"]  # what it gathers or makes says it better
	parts["focus"].show_for(b)
	parts["trade"].show_for(b)
	parts["recipe"].text = recipe_text(state, b)
	parts["recipe"].visible = parts["recipe"].text != ""
	parts["worker"].text = worker_text(state, b)
	parts["worker"].visible = Buildings.needs_worker(b)
	parts["pace"].text = pace_text(state, b)
	parts["pace"].visible = parts["pace"].text != ""
	parts["pace"].tooltip_text = Data.PACE_TIP % Work.text(state, b).replace("\n", "; ")
	parts["click"].text = click_text(state, b)
	parts["click"].visible = parts["click"].text != ""
	parts["click"].add_theme_color_override("font_color", Ui.TEXT)
	var held := Buildings.buffered(b["out"])
	parts["holding"].visible = Buildings.needs_worker(b)
	parts["bar"].visible = Buildings.needs_worker(b)
	parts["holding"].text = (
		Data.HOLDING % [held, Data.BUFFER_CAP] + ((": " + Ui.cost_text(b["out"])) if held > 0 else "")
	)
	parts["bar"].max_value = Data.BUFFER_CAP
	parts["bar"].value = held
	parts["trip"].text = trip_text(state, b["pos"])
	parts["trip_box"].visible = parts["trip"].text != ""
	var collect: Button = parts["collect"]
	collect.visible = held > 0
	collect.text = "Collect %d" % held
	var pause: Button = parts["pause"]
	pause.visible = Buildings.needs_worker(b)
	pause.text = "Resume" if b["paused"] else "Pause"


## "3 Fiber → 1 Rope / 4 s" for a workshop, what's in reach for a hut.
static func recipe_text(s: Sim, b: Dictionary) -> String:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	match def["kind"]:
		"processor":
			if def.get("trade", false) and not Buildings.is_trading(b):
				return ""
			var used := Buildings.recipe_in(b)
			var ins := Ui.cost_text(used) if not used.is_empty() else "nothing"
			var made := Buildings.recipe_out(b)
			return "%s → %s / %s s" % [ins, Ui.cost_text(made), str(snappedf(Work.time(s, b), 0.1))]
		"gatherer":
			return gather_text(s, s.town.focus_tiles(b), true)
	return ""


## What clicking the building does now: send a trip (before Paths & Haulers, or with no road link), or rush it.
static func click_text(s: Sim, b: Dictionary) -> String:
	if not Buildings.needs_worker(b):
		return ""
	var kind: String = Data.BUILDINGS[b["type"]]["kind"]
	if kind == "gatherer" and not Roads.automated(s, b):
		var hint: String = Data.TRIPS_HINT % [Data.PEOPLE["one"], b["trips"], Data.TRIP_QUEUE]
		if HutFocus.click_can_wait(s, b):
			hint = Data.TRIPS_FED % Data.PEOPLE["many"] + " " + hint
		return hint
	if b["rush_cd"] > 0.0:
		return Data.RUSH_COOL % ceili(b["rush_cd"])
	if Workers.can_rush(s, b):
		return Data.RUSH_HINT % int(Data.RUSH_COOLDOWN)
	return Data.RUSH_WAIT


## Who works here, in a sentence: "Aro the Woodcutter works here. Their flint tool has 32 uses left."
static func worker_text(s: Sim, b: Dictionary) -> String:
	if b["paused"]:
		return Data.WORKER_PAUSED % Data.PEOPLE["one"]
	if b["worker"] < 0:
		return Data.WORKER_NONE % Data.PEOPLE["one"]
	var k: Dictionary = s.people.kith[b["worker"]]
	var who: String = Data.WORKER_HERE % s.people.title_of(k)
	if Buildings.crew_size(b) > 1:
		var here := Buildings.crew_slots(b).filter(func(slot): return b[slot] >= 0).size()
		who += " " + Data.WORKER_CREW % [Buildings.crew_size(b), Data.PEOPLE["many"], here]
	if k["tool"] > 0:
		var tool_name: String = Data.ITEMS[Kith.tool_of(k)]["one"]
		return who + " " + Data.WORKER_TOOL % [tool_name.to_lower(), k["tool"]]
	for id in Data.TOOL_ITEMS:  # the best tool they could be given
		if Hands.recipe_unlocked(s, id):
			var one: String = Data.ITEMS[id]["one"]
			var share := roundi(Bonuses.tool_bonus(id) * 100.0)
			return who + " " + Data.WORKER_NO_TOOL % [one.to_lower(), Data.ITEMS[id]["name"], share]
	return who


## How fast it goes, in plain words (the exact numbers are the tooltip): what a trip brings back and how long the
## work takes, or what a workshop makes a minute, and what speeds it up.
static func pace_text(s: Sim, b: Dictionary) -> String:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if not def.has("time") or not Buildings.needs_worker(b):
		return ""
	var lines: Array = []
	if def["kind"] == "gatherer":
		var item: String = b["focus"]
		if item != "" and s.people.knows(item):
			lines.append(Data.PACE_TRIP % ("%d %s" % [Work.bundle_size(s, b, item), Data.ITEMS[item]["name"]]))
		lines.append(Data.PACE_WORK % str(snappedf(Work.time(s, b), 0.1)))
	else:
		var out := Buildings.recipe_out(b)
		if out.is_empty():
			return ""
		var made := 0
		for id in out:
			made += out[id]
		var per_min := 60.0 / Work.time(s, b) * made
		lines.append(
			Data.PACE_MAKES % [str(snappedf(per_min, 0.1)).trim_suffix(".0"), Data.ITEMS[out.keys()[0]]["name"]]
		)
	var boosts: Array = []
	for bonus in Bonuses.active(s, b, ""):
		if bonus["group"] == "speed":
			boosts.append("%s (+%d%%)" % [bonus["name"], roundi(bonus["add"] * 100.0)])
	if not boosts.is_empty():
		lines.append(Data.PACE_BOOST % ", ".join(boosts))
	return " ".join(lines)


## "To Hearth · 11 tiles · 22 s a trip", or "" for the Hearth itself.
static func trip_text(s: Sim, p: Vector2i) -> String:
	var info := s.people.trip_info(p)
	var depot: Vector2i = info["depot"]
	var where := "Hearth" if depot == s.world.camp_pos else "Storehouse"
	if not info["ok"]:
		return "No way to the %s: build a road or bridge" % where
	if info["tiles"] == 0:
		return ""
	return "To %s · %d tiles · %d s a trip" % [where, info["tiles"], roundi(info["seconds"])]


## "Gathers from the 3 highlighted tiles (within 2): Berries x3." `tiles` are the tiles of the one resource the hut
## works (Buildings.focus_tiles), the same ones the map highlights. `short` is the card's version, without the range.
static func gather_text(s: Sim, tiles: Array, short := false) -> String:
	var r := s.town.hut_radius()
	if tiles.is_empty():
		return "No resources within %d tiles: it would have nothing to gather (bare grass gives nothing)." % r
	var item: String = Data.TILES[s.world.tile_at(tiles[0])]["yields"]
	var known := ""
	if not s.people.knows(item):
		known = " (not learned yet)" if short else " not yet learned (gather by hand %dx)" % Hands.learn_needed(s)
	var what := "%s x%d%s" % [Data.ITEMS[item]["name"], tiles.size(), known]
	if short:
		return "Gathers from the %d highlighted tiles: %s." % [tiles.size(), what]
	return "Gathers from the %d highlighted tiles (within %d): %s." % [tiles.size(), r, what]
