extends PanelContainer
## The selection panel for a clicked building, anchored beside it on the map: status, what it does,
## its recipe or what it gathers, the worker and their tool, the speed math, what it holds, the trip
## to the stockpile, and Collect, Pause and Demolish buttons.

signal demolish_pressed(p: Vector2i)
signal closed

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Workers = preload("res://scripts/workers.gd")
const Hands = preload("res://scripts/hands.gd")

const WIDTH := 252.0
const INSET := Color("1b3a47")

var state: GameState
var pos := Vector2i(-1, -1)  # the selected building's tile
var parts := {}


func setup(game: GameState) -> void:
	state = game
	visible = false
	add_theme_stylebox_override("panel", Ui.panel_style(Ui.PANEL, 10))
	custom_minimum_size = Vector2(WIDTH, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
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
	close.custom_minimum_size = Vector2(24, 24)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)

	for key in ["desc", "recipe", "worker", "math", "click"]:
		parts[key] = _wrapped(12)
		v.add_child(parts[key])
	parts["math"].add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
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

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	v.add_child(buttons)
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


func _wrapped(font_size: int) -> Label:
	var l := Ui.label("", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(WIDTH - 60, 0)
	return l


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
	visible = state.building_at.has(p)
	refresh()


func selected() -> Dictionary:
	if not visible or not state.building_at.has(pos):
		return {}
	return state.buildings[state.building_at[pos]]


func _on_collect() -> void:
	if state.building_at.has(pos):
		state.haul(state.building_at[pos])
		refresh()


func _on_pause() -> void:
	if state.building_at.has(pos):
		var i: int = state.building_at[pos]
		state.set_paused(i, not state.buildings[i]["paused"])
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
	var col := Color.WHITE
	if b["alert"] != "":
		col = Color("ff9aa9")
	elif b["status"].begins_with("Working") or b["status"].begins_with("Carrying"):
		col = Ui.GOOD
	status.add_theme_color_override("font_color", col)
	parts["desc"].text = def["desc"]
	parts["recipe"].text = recipe_text(state, b)
	parts["recipe"].visible = parts["recipe"].text != ""
	parts["worker"].text = worker_text(state, b)
	parts["worker"].visible = state.needs_worker(b)
	parts["math"].text = Bonuses.text(state, b)
	parts["math"].visible = state.needs_worker(b) and parts["math"].text != ""
	parts["click"].text = click_text(state, b)
	parts["click"].visible = parts["click"].text != ""
	parts["click"].add_theme_color_override("font_color", Ui.HIGHLIGHT)
	var held := state.buffered(b["out"])
	parts["holding"].visible = state.needs_worker(b)
	parts["bar"].visible = state.needs_worker(b)
	parts["holding"].text = (
		"Holding %d / %d%s" % [held, Data.BUFFER_CAP, (": " + Ui.cost_text(b["out"])) if held > 0 else ""]
	)
	parts["bar"].max_value = Data.BUFFER_CAP
	parts["bar"].value = held
	parts["trip"].text = trip_text(state, b["pos"])
	parts["trip_box"].visible = parts["trip"].text != ""
	var collect: Button = parts["collect"]
	collect.visible = held > 0
	collect.text = "Collect %d" % held
	var pause: Button = parts["pause"]
	pause.visible = state.needs_worker(b)
	pause.text = "Resume" if b["paused"] else "Pause"
	var demolish: Button = parts["demolish"]
	demolish.disabled = def["kind"] == "camp"
	demolish.tooltip_text = (
		"The Hearth stays: it's the heart of the settlement."
		if def["kind"] == "camp"
		else "Tear it down for half its cost back (X)."
	)


## "3 Fiber → 1 Rope / 4 s" for a workshop, what's in reach for a hut.
static func recipe_text(s: GameState, b: Dictionary) -> String:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	match def["kind"]:
		"processor":
			var ins := Ui.cost_text(def["in"]) if not def["in"].is_empty() else "nothing"
			return "%s → %s / %s s" % [ins, Ui.cost_text(def["out"]), str(snappedf(s._work_time(b), 0.1))]
		"gatherer":
			return gather_text(s, s.gather_tiles(b["pos"]))
	return ""


## What clicking the building does now: send a trip (before Paths & Haulers), or rush it.
static func click_text(s: GameState, b: Dictionary) -> String:
	if not s.needs_worker(b):
		return ""
	var kind: String = Data.BUILDINGS[b["type"]]["kind"]
	if kind == "gatherer" and not s.has_haulers():
		var pips := ""
		for n in Data.TRIP_QUEUE:
			pips += "●" if n < b["trips"] else "○"
		return (
			"Trips %s  ·  click the hut to send its %s for a bundle (up to %d queued)"
			% [pips, Data.PEOPLE["one"], Data.TRIP_QUEUE]
		)
	if b["rush_cd"] > 0.0:
		return "Rush ready in %d s" % ceili(b["rush_cd"])
	if Workers.can_rush(s, b):
		return "Click to rush: finish this cycle now (then %d s to recover)" % int(Data.RUSH_COOLDOWN)
	return "Click to rush while it's working"


## "Worker: Aro the Woodcutter · Flint Tool, 32 jobs left".
static func worker_text(s: GameState, b: Dictionary) -> String:
	var job := Workers.building_job(s, b)
	if b["paused"]:
		return "Worker: no %s while paused" % job
	if b["worker"] < 0:
		return "Worker: no %s yet · waiting for a free %s" % [job, Data.PEOPLE["one"]]
	var k: Dictionary = s.kith[b["worker"]]
	var who := "Worker: " + Workers.title_of(s, k)
	if k["tool"] > 0:
		return who + " · Flint Tool, %d jobs left" % k["tool"]
	if Hands.recipe_unlocked(s, "flint_tools"):
		return who + " · no tool (craft Flint Tools: +50% speed)"
	return who


## "To Hearth · 11 tiles · 22 s a trip", or "" for the Hearth itself.
static func trip_text(s: GameState, p: Vector2i) -> String:
	var info := s.trip_info(p)
	var depot: Vector2i = info["depot"]
	var where := "Hearth" if depot == s.camp_pos else "Storehouse"
	if not info["ok"]:
		return "No way to the %s: build a road or bridge" % where
	if info["tiles"] == 0:
		return ""
	return "To %s · %d tiles · %d s a trip" % [where, info["tiles"], roundi(info["seconds"])]


## "Gathers from the 5 highlighted tiles (within 2), taking turns: Wood x3, Stone x2."
static func gather_text(s: GameState, tiles: Array) -> String:
	var r := s.hut_radius()
	if tiles.is_empty():
		return "No resources within %d tiles: it will cut grass for Fiber." % r
	var counts := {}
	for p in tiles:
		var item: String = Data.TILES[s.tile_at(p)]["yields"]
		counts[item] = counts.get(item, 0) + 1
	var out: Array = []
	for id in counts:
		var known := "" if s.knows(id) else " not yet learned (gather by hand %dx)" % Data.LEARN_CLICKS
		out.append("%s x%d%s" % [Data.ITEMS[id]["name"], counts[id], known])
	return "Gathers from the %d highlighted tiles (within %d), taking turns: %s." % [tiles.size(), r, ", ".join(out)]
