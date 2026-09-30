extends PanelContainer
## The selected building's details, docked in the side panel's Info section (never floating over the map, so
## it can't cover the tiles you want next): status, what it does, its recipe or what it gathers, the worker and
## their tool in plain words (the exact numbers are in a tooltip), what it holds, the trip to the stockpile, and
## Collect, Pause and Demolish buttons, with an x to close it.

signal demolish_pressed(p: Vector2i)
signal closed

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Workers = preload("res://scripts/workers.gd")
const Roads = preload("res://scripts/roads.gd")
const Hands = preload("res://scripts/hands.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Work = preload("res://scripts/work.gd")
const HutFocus = preload("res://scripts/hut_focus.gd")

const INSET := Color("1b3a47")

var state: Sim
var pos := Vector2i(-1, -1)  # the selected building's tile
var parts := {}


func setup(game: Sim) -> void:
	state = game
	visible = false
	add_theme_stylebox_override("panel", Ui.panel_style(Ui.PANEL, 8))
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
	parts["name"] = Ui.label("", 15)
	names.add_child(parts["name"])
	parts["status"] = _wrapped(11)
	names.add_child(parts["status"])
	var close := Ui.button("x")
	close.custom_minimum_size = Vector2(28, 28)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.tooltip_text = Data.CLOSE_TIP
	close.add_theme_stylebox_override("normal", _x_style(Ui.BAR))
	close.add_theme_stylebox_override("hover", _x_style(Ui.BAD.darkened(0.3)))
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)

	for key in ["desc", "recipe", "worker", "pace", "click"]:
		parts[key] = _wrapped(12)
		v.add_child(parts[key])
	parts["pace"].add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	parts["pace"].mouse_filter = Control.MOUSE_FILTER_STOP  # its tooltip has the exact numbers
	var focus := HutFocus.new()  # what a hut works: one line, one click to change (scripts/hut_focus.gd)
	focus.setup(game)
	focus.changed.connect(refresh)
	v.add_child(focus)
	v.move_child(focus, parts["recipe"].get_index())
	parts["focus"] = focus
	parts["holding"] = Ui.label("", 12)
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
	parts["trip"] = _wrapped(12)
	trip.add_child(parts["trip"])
	v.add_child(trip)

	# The buttons are docked under the scrolling Info area (SidePanel moves them there), so they never scroll out of reach.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	v.add_child(buttons)
	parts["buttons"] = buttons
	visibility_changed.connect(_sync_buttons)
	var collect := _button("Collect", Ui.HIGHLIGHT, Ui.HIGHLIGHT)
	collect.add_theme_color_override("font_color", Art.OUTLINE)
	collect.pressed.connect(_on_collect)
	buttons.add_child(collect)
	parts["collect"] = collect
	var pause := _button("Pause", Ui.BAR, Color.WHITE)
	pause.pressed.connect(_on_pause)
	buttons.add_child(pause)
	parts["pause"] = pause
	var demolish := _button("Demolish", Ui.BAR, Ui.BAD)
	demolish.pressed.connect(func(): demolish_pressed.emit(pos))
	buttons.add_child(demolish)
	parts["demolish"] = demolish


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
	var col := Color.WHITE
	if b["alert"] != "":
		col = Color("ff9aa9")
	elif b["status"].begins_with("Working") or b["status"].begins_with("Carrying"):
		col = Ui.GOOD
	status.add_theme_color_override("font_color", col)
	parts["desc"].text = def["desc"]
	parts["desc"].visible = def["kind"] not in ["gatherer", "processor"]  # what it gathers or makes says it better
	parts["focus"].show_for(b)
	parts["recipe"].text = recipe_text(state, b)
	parts["recipe"].visible = parts["recipe"].text != ""
	parts["worker"].text = worker_text(state, b)
	parts["worker"].visible = Buildings.needs_worker(b)
	parts["pace"].text = pace_text(state, b)
	parts["pace"].visible = parts["pace"].text != ""
	parts["pace"].tooltip_text = Data.PACE_TIP % Work.text(state, b).replace("\n", "; ")
	parts["click"].text = click_text(state, b)
	parts["click"].visible = parts["click"].text != ""
	parts["click"].add_theme_color_override("font_color", Ui.HIGHLIGHT)
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
	var demolish: Button = parts["demolish"]
	demolish.disabled = def["kind"] == "camp"
	demolish.tooltip_text = (
		"The Hearth stays: it's the heart of the settlement."
		if def["kind"] == "camp"
		else "Tear it down for half its cost back (X)."
	)


## "3 Fiber → 1 Rope / 4 s" for a workshop, what's in reach for a hut.
static func recipe_text(s: Sim, b: Dictionary) -> String:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	match def["kind"]:
		"processor":
			var ins := Ui.cost_text(def["in"]) if not def["in"].is_empty() else "nothing"
			return "%s → %s / %s s" % [ins, Ui.cost_text(def["out"]), str(snappedf(Work.time(s, b), 0.1))]
		"gatherer":
			return gather_text(s, s.town.gather_tiles(b["pos"]), b["focus"], true)
	return ""


## What clicking the building does now: send a trip (before Paths & Haulers, or with no road link), or rush it.
static func click_text(s: Sim, b: Dictionary) -> String:
	if not Buildings.needs_worker(b):
		return ""
	var kind: String = Data.BUILDINGS[b["type"]]["kind"]
	if kind == "gatherer" and not Roads.automated(s, b):
		return Data.TRIPS_HINT % [Data.PEOPLE["one"], b["trips"], Data.TRIP_QUEUE]
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
	if k["tool"] > 0:
		return who + " " + Data.WORKER_TOOL % k["tool"]
	if Hands.recipe_unlocked(s, "flint_tools"):
		return who + " " + Data.WORKER_NO_TOOL % roundi(Data.BONUSES["tools"]["add"] * 100.0)
	return who


## How fast it goes, in plain words (the exact numbers are the tooltip): what a trip brings back and how long the
## work takes, or what a workshop makes a minute, and what speeds it up.
static func pace_text(s: Sim, b: Dictionary) -> String:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if not def.has("time") or not Buildings.needs_worker(b):
		return ""
	var lines: Array = []
	if def["kind"] == "gatherer":
		var bundles: Array = []
		var seen := {}
		for item in b["gather_items"]:
			if not seen.has(item) and s.people.knows(item):
				seen[item] = true
				bundles.append("%d %s" % [Work.bundle_size(s, b, item), Data.ITEMS[item]["name"]])
		if not bundles.is_empty():
			lines.append(Data.PACE_TRIP % ", ".join(bundles))
		lines.append(Data.PACE_WORK % str(snappedf(Work.time(s, b), 0.1)))
	else:
		var made := 0
		for id in def["out"]:
			made += def["out"][id]
		var per_min := 60.0 / Work.time(s, b) * made
		lines.append(
			Data.PACE_MAKES % [str(snappedf(per_min, 0.1)).trim_suffix(".0"), Data.ITEMS[def["out"].keys()[0]]["name"]]
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


## "Gathers from the 5 highlighted tiles (within 2), taking turns: Wood x3, Stone x2." `short` is the card's version:
## "Gathers from the 5 highlighted tiles: Wood x3, Stone x2 (not learned yet)." `focus` is the resource the hut
## works ("" to leave that out): "... It works only Wood."
static func gather_text(s: Sim, tiles: Array, focus := "", short := false) -> String:
	var r := s.town.hut_radius()
	if tiles.is_empty():
		return "No resources within %d tiles: it would have nothing to gather (bare grass gives nothing)." % r
	var counts := {}
	for p in tiles:
		var item: String = Data.TILES[s.world.tile_at(p)]["yields"]
		counts[item] = counts.get(item, 0) + 1
	var out: Array = []
	for id in counts:
		var known := ""
		if not s.people.knows(id):
			known = " (not learned yet)" if short else " not yet learned (gather by hand %dx)" % Data.LEARN_CLICKS
		out.append("%s x%d%s" % [Data.ITEMS[id]["name"], counts[id], known])
	var line := "Gathers from the %d highlighted tiles: %s." % [tiles.size(), ", ".join(out)]
	if not short:
		line = "Gathers from the %d highlighted tiles (within %d): %s." % [tiles.size(), r, ", ".join(out)]
	if focus != "":
		line += " It works only %s." % Data.ITEMS[focus]["name"]
	return line
