extends Node2D
## Draws the map in a flat, bold-outlined vector style and builds the UI in code.

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const Goals = preload("res://scripts/goals.gd")
const TechPanel = preload("res://scripts/tech_panel.gd")
const BuildBar = preload("res://scripts/build_bar.gd")
const TopBar = preload("res://scripts/top_bar.gd")
const Research = preload("res://scripts/research.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Rules = preload("res://scripts/rules.gd")
const Workers = preload("res://scripts/workers.gd")
const Roads = preload("res://scripts/roads.gd")
const Hands = preload("res://scripts/hands.gd")

const TILE := 32.0
const MAP_ORIGIN := Vector2.ZERO  # the node's transform scales and centers the map
const FIT_SETTLE_FRAMES := 3  # frames after a window resize while the bars settle to their new size
const OUTLINE: Color = Art.OUTLINE
const OUTLINE_W := 2.5
const KITH := Color("e76f51")
const SIDE_W := 290.0
const BAD := Color("ef476f")
const GOOD := Color("80ed99")
const GOAL_COLOR := Color("ffd166")
const FOG := Color("2c3834")
const LINE_TYPES := ["road", "bridge", "field"]  # laid by dragging
const AURA_FILL := Color(0.55, 0.45, 0.6, 0.2)

var fit_vp := Vector2.ZERO  # the window size the map was last fit to
var fit_bars := Vector2.ZERO  # the top and bottom bar heights the fit uses
var fit_settle := 0
var state: GameState
var placing := ""  # building type being placed, "" when not placing
var hover := Vector2i(-1, -1)
var drag_from := Vector2i(-1, -1)  # where a road, bridge or field drag started
var time := 0.0
var popups: Array = []  # {pos: Vector2, text: String, t: float}
var rubble: Array = []  # {pos: Vector2i, t: float}, torn-down buildings fading out

var goal_labels: Array = []
var goal_header: Label
var info_label: Label
var toast_label: Label
var toast_time := 0.0
var top_bar: TopBar
var bottom_bar: BuildBar
var side_panel: PanelContainer
var tech_panel: TechPanel
var building_panel: BuildingPanel
var win_overlay: Control
var ui_refresh := 0.0
var paused := false
var speed := 1  # simulation steps per frame: 1x, 2x or 3x
var holding := false  # the left button is down on a resource tile: hold to harvest


func _ready() -> void:
	state = GameState.new()
	state.generate(randi())
	_build_ui()
	_toast("The Kith make camp. Follow the goals on the right. Press T for the tech tree.", 6.0)


func _process(delta: float) -> void:
	time += delta
	if not paused:
		for i in speed:
			state.tick(delta)
	for e in state.events:
		if e == Data.BORN_EVENT % Data.PEOPLE["one"]:
			var at := Overlays.center(state.camp_pos) - Vector2(0, 12)
			popups.append({"pos": at, "text": "+1 Kith", "t": 0.0, "col": KITH.lightened(0.3)})
			_toast("New Kith arrive at the Hearth while food lasts", 2.5)
		else:
			_toast(e, 3.0)
	state.events.clear()
	if state.won and not win_overlay.visible:
		win_overlay.visible = true
	for p in popups:
		p["t"] += delta
	popups = popups.filter(func(p): return p["t"] < 1.2)
	for r in rubble:
		r["t"] += delta
	rubble = rubble.filter(func(r): return r["t"] < Overlays.RUBBLE_TIME)
	toast_time -= delta
	toast_label.modulate.a = clampf(toast_time, 0.0, 1.0)
	_layout()
	hover = _tile_under()
	_hold(delta)
	ui_refresh -= delta
	if ui_refresh <= 0.0:
		ui_refresh = 0.2
		_refresh_ui()
	queue_redraw()


## Fit the map between the bars and left of the side panel, scaled and centered. The fit follows the
## window size only: the bars keep steady heights (see TopBar._fix_width), and at one window size the
## fit uses the tallest each bar has been once the window settled, so a bar can never make the map
## jump back and forth. The scale is kept to steps of 1/64.
func _layout() -> void:
	var vp := get_viewport_rect().size
	if vp != fit_vp:
		fit_vp = vp
		fit_settle = FIT_SETTLE_FRAMES
	if fit_settle > 0:
		fit_settle -= 1
		fit_bars = Vector2(top_bar.size.y, bottom_bar.size.y)
	else:
		fit_bars = fit_bars.max(Vector2(top_bar.size.y, bottom_bar.size.y))
	var top := fit_bars.x
	var bottom := fit_bars.y
	side_panel.position = Vector2(vp.x - SIDE_W - 8, top + 8)
	side_panel.size = Vector2(SIDE_W, maxf(vp.y - top - bottom - 16, 100))
	var area := Rect2(8, top + 8, vp.x - SIDE_W - 24, vp.y - top - bottom - 16)
	var map_size := Vector2(GameState.WIDTH, GameState.HEIGHT) * TILE
	var k := maxf(floorf(minf(area.size.x / map_size.x, area.size.y / map_size.y) * 64.0) / 64.0, 0.1)
	scale = Vector2(k, k)
	position = (area.position + (area.size - map_size * k) / 2.0).round()
	if building_panel.visible:
		# Beside the selected building, kept on screen.
		var at := position + Overlays.center(building_panel.pos) * k
		var panel := building_panel.size
		var x := at.x + TILE * k * 0.7
		if x + panel.x > vp.x - SIDE_W - 16:
			x = at.x - TILE * k * 0.7 - panel.x
		building_panel.position = Vector2(
			clampf(x, 8, vp.x - panel.x - 8), clampf(at.y - panel.y / 2.0, top + 8, vp.y - bottom - panel.y - 8)
		)


# --- Input -------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_stop_holding()
		if drag_from.x >= 0:
			_lay_line()
	elif event is InputEventMouseButton and event.pressed:
		var p := _tile_under()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			placing = ""
			drag_from = Vector2i(-1, -1)
			building_panel.select(Vector2i(-1, -1))
		elif event.button_index == MOUSE_BUTTON_LEFT and state.in_bounds(p):
			if placing in LINE_TYPES:
				drag_from = p  # laid on release, with a preview while dragging
			else:
				_click_tile(p)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_T:
				tech_panel.visible = not tech_panel.visible
			KEY_SPACE:
				_set_speed(0)
			KEY_1, KEY_2, KEY_3:
				_set_speed(event.keycode - KEY_0)
			KEY_X:
				placing = "" if placing == "demolish" else "demolish"
			KEY_ESCAPE:
				placing = ""
				tech_panel.visible = false
				building_panel.select(Vector2i(-1, -1))


## 0 toggles pause; 1, 2 or 3 sets the speed and unpauses.
func _set_speed(v: int) -> void:
	if v == 0:
		paused = not paused
	else:
		speed = v
		paused = false
	_refresh_ui()


## The tiles the current drag covers, ending under the mouse (kept on the map).
func _drag_line() -> Array:
	var end := _tile_under().clamp(Vector2i.ZERO, Vector2i(GameState.WIDTH - 1, GameState.HEIGHT - 1))
	return Rules.line_tiles(drag_from, end)


## Release: lay the dragged road, bridge or fields on every tile that takes it.
func _lay_line() -> void:
	var line := _drag_line()
	drag_from = Vector2i(-1, -1)
	if placing not in LINE_TYPES:
		return
	var err := state.placement_error(placing, line[0])
	if state.place_line(placing, line) == 0 and err != "":
		_toast(err, 2.0)


func _tile_under() -> Vector2i:
	var local := (get_local_mouse_position() - MAP_ORIGIN) / TILE
	return Vector2i(floori(local.x), floori(local.y))


func _click_tile(p: Vector2i) -> void:
	if placing == "demolish":
		_demolish(p)
		return
	if placing != "":
		var err := state.placement_error(placing, p)
		if err == "":
			state.place(placing, p)
			if not state.can_afford(Data.BUILDINGS[placing]["cost"]):
				placing = ""
		else:
			_toast(err, 2.0)
		return
	if state.building_at.has(p):
		var note := Workers.click(state, state.building_at[p])
		if note != "":
			popups.append({"pos": _tile_center(p), "text": note, "t": 0.0})
		building_panel.select(p)
		return
	building_panel.select(Vector2i(-1, -1))
	if state.tile_at(p) == "shard" and state.fog.is_revealed(p):
		var first_look := not state.shard_seen
		_toast(state.gather_by_hand(p) + ("\nA new idea stirs in the tech tree: Star Lore." if first_look else ""), 8.0)
		return
	# Everything else is gathered by holding: _process fills the ring while the button stays down.
	state.release_harvest()
	holding = true


## Hold to harvest, each frame the button is down: over a Control (a bar, a panel) it doesn't count.
func _hold(delta: float) -> void:
	if not holding:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or placing != "":
		_stop_holding()
		return
	if get_viewport().gui_get_hovered_control() != null or not state.in_bounds(hover):
		state.release_harvest()
		return
	var msg := state.hold_harvest(hover, delta)
	if msg != "":
		popups.append({"pos": _tile_center(hover), "text": msg, "t": 0.0})


func _stop_holding() -> void:
	holding = false
	state.release_harvest()


## Tear down what's at p for half its cost back.
func _demolish(p: Vector2i) -> void:
	var type := state.built_type(p)
	if type == "":
		return
	if Data.BUILDINGS[type]["kind"] == "camp":
		_toast("The Hearth stays: it's the heart of the settlement.", 2.0)
		return
	var refund := state.demolish(p)
	rubble.append({"pos": p, "t": 0.0})
	if building_panel.pos == p:
		building_panel.select(Vector2i(-1, -1))
	popups.append(
		{"pos": _tile_center(p), "text": "+" + Ui.cost_text(refund) if not refund.is_empty() else "Cleared", "t": 0.0}
	)


# --- UI ----------------------------------------------------------------------


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Top bar: Kith, food, and every good with its rate.
	top_bar = TopBar.new()
	layer.add_child(top_bar)
	top_bar.setup(state)
	top_bar.speed_picked.connect(_set_speed)

	# Bottom bar: tabs of fixed-size build buttons, Demolish and Craft.
	bottom_bar = BuildBar.new()
	layer.add_child(bottom_bar)
	bottom_bar.setup(state)
	bottom_bar.build_picked.connect(func(type): placing = "" if placing == type else type)
	bottom_bar.craft_picked.connect(func(r): Hands.craft(state, r))
	bottom_bar.tech_pressed.connect(func(): tech_panel.visible = not tech_panel.visible)
	bottom_bar.demolish_pressed.connect(func(): placing = "" if placing == "demolish" else "demolish")

	_build_side_panel(layer)

	building_panel = BuildingPanel.new()
	layer.add_child(building_panel)
	building_panel.setup(state)
	building_panel.demolish_pressed.connect(_demolish)
	building_panel.closed.connect(func(): building_panel.select(Vector2i(-1, -1)))

	# Toasts, centered under the top bar.
	toast_label = Ui.label("", 17)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -500
	toast_label.offset_right = 500
	toast_label.offset_top = 56
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	toast_label.add_theme_color_override("font_outline_color", OUTLINE)
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(toast_label)

	tech_panel = TechPanel.new()
	layer.add_child(tech_panel)
	tech_panel.setup(state)
	_build_win_overlay(layer)


## Goals checklist on top, and details about whatever the mouse is over below it.
func _build_side_panel(layer: CanvasLayer) -> void:
	side_panel = PanelContainer.new()
	side_panel.add_theme_stylebox_override("panel", Ui.panel_style(Color("264653"), 12))
	layer.add_child(side_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	side_panel.add_child(v)
	goal_header = Ui.label("Goals", 18)
	v.add_child(goal_header)
	for i in 4:
		var g := Ui.label("", 14)
		g.autowrap_mode = TextServer.AUTOWRAP_WORD
		g.custom_minimum_size = Vector2(SIDE_W - 30, 0)
		v.add_child(g)
		goal_labels.append(g)
	v.add_child(HSeparator.new())
	v.add_child(Ui.label("Info", 18))
	info_label = Ui.label("", 14)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_label.custom_minimum_size = Vector2(SIDE_W - 30, 0)
	v.add_child(info_label)


func _build_win_overlay(layer: CanvasLayer) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.05, 0.08, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	layer.add_child(overlay)
	win_overlay = overlay
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -300
	v.offset_right = 300
	v.offset_top = -80
	win_overlay.add_child(v)
	var title := Ui.label("BRONZE DAWN", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := Ui.label("The stone age ends. The next era begins.\nFar above Solace, something is falling.", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)


func _refresh_ui() -> void:
	top_bar.refresh(paused, speed)
	bottom_bar.refresh(placing, Research.ready_list(state).size())
	tech_panel.refresh()
	building_panel.refresh()

	var cur := Goals.current_goal(state)
	goal_header.text = "Goals (%d/%d)" % [mini(cur, Data.GOALS.size()), Data.GOALS.size()]
	for i in goal_labels.size():
		var gi := cur - 1 + i
		var l: Label = goal_labels[i]
		l.visible = gi >= 0 and gi < Data.GOALS.size()
		if not l.visible:
			continue
		var done: bool = state.goals_done.has(Data.GOALS[gi]["id"])
		l.text = ("Done: " if done else ("> " if gi == cur else "  ")) + Data.GOALS[gi]["text"]
		var col := GOOD if done else (GOAL_COLOR if gi == cur else Color(1, 1, 1, 0.55))
		l.add_theme_color_override("font_color", col)
	if cur >= Data.GOALS.size():
		goal_labels[1].visible = true
		goal_labels[1].text = "All goals done."
	info_label.text = _hover_text()
	var item := _hover_item()
	top_bar.set_click_hint(hold_hint(item) if item != "" else "")


func _hover_text() -> String:
	if placing == "demolish":
		return "Demolish: click a building, road or field to tear it down for half its cost back. Right-click to stop."
	if placing != "":
		var def: Dictionary = Data.BUILDINGS[placing]
		var s := "Placing %s. Left-click open grassland, right-click to stop." % def["name"]
		if def["kind"] in ["road", "bridge", "field"]:
			s = "Laying %s: click, or drag and release to lay a line. Right-click to stop." % def["name"]
		s += "\nCost: " + (_progress(def["cost"], 99) if not def["cost"].is_empty() else "free")
		if state.in_bounds(hover):
			var err := state.placement_error(placing, hover)
			if err != "":
				s += "\n\nCan't build here: " + err + "."
			if placing == "gatherers_hut":
				s += "\n\n" + BuildingPanel.gather_text(state, state.gather_tiles(hover))
			if state.has_haulers() and Data.BUILDINGS[placing]["kind"] in ["gatherer", "processor"]:
				s += "\n" + _road_preview(hover)
		return s
	if not state.in_bounds(hover):
		return "Point at the map to see what's there."
	if not state.fog.is_revealed(hover):
		return "Unexplored. Build nearby to see it."
	var who := _kith_here(hover)
	return (who + "\n\n" if who != "" else "") + _tile_text()


## Whether a building placed at p would be linked by road, and if not, how far the road has to go.
func _road_preview(p: Vector2i) -> String:
	var g := Roads.gap(state, p)
	if g["to"].x < 0:
		return "Road: linked here, haulers will carry for it."
	return "Needs road: no road touches here. Lay about %d tiles of Road to link it." % g["tiles"]


## "Aro the Woodcutter, Tam the Hauler" for the Kith standing on or walking through tile p.
func _kith_here(p: Vector2i) -> String:
	var names: Array = []
	for k in state.kith:
		var at: Vector2 = k["pos"]
		if Vector2i(roundi(at.x), roundi(at.y)) == p:
			names.append(Workers.title_of(state, k))
	return ", ".join(names)


## What's on the hovered tile: a building, a road, a resource or open ground.
func _tile_text() -> String:
	if state.building_at.has(hover):
		var b: Dictionary = state.buildings[state.building_at[hover]]
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		var s: String = def["name"] + "\n" + def["desc"] + "\n\nStatus: " + b["status"]
		if state.needs_worker(b):
			s += "\n" + BuildingPanel.worker_text(state, b)
			s += "\n" + Bonuses.text(state, b)
		if state.buffered(b["out"]) > 0:
			s += "\nHolding " + Ui.cost_text(b["out"])
		if def["kind"] == "gatherer":
			s += "\n\n" + BuildingPanel.gather_text(state, state.gather_tiles(hover))
		if state.has_haulers() and state.needs_worker(b):
			s += (
				"\n"
				+ (
					"Road: linked, haulers carry for it"
					if Roads.linked(state, b)
					else "Needs road: " + Workers.road_hint(state, hover)
				)
			)
		var click := BuildingPanel.click_text(state, b)
		return s + "\n\n" + (click + "\n" if click != "" else "") + "Click for its panel."
	var t: Dictionary = Data.TILES[state.tile_at(hover)]
	if state.roads.has(hover):
		if state.tile_at(hover) == "river":
			return "Wooden Bridge. Kith and haulers cross the river here."
		return "Road on %s. Kith walk twice as fast here." % t["name"]
	var hint := Overlays.blocked_hint(state, hover)
	if t["yields"] != "":
		var item: String = t["yields"]
		var s := "%s\n%s. Hold the mouse on it to gather." % [t["name"], hold_hint(item)]
		if Data.FOOD_VALUE.has(item):
			s += " It's food: the %s eat it." % Data.PEOPLE["many"]
		s += "\n" + learn_text(item)
		return s + ("\n" + hint + "." if hint != "" else "")
	return t["name"] + ("\n" + hint + "." if hint != "" else "")


## "Hold: +3 Wood, 0.7s".
func hold_hint(item: String) -> String:
	var secs := str(snappedf(Hands.hold_time(state, item), 0.1))
	return "Hold: +%d %s, %ss" % [state.harvest_yield(item), Data.ITEMS[item]["name"], secs]


## How far a Kith is from learning to gather `item` by watching you.
func learn_text(item: String) -> String:
	var item_name: String = Data.ITEMS[item]["name"]
	if state.knows(item):
		return "%s knows how to gather %s: huts can gather it." % [state.learned[item], item_name]
	return (
		"Harvested by hand %d/%d. A %s is watching and will learn %s."
		% [state.hand_counts.get(item, 0), Data.LEARN_CLICKS, Data.PEOPLE["one"], item_name]
	)


## The tile under the mouse gives this when clicked, or "" if it isn't a resource you can see.
func _hover_item() -> String:
	if placing != "" or not state.in_bounds(hover) or not state.fog.is_revealed(hover):
		return ""
	if state.building_at.has(hover) or state.roads.has(hover) or state.tile_at(hover) == "":
		return ""
	return Data.TILES[state.tile_at(hover)]["yields"]


func _progress(cost: Dictionary, limit: int) -> String:
	return Ui.progress_text(state.inv, cost, limit)


func _toast(text: String, seconds: float) -> void:
	toast_label.text = text
	toast_time = seconds


# --- Drawing -----------------------------------------------------------------


func _tile_rect(p: Vector2i) -> Rect2:
	return Rect2(MAP_ORIGIN + Vector2(p) * TILE, Vector2(TILE, TILE))


func _tile_center(p: Vector2i) -> Vector2:
	return MAP_ORIGIN + (Vector2(p) + Vector2(0.5, 0.5)) * TILE


func _draw() -> void:
	# Ground.
	for y in GameState.HEIGHT:
		for x in GameState.WIDTH:
			var p := Vector2i(x, y)
			var t := state.tile_at(p)
			var base: Color = (
				Data.TILES["grass"]["color"]
				if t in ["tree", "rock", "berry", "grain", "flax", "shard"]
				else Data.TILES[t]["color"]
			)
			if (x + y) % 2 == 0:
				base = base.lightened(0.04)
			draw_rect(_tile_rect(p), base)
	var map_rect := Rect2(MAP_ORIGIN, Vector2(GameState.WIDTH, GameState.HEIGHT) * TILE)
	draw_rect(map_rect, OUTLINE, false, 4.0)
	_draw_roads()

	# Features.
	for y in GameState.HEIGHT:
		for x in GameState.WIDTH:
			var p := Vector2i(x, y)
			Art.feature(self, state.tile_at(p), _tile_center(p), p, time)

	# Ranges: a hut's gathering tiles, power range for wheels, Standing Stone reach.
	var hovered_type := ""
	if state.building_at.has(hover):
		hovered_type = state.buildings[state.building_at[hover]]["type"]
	if state.in_bounds(hover) and (placing == "gatherers_hut" or (placing == "" and hovered_type == "gatherers_hut")):
		_draw_gather_range(hover)
	if placing == "water_wheel" and state.in_bounds(hover):
		draw_circle(_tile_center(hover), Data.BUILDINGS["water_wheel"]["radius"] * TILE, Color(0.16, 0.62, 0.56, 0.18))
	if placing == "grindstone" or hovered_type in ["water_wheel", "grindstone"]:
		for b in state.buildings:
			if b["type"] == "water_wheel":
				draw_circle(
					_tile_center(b["pos"]),
					Data.BUILDINGS["water_wheel"]["radius"] * TILE,
					Color(0.16, 0.62, 0.56, 0.18)
				)
	_draw_aura_ranges(hovered_type)
	Overlays.settlement_ring(self, state, placing == "dwelling")
	for b in state.buildings:
		_draw_building(b)
	Overlays.rubble(self, rubble)
	var sel := building_panel.selected()
	if not sel.is_empty():
		draw_rect(_tile_rect(sel["pos"]).grow(1), GOAL_COLOR, false, 3.0)
		if sel["type"] == "gatherers_hut" and placing == "":
			_draw_gather_range(sel["pos"])
		Overlays.flow_arrows(self, state, sel, time)
	_draw_kith()
	_draw_fog()
	Overlays.status_pills(self, state)

	# Placement ghost.
	if placing == "demolish" and state.in_bounds(hover):
		Overlays.demolish_hover(self, state, hover)
	elif placing in LINE_TYPES and drag_from.x >= 0:
		Overlays.line_ghost(self, state, placing, _drag_line())
	elif placing != "" and state.in_bounds(hover):
		var note := ""
		if Data.BUILDINGS[placing]["kind"] in ["gatherer", "processor"]:
			note = BuildingPanel.trip_text(state, hover)
		elif placing == "road" and state.tile_at(hover) == "rock":
			note = "Cut a pass · %s" % Ui.cost_text(Data.PASS_COST)
		Overlays.placement_ghost(self, state, placing, hover, note)
	elif state.in_bounds(hover) and not state.fog.is_revealed(hover):
		var fr := _tile_rect(hover)
		Art.dashed_rect(self, fr.grow(-1), Color(1, 1, 1, 0.6), 2.0, 5.0, 4.0)
		Art.pill(
			self, Vector2(fr.get_center().x, fr.end.y + 4), "Unexplored · build nearby to see", Color.WHITE, OUTLINE, 12
		)
	elif state.in_bounds(hover) and state.fog.is_revealed(hover) and Overlays.blocked_hint(state, hover) != "":
		draw_rect(_tile_rect(hover).grow(-1), Color(1, 1, 1, 0.8), false, 2.0)
		var r := _tile_rect(hover)
		Art.pill(
			self, Vector2(r.get_center().x, r.end.y + 4), Overlays.blocked_hint(state, hover), Color.WHITE, OUTLINE, 12
		)
	elif state.in_bounds(hover):
		draw_rect(_tile_rect(hover).grow(-1), Color(1, 1, 1, 0.8), false, 2.0)
		var item := _hover_item()
		if item != "":
			var hr := _tile_rect(hover)
			var tag := hold_hint(item)
			if not state.knows(item):
				tag += "  ·  taught %d/%d" % [state.hand_counts.get(item, 0), Data.LEARN_CLICKS]
			Art.pill(self, Vector2(hr.get_center().x, hr.end.y + 4), tag, Color.WHITE, OUTLINE, 12)

	_draw_hold_ring()
	if paused:
		Art.pill(self, Vector2(GameState.WIDTH * TILE / 2.0, 8), "Paused · Space to resume", GOAL_COLOR, OUTLINE, 16)

	var font := ThemeDB.fallback_font
	for pop in popups:
		var pos: Vector2 = pop["pos"] + Vector2(-20, -10 - pop["t"] * 30)
		var a: float = 1.0 - pop["t"] / 1.2
		draw_string_outline(font, pos, pop["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 5, Color(OUTLINE, a))
		var col: Color = pop.get("col", Color.WHITE)
		draw_string(font, pos, pop["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(col, a))


## Unexplored tiles: nearly opaque, with a softer edge next to explored ground.
func _draw_fog() -> void:
	for y in GameState.HEIGHT:
		for x in GameState.WIDTH:
			var p := Vector2i(x, y)
			if state.fog.is_revealed(p):
				continue
			var edge := false
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				edge = edge or state.fog.is_revealed(p + n)
			draw_rect(_tile_rect(p), Color(FOG, 0.55 if edge else 0.94))


## A Standing Stone's reach: under the cursor while placing one, around each one while hovering one.
func _draw_aura_ranges(hovered_type: String) -> void:
	var radius: float = Data.BUILDINGS["standing_stone"]["radius"] * TILE
	if placing == "standing_stone" and state.in_bounds(hover):
		draw_circle(_tile_center(hover), radius, AURA_FILL)
	if hovered_type == "standing_stone":
		for b in state.buildings:
			if b["type"] == "standing_stone":
				draw_circle(_tile_center(b["pos"]), radius, AURA_FILL)


## Outline the hut's reach and light up the tiles it would gather from.
func _draw_gather_range(p: Vector2i) -> void:
	var r := state.hut_radius()
	var reach := Rect2(MAP_ORIGIN + Vector2(p - Vector2i(r, r)) * TILE, Vector2.ONE * (2 * r + 1) * TILE)
	draw_rect(reach, Color(1, 0.82, 0.4, 0.12))
	draw_rect(reach, GOAL_COLOR, false, 2.0)
	for t in state.gather_tiles(p):
		draw_rect(_tile_rect(t).grow(-3), Color(1, 0.82, 0.4, 0.35))
		draw_rect(_tile_rect(t).grow(-3), GOAL_COLOR, false, 2.0)


func _draw_building(b: Dictionary) -> void:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	var p: Vector2i = b["pos"]
	var r := _tile_rect(p).grow(-2)
	var c := r.get_center()
	var working: bool = b["status"] == "Working"

	# Base plate in Kith color, like a unit on a game board.
	draw_rect(r, KITH.darkened(0.15))
	draw_rect(r, OUTLINE, false, OUTLINE_W)

	Art.building(self, b["type"], c, working, time)

	# Progress bar and held output.
	if def.has("time") and working:
		var frac := state.progress_frac(b)
		draw_rect(Rect2(r.position + Vector2(2, r.size.y - 5), Vector2((r.size.x - 4) * frac, 3)), Color("ffd166"))
	var held := state.buffered(b["out"])
	if held > 0:
		var badge := r.position + Vector2(r.size.x - 2, 2)
		Art.outlined_circle(self, badge, 7.0, Color("ffd166") if held < Data.BUFFER_CAP else Color("ef476f"))
		draw_string(
			ThemeDB.fallback_font,
			badge + Vector2(-4 if held < 10 else -7, 4),
			str(held),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			OUTLINE
		)
	_draw_trips(b, r)
	_draw_rush(b, r)
	if b["status"].begins_with("Hungry") or b["status"].begins_with("No power"):
		draw_string(
			ThemeDB.fallback_font, r.position + Vector2(-2, 10), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ef476f")
		)


## Hold to harvest: an outline ring over the held tile, with a highlight arc filling clockwise from the top.
func _draw_hold_ring() -> void:
	if not holding or not state.in_bounds(state.harvest_tile) or Hands.item_at(state, state.harvest_tile) == "":
		return
	var c := _tile_center(state.harvest_tile)
	var radius := TILE * 0.42
	draw_arc(c, radius, 0.0, TAU, 40, OUTLINE, 7.0, true)
	draw_arc(c, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.3), 3.0, true)
	if state.harvest_frac > 0.0:
		var to := -PI / 2.0 + TAU * state.harvest_frac
		draw_arc(c, radius, -PI / 2.0, to, maxi(4, int(40 * state.harvest_frac)), GOAL_COLOR, 4.0, true)


## A hut that hauls by clicks (before Paths & Haulers, or with no road link) shows its trip queue as
## pips along the top: gold for each queued trip.
func _draw_trips(b: Dictionary, r: Rect2) -> void:
	if Data.BUILDINGS[b["type"]]["kind"] != "gatherer" or Roads.automated(state, b):
		return
	for n in Data.TRIP_QUEUE:
		var c := r.position + Vector2(r.size.x / 2.0 + (n - (Data.TRIP_QUEUE - 1) / 2.0) * 8.0, -3.0)
		draw_circle(c, 3.6, OUTLINE)
		draw_circle(c, 2.4, GOAL_COLOR if n < b["trips"] else Color(1, 1, 1, 0.35))


## A rushed building shows its cooldown as a shrinking wedge in its top-left corner.
func _draw_rush(b: Dictionary, r: Rect2) -> void:
	if b["rush_cd"] <= 0.0:
		return
	var c := r.position + Vector2(5, 5)
	var frac: float = b["rush_cd"] / Data.RUSH_COOLDOWN
	draw_circle(c, 5.5, OUTLINE)
	draw_circle(c, 4.0, Color(1, 1, 1, 0.3))
	var pts := PackedVector2Array([c])
	for n in 13:
		pts.append(c + Vector2.from_angle(-PI / 2.0 + TAU * frac * n / 12.0) * 4.0)
	if frac > 0.02:
		draw_colored_polygon(pts, GOAL_COLOR)


## Each Kith is a small figure; haulers and hut workers show what they carry.
func _draw_kith() -> void:
	for i in state.kith.size():
		var k: Dictionary = state.kith[i]
		var c: Vector2 = MAP_ORIGIN + (k["pos"] + Vector2(0.5, 0.5)) * TILE
		if k["path"].is_empty():
			c += Vector2.from_angle(i * 2.4) * 9.0  # spread out anyone standing around
		if k["job"] == "work" and k["phase"] != "to_site" and k["path"].is_empty() and k["phase"] != "harvest":
			continue  # inside their building
		var bob := sin(time * 12.0 + c.x) * 1.5 if not k["path"].is_empty() else 0.0
		c += Vector2(0, bob)
		Art.outlined_circle(self, c, 5.0, KITH.lightened(0.25) if k["job"] == "haul" else KITH)
		for id in k["carry"]:
			draw_rect(Rect2(c + Vector2(-4, -13), Vector2(8, 7)), Data.ITEMS[id]["color"])
			draw_rect(Rect2(c + Vector2(-4, -13), Vector2(8, 7)), OUTLINE, false, 1.5)


func _draw_roads() -> void:
	var dirt := Data.BUILDINGS["road"]["color"]
	for p in state.roads:
		var c := _tile_center(p)
		if state.tile_at(p) == "river":
			var bridge := Art.sprite("tile_bridge_wood")
			if bridge != null:
				draw_texture_rect(bridge, _tile_rect(p), false)
				continue
			draw_rect(_tile_rect(p).grow_individual(0, -5, 0, -5), Color("8d6e63"))
			for i in 4:
				var x := _tile_rect(p).position.x + 4 + i * 8
				draw_line(Vector2(x, c.y - 11), Vector2(x, c.y + 11), OUTLINE, 1.5)
			continue
		draw_circle(c, 8.0, dirt)
		for n in GameState.NEIGHBORS:
			if state.roads.has(p + n) or state.building_at.has(p + n):
				var half := Vector2(n) * TILE * 0.5
				var w := Vector2(absf(n.y), absf(n.x)) * 8.0
				draw_colored_polygon(PackedVector2Array([c - w, c + w, c + half + w, c + half - w]), dirt)
