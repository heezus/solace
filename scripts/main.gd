extends Node2D
## Draws the map in a flat, bold-outlined vector style and builds the UI in code.

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")

const TILE := 32.0
const MAP_ORIGIN := Vector2.ZERO  # the node's transform scales and centers the map
const OUTLINE := Color("1b1b1f")
const OUTLINE_W := 2.5
const KITH := Color("e76f51")
const SIDE_W := 290.0
const BAD := Color("ef476f")
const GOOD := Color("80ed99")
const GOAL_COLOR := Color("ffd166")

var state: GameState
var placing := ""  # building type being placed, "" when not placing
var hover := Vector2i(-1, -1)
var time := 0.0
var popups: Array = []  # {pos: Vector2, text: String, t: float}

var item_boxes := {}
var item_labels := {}
var food_label: Label
var kith_label: Label
var build_buttons := {}
var craft_buttons := {}
var tech_cards := {}
var goal_labels: Array = []
var goal_header: Label
var info_label: Label
var toast_label: Label
var toast_time := 0.0
var top_bar: PanelContainer
var bottom_bar: PanelContainer
var side_panel: PanelContainer
var tech_panel: PanelContainer
var win_overlay: Control
var ui_refresh := 0.0


func _ready() -> void:
	state = GameState.new()
	state.generate(randi())
	_build_ui()
	_toast("The Kith make camp. Follow the goals on the right. Press T for the tech tree.", 6.0)


func _process(delta: float) -> void:
	time += delta
	state.tick(delta)
	for e in state.events:
		_toast(e, 3.0)
	state.events.clear()
	if state.won and not win_overlay.visible:
		win_overlay.visible = true
	for p in popups:
		p["t"] += delta
	popups = popups.filter(func(p): return p["t"] < 1.2)
	toast_time -= delta
	toast_label.modulate.a = clampf(toast_time, 0.0, 1.0)
	_layout()
	hover = _tile_under()
	ui_refresh -= delta
	if ui_refresh <= 0.0:
		ui_refresh = 0.2
		_refresh_ui()
	queue_redraw()


## Fit the map between the bars and left of the side panel, scaled and centered.
func _layout() -> void:
	var vp := get_viewport_rect().size
	var top := top_bar.size.y
	var bottom := bottom_bar.size.y
	side_panel.position = Vector2(vp.x - SIDE_W - 8, top + 8)
	side_panel.size = Vector2(SIDE_W, maxf(vp.y - top - bottom - 16, 100))
	var area := Rect2(8, top + 8, vp.x - SIDE_W - 24, vp.y - top - bottom - 16)
	var map_size := Vector2(GameState.WIDTH, GameState.HEIGHT) * TILE
	var k := maxf(minf(area.size.x / map_size.x, area.size.y / map_size.y), 0.1)
	scale = Vector2(k, k)
	position = (area.position + (area.size - map_size * k) / 2.0).round()


# --- Input -------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and placing == "road" and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var p := _tile_under()
		if state.placement_error("road", p) == "":
			state.place("road", p)
	elif event is InputEventMouseButton and event.pressed:
		var p := _tile_under()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			placing = ""
		elif event.button_index == MOUSE_BUTTON_LEFT and state.in_bounds(p):
			_click_tile(p)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_T:
				tech_panel.visible = not tech_panel.visible
			KEY_ESCAPE:
				placing = ""
				tech_panel.visible = false


func _tile_under() -> Vector2i:
	var local := (get_local_mouse_position() - MAP_ORIGIN) / TILE
	return Vector2i(floori(local.x), floori(local.y))


func _click_tile(p: Vector2i) -> void:
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
		var i: int = state.building_at[p]
		if not state.has_haulers():
			state.haul(i)
		return
	var msg := state.gather_by_hand(p)
	if msg == Data.SHARD_TEXT:
		_toast(msg, 8.0)
	elif msg != "":
		popups.append({"pos": _tile_center(p), "text": msg, "t": 0.0})


# --- UI ----------------------------------------------------------------------


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Top bar: the stockpile and food.
	top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.add_theme_stylebox_override("panel", _panel_style(Color("264653")))
	layer.add_child(top_bar)
	var items := HFlowContainer.new()
	items.add_theme_constant_override("h_separation", 14)
	top_bar.add_child(items)
	kith_label = _label("", 15)
	kith_label.mouse_filter = Control.MOUSE_FILTER_PASS
	items.add_child(kith_label)
	food_label = _label("", 15)
	food_label.mouse_filter = Control.MOUSE_FILTER_PASS
	food_label.tooltip_text = "Every Kith eats food: Berries are worth 1, Flour 3."
	items.add_child(food_label)
	items.add_child(VSeparator.new())
	for id in Data.ITEM_ORDER:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 5)
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		box.tooltip_text = _item_tooltip(id)
		var swatch := ColorRect.new()
		swatch.color = Data.ITEMS[id]["color"]
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(swatch)
		var l := _label("", 15)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(l)
		items.add_child(box)
		item_boxes[id] = box
		item_labels[id] = l

	# Bottom bar: build, craft, tech. Wraps onto a second row when the window is narrow.
	bottom_bar = PanelContainer.new()
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_bar.add_theme_stylebox_override("panel", _panel_style(Color("264653")))
	layer.add_child(bottom_bar)
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 6)
	bar.add_theme_constant_override("v_separation", 6)
	bottom_bar.add_child(bar)
	var tech_btn := _button("Tech Tree (T)")
	tech_btn.pressed.connect(func(): tech_panel.visible = not tech_panel.visible)
	bar.add_child(tech_btn)
	bar.add_child(VSeparator.new())
	bar.add_child(_bar_heading("Build:"))
	for type in Data.BUILD_ORDER:
		var b := _button(Data.BUILDINGS[type]["name"])
		b.icon = _swatch_texture(_tech_color(Data.BUILDINGS[type]["tech"]))
		b.pressed.connect(func(): placing = "" if placing == type else type)
		bar.add_child(b)
		build_buttons[type] = b
	bar.add_child(VSeparator.new())
	bar.add_child(_bar_heading("Craft:"))
	for r in Data.RECIPES:
		var b := _button("Craft " + Data.RECIPES[r]["name"])
		b.icon = _swatch_texture(_tech_color(Data.RECIPES[r]["tech"]))
		b.pressed.connect(func(): state.craft(r))
		bar.add_child(b)
		craft_buttons[r] = b

	_build_side_panel(layer)

	# Toasts, centered under the top bar.
	toast_label = _label("", 17)
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

	_build_tech_panel(layer)
	_build_win_overlay(layer)


## Goals checklist on top, and details about whatever the mouse is over below it.
func _build_side_panel(layer: CanvasLayer) -> void:
	side_panel = PanelContainer.new()
	side_panel.add_theme_stylebox_override("panel", _panel_style(Color("264653"), 12))
	layer.add_child(side_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	side_panel.add_child(v)
	goal_header = _label("Goals", 18)
	v.add_child(goal_header)
	for i in 4:
		var g := _label("", 14)
		g.autowrap_mode = TextServer.AUTOWRAP_WORD
		g.custom_minimum_size = Vector2(SIDE_W - 30, 0)
		v.add_child(g)
		goal_labels.append(g)
	v.add_child(HSeparator.new())
	v.add_child(_label("Info", 18))
	info_label = _label("", 14)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_label.custom_minimum_size = Vector2(SIDE_W - 30, 0)
	v.add_child(info_label)


func _build_tech_panel(layer: CanvasLayer) -> void:
	tech_panel = PanelContainer.new()
	tech_panel.add_theme_stylebox_override("panel", _panel_style(Color("1d3557"), 16))
	tech_panel.set_anchors_preset(Control.PRESET_CENTER)
	tech_panel.visible = false
	layer.add_child(tech_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	tech_panel.add_child(v)
	v.add_child(_label("Stone Age: Tech Tree", 22))
	v.add_child(_label("Each tech has a color. The same color marks what it needs, and the buildings it unlocks.", 13))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for tech in Data.TECH_ORDER:
		var t: Dictionary = Data.TECHS[tech]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(300, 150)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		card.add_child(cv)
		var title := HBoxContainer.new()
		title.add_child(_badge(tech))
		title.add_child(_label(t["name"], 17))
		cv.add_child(title)
		var desc := _label(t["desc"], 12)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.custom_minimum_size = Vector2(280, 0)
		cv.add_child(desc)
		var needs := HBoxContainer.new()
		needs.add_child(_label("Needs:", 12))
		var chips := {}
		for r in t["requires"]:
			var chip := _chip(r)
			needs.add_child(chip)
			chips[r] = chip
		if t["requires"].is_empty():
			needs.add_child(_label("nothing, start here", 12))
		cv.add_child(needs)
		var unlocks := _label("Unlocks: " + _unlocks_text(tech), 12)
		unlocks.autowrap_mode = TextServer.AUTOWRAP_WORD
		unlocks.custom_minimum_size = Vector2(280, 0)
		unlocks.add_theme_color_override("font_color", Color("cfe8ef"))
		cv.add_child(unlocks)
		var btn := _button("Research: " + _cost_text(t["cost"]))
		btn.pressed.connect(func(): state.research(tech))
		cv.add_child(btn)
		grid.add_child(card)
		tech_cards[tech] = {"card": card, "chips": chips, "button": btn}
	var close := _button("Close")
	close.pressed.connect(func(): tech_panel.visible = false)
	v.add_child(close)
	# Center after layout settles, and whenever it opens.
	var center := func(): tech_panel.position = (get_viewport_rect().size - tech_panel.size) / 2.0
	tech_panel.resized.connect(center)
	tech_panel.visibility_changed.connect(center)


func _build_win_overlay(layer: CanvasLayer) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.05, 0.08, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	layer.add_child(overlay)
	win_overlay = overlay
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -300
	v.offset_right = 300
	v.offset_top = -80
	win_overlay.add_child(v)
	var title := _label("BRONZE DAWN", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := _label("The stone age ends. The next era begins.\nFar above Solace, something is falling.", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)


func _refresh_ui() -> void:
	for id in item_labels:
		var n: int = state.inv.get(id, 0)
		item_boxes[id].visible = state.seen.has(id)
		item_labels[id].text = "%s %d" % [Data.ITEMS[id]["name"], n]
		var zero_color := BAD if Data.FOOD_VALUE.has(id) else Color(1, 1, 1, 0.45)
		item_labels[id].add_theme_color_override("font_color", zero_color if n == 0 else Color.WHITE)
	var note := state.growth_note()
	var idle := state.idle_kith()
	kith_label.text = "Kith %d/%d%s%s" % [
		state.kith.size(),
		state.housing(),
		(", %d %s" % [idle, "hauling" if state.has_haulers() else "idle"]) if idle > 0 else "",
		"  (" + note + ")" if note != "" else "  (growing)",
	]
	kith_label.tooltip_text = "Kith work buildings and haul goods. Each building needs one. They grow with spare food and room."
	kith_label.add_theme_color_override("font_color", GOAL_COLOR if note != "" else GOOD)
	if state.starving and state.food_use > 0.0:
		food_label.text = "Food: none! The Kith have stopped working"
		food_label.add_theme_color_override("font_color", BAD)
	else:
		var s := "Food %d" % int(state.food_total())
		if state.food_use > 0.0:
			s += " (-%.2f/s)" % state.food_use
		var reserve := state.flour_reserve()
		if reserve > 0 and state.inv.get("flour", 0) > 0:
			s += "  [%d Flour kept for research]" % mini(reserve, state.inv["flour"])
		food_label.text = s
		food_label.add_theme_color_override("font_color", GOAL_COLOR if state.food_total() < 5 else Color.WHITE)

	for type in build_buttons:
		var b: Button = build_buttons[type]
		var def: Dictionary = Data.BUILDINGS[type]
		b.tooltip_text = def["desc"]
		if not state.building_unlocked(type):
			b.text = "%s (research %s)" % [def["name"], Data.TECHS[def["tech"]]["name"]]
			b.disabled = true
			continue
		var short := state.shortfall_text(def["cost"])
		var label: String = def["name"] + (": " + short if short != "" else " (" + _cost_text(def["cost"]) + ")")
		b.text = ("> " if placing == type else "") + label
		b.disabled = short != "" and placing != type
	for r in craft_buttons:
		var b: Button = craft_buttons[r]
		var rec: Dictionary = Data.RECIPES[r]
		if not state.recipe_unlocked(r):
			b.text = "%s (research %s)" % [rec["name"], Data.TECHS[rec["tech"]]["name"]]
			b.disabled = true
			continue
		var short := state.shortfall_text(rec["in"])
		b.text = "Craft %s: %s" % [rec["name"], short if short != "" else _cost_text(rec["in"])]
		b.disabled = short != ""

	for tech in tech_cards:
		var c: Dictionary = tech_cards[tech]
		var done: bool = state.researched.has(tech)
		var ready := state.requirements_met(tech)
		for r in c["chips"]:
			c["chips"][r].modulate = Color(1, 1, 1, 1) if state.researched.has(r) else Color(1, 1, 1, 0.5)
		var short := state.shortfall_text(Data.TECHS[tech]["cost"])
		c["button"].disabled = not state.can_research(tech)
		if done:
			c["button"].text = "Discovered"
		elif not ready:
			c["button"].text = "Research the techs it needs first"
		else:
			c["button"].text = "Research: " + (short if short != "" else _cost_text(Data.TECHS[tech]["cost"]))
		var border: Color = GOAL_COLOR if state.can_research(tech) else _tech_color(tech)
		var style := _panel_style(Color("32607f") if not done else Color("2b5470"), 8)
		style.border_color = border
		style.set_border_width_all(4 if state.can_research(tech) else 3)
		c["card"].add_theme_stylebox_override("panel", style)
		c["card"].modulate = Color(1, 1, 1, 1) if done or ready else Color(1, 1, 1, 0.5)

	var cur := state.current_goal()
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


func _hover_text() -> String:
	if placing != "":
		var s := "Placing %s. Left-click open grassland, right-click to stop." % Data.BUILDINGS[placing]["name"]
		if placing == "road":
			s = "Laying Road: click or drag across grassland, or across the river to bridge it. Right-click to stop."
		if state.in_bounds(hover):
			var err := state.placement_error(placing, hover)
			if err != "":
				s += "\n\nCan't build here: " + err + "."
			if placing == "gatherers_hut":
				s += "\n\n" + _gather_text(state.gather_tiles(hover))
		return s
	if not state.in_bounds(hover):
		return "Point at the map to see what's there."
	if state.building_at.has(hover):
		var b: Dictionary = state.buildings[state.building_at[hover]]
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		var s: String = def["name"] + "\n" + def["desc"] + "\n\nStatus: " + b["status"]
		if state.needs_worker(b):
			s += "\nWorker: " + ("yes" if b["worker"] >= 0 else "none, grow more Kith")
		if state.buffered(b["out"]) > 0:
			s += "\nHolding " + _cost_text(b["out"])
		if def["kind"] == "gatherer":
			s += "\n\n" + _gather_text(state.gather_tiles(hover))
		return s
	var t: Dictionary = Data.TILES[state.tile_at(hover)]
	if state.roads.has(hover):
		return "Road on %s. Kith walk twice as fast here." % t["name"]
	if t["yields"] != "":
		var s := "%s\nClick to gather %s." % [t["name"], Data.ITEMS[t["yields"]]["name"]]
		if Data.FOOD_VALUE.has(t["yields"]):
			s += " It's food: running buildings eat it."
		return s
	return t["name"]


## "Works 5 tiles within 2: Wood x3, Stone x2", for a hut's highlighted tiles.
func _gather_text(tiles: Array) -> String:
	var r: int = Data.BUILDINGS["gatherers_hut"]["radius"]
	if tiles.is_empty():
		return "No resources within %d tiles: it will cut grass for Fiber." % r
	var counts := {}
	for p in tiles:
		var item: String = Data.TILES[state.tile_at(p)]["yields"]
		counts[item] = counts.get(item, 0) + 1
	var parts: Array = []
	for id in counts:
		parts.append("%s x%d" % [Data.ITEMS[id]["name"], counts[id]])
	return "Gathers from the %d highlighted tiles (within %d), taking turns: %s." % [tiles.size(), r, ", ".join(parts)]


func _unlocks_text(tech: String) -> String:
	var parts: Array = []
	for type in Data.BUILD_ORDER:
		if Data.BUILDINGS[type]["tech"] == tech:
			parts.append(Data.BUILDINGS[type]["name"])
	for r in Data.RECIPES:
		if Data.RECIPES[r]["tech"] == tech:
			parts.append("crafting " + Data.RECIPES[r]["name"])
	var next: Array = []
	for t in Data.TECH_ORDER:
		if tech in Data.TECHS[t]["requires"]:
			next.append(Data.TECHS[t]["name"])
	var s := ", ".join(parts) if not parts.is_empty() else "nothing to build"
	if not next.is_empty():
		s += ". Leads to " + ", ".join(next)
	return s


func _item_tooltip(id: String) -> String:
	var s: String = Data.ITEMS[id]["name"]
	if Data.FOOD_VALUE.has(id):
		s += ": food worth %d. Running buildings eat it." % int(Data.FOOD_VALUE[id])
	return s


func _tech_color(tech: String) -> Color:
	return Data.TECHS[tech]["color"] if Data.TECHS.has(tech) else Color("e76f51")


func _toast(text: String, seconds: float) -> void:
	toast_label.text = text
	toast_time = seconds


func _cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for id in cost:
		parts.append("%d %s" % [cost[id], Data.ITEMS[id]["name"]])
	return ", ".join(parts)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func _bar_heading(text: String) -> Label:
	var l := _label(text, 13)
	l.add_theme_color_override("font_color", Color("a8dadc"))
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	return b


## A tech's colored square with its two-letter code.
func _badge(tech: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _panel_style(_tech_color(tech), 2)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(26, 22)
	var l := _label(Data.TECHS[tech]["abbr"], 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	p.add_child(l)
	return p


## A badge plus the tech's name, used in "Needs:".
func _chip(tech: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.add_child(_badge(tech))
	h.add_child(_label(Data.TECHS[tech]["name"], 12))
	return h


func _swatch_texture(color: Color) -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(OUTLINE)
	img.fill_rect(Rect2i(2, 2, 8, 8), color)
	return ImageTexture.create_from_image(img)


func _panel_style(color: Color, margin: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = OUTLINE
	s.set_border_width_all(3)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(margin)
	return s


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
				if t in ["tree", "rock", "berry", "grain", "shard"]
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
			_draw_feature(state.tile_at(p), _tile_center(p), p)

	# Ranges: a hut's gathering tiles, and power range for wheels.
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
				draw_circle(_tile_center(b["pos"]), Data.BUILDINGS["water_wheel"]["radius"] * TILE, Color(0.16, 0.62, 0.56, 0.18))
	for b in state.buildings:
		_draw_building(b)
	_draw_kith()

	# Placement ghost.
	if placing != "" and state.in_bounds(hover):
		var ok := state.placement_error(placing, hover) == ""
		var c := Color(0.3, 1, 0.4, 0.45) if ok else Color(1, 0.25, 0.25, 0.45)
		draw_rect(_tile_rect(hover).grow(-2), c)
		draw_rect(_tile_rect(hover).grow(-2), OUTLINE, false, 2.0)
	elif state.in_bounds(hover):
		draw_rect(_tile_rect(hover).grow(-1), Color(1, 1, 1, 0.8), false, 2.0)

	var font := ThemeDB.fallback_font
	for pop in popups:
		var pos: Vector2 = pop["pos"] + Vector2(-20, -10 - pop["t"] * 30)
		var a: float = 1.0 - pop["t"] / 1.2
		draw_string_outline(font, pos, pop["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 5, Color(OUTLINE, a))
		draw_string(font, pos, pop["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, a))


## Outline the hut's reach and light up the tiles it would gather from.
func _draw_gather_range(p: Vector2i) -> void:
	var r: int = Data.BUILDINGS["gatherers_hut"]["radius"]
	var reach := Rect2(MAP_ORIGIN + Vector2(p - Vector2i(r, r)) * TILE, Vector2.ONE * (2 * r + 1) * TILE)
	draw_rect(reach, Color(1, 0.82, 0.4, 0.12))
	draw_rect(reach, GOAL_COLOR, false, 2.0)
	for t in state.gather_tiles(p):
		draw_rect(_tile_rect(t).grow(-3), Color(1, 0.82, 0.4, 0.35))
		draw_rect(_tile_rect(t).grow(-3), GOAL_COLOR, false, 2.0)


func _draw_feature(t: String, c: Vector2, p: Vector2i) -> void:
	var jitter := Vector2(((p.x * 7 + p.y * 3) % 5) - 2, ((p.x * 3 + p.y * 5) % 5) - 2)
	match t:
		"tree":
			draw_rect(Rect2(c + Vector2(-2, 2), Vector2(4, 9)), Color("6d4c41"))
			_outlined_circle(c + Vector2(0, -3) + jitter * 0.5, 10.0, Color("2e7d32"))
			draw_circle(c + Vector2(-3, -6) + jitter * 0.5, 3.0, Color("43a047"))
		"rock":
			var pts := PackedVector2Array(
				[c + Vector2(-11, 8), c + Vector2(-8, -5), c + Vector2(0, -10), c + Vector2(9, -4), c + Vector2(11, 8)]
			)
			_outlined_poly(pts, Color("9e9e9e"))
			draw_line(c + Vector2(-2, -6), c + Vector2(2, 4), Color("757575"), 2.0)
		"gravel":
			for i in 5:
				draw_circle(c + Vector2((i * 11) % 20 - 10, (i * 7) % 16 - 8), 2.5, Color("4a4e69"))
		"clay":
			draw_circle(c + Vector2(-5, 3), 5.0, Color("a0522d"))
			draw_circle(c + Vector2(6, -3), 4.0, Color("a0522d"))
		"berry":
			_outlined_circle(c + Vector2(0, 2), 10.0, Color("558b2f"))
			for off in [Vector2(-4, -1), Vector2(3, 3), Vector2(4, -4), Vector2(-2, 6)]:
				draw_circle(c + off, 2.5, Color("d62246"))
		"grain":
			for i in 4:
				var x := -9 + i * 6
				draw_line(c + Vector2(x, 10), c + Vector2(x + 2, -8), Color("8d6e1f"), 2.0)
				draw_circle(c + Vector2(x + 2, -8), 2.5, Color("f2c14e"))
		"river":
			var w := sin(time * 2.0 + p.y * 0.9) * 3.0
			draw_line(c + Vector2(-10 + w, -4), c + Vector2(-2 + w, -4), Color(1, 1, 1, 0.5), 2.0)
			draw_line(c + Vector2(2 - w, 5), c + Vector2(10 - w, 5), Color(1, 1, 1, 0.5), 2.0)
		"shard":
			var glow := 0.35 + 0.25 * sin(time * 2.5)
			draw_circle(c, 13.0, Color(0.6, 0.95, 1.0, glow * 0.5))
			var pts := PackedVector2Array(
				[c + Vector2(0, -10), c + Vector2(6, 0), c + Vector2(0, 10), c + Vector2(-6, 0)]
			)
			_outlined_poly(pts, Color("bdf4ff"))


func _draw_building(b: Dictionary) -> void:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	var p: Vector2i = b["pos"]
	var r := _tile_rect(p).grow(-2)
	var c := r.get_center()
	var working: bool = b["status"] == "Working"

	# Base plate in Kith color, like a unit on a game board.
	draw_rect(r, KITH.darkened(0.15))
	draw_rect(r, OUTLINE, false, OUTLINE_W)

	match b["type"]:
		"camp":
			_outlined_poly(
				PackedVector2Array([c + Vector2(-11, 9), c + Vector2(0, -11), c + Vector2(11, 9)]), Color("f4e1c1")
			)
			var flame := 3.0 + sin(time * 10.0) * 1.0
			draw_circle(c + Vector2(0, 5), flame, Color("ffb703"))
		"charcoal_pit":
			_outlined_circle(c + Vector2(0, 4), 9.0, Color("3d405b"))
			if working:
				for i in 3:
					var t := fmod(time * 0.6 + i / 3.0, 1.0)
					draw_circle(
						c + Vector2(sin(t * 6.0) * 3.0, -2 - t * 12), 2.0 + t * 2.0, Color(0.8, 0.8, 0.8, 1.0 - t)
					)
		"twine_post":
			draw_rect(Rect2(c + Vector2(-2, -11), Vector2(4, 20)), Color("6d4c41"))
			_outlined_circle(c + Vector2(0, 2), 6.0, Color("bc8a5f"))
		"gatherers_hut":
			draw_rect(Rect2(c + Vector2(-8, -1), Vector2(16, 10)), Color("f4a261"))
			draw_rect(Rect2(c + Vector2(-8, -1), Vector2(16, 10)), OUTLINE, false, 2.0)
			_outlined_poly(
				PackedVector2Array([c + Vector2(-11, 0), c + Vector2(0, -11), c + Vector2(11, 0)]), Color("e9c46a")
			)
		"kiln":
			_outlined_circle(c + Vector2(0, 2), 10.0, Color("9c3d2e"))
			draw_circle(c + Vector2(0, 5), 4.0, Color("ffb703") if working else OUTLINE)
		"dwelling":
			draw_rect(Rect2(c + Vector2(-9, -1), Vector2(18, 10)), Color("d4a373"))
			draw_rect(Rect2(c + Vector2(-9, -1), Vector2(18, 10)), OUTLINE, false, 2.0)
			_outlined_poly(
				PackedVector2Array([c + Vector2(-12, 0), c + Vector2(0, -10), c + Vector2(12, 0)]), Color("a8dadc")
			)
			draw_rect(Rect2(c + Vector2(-2, 3), Vector2(4, 6)), OUTLINE)
		"storehouse":
			var box := Rect2(c + Vector2(-10, -8), Vector2(20, 17))
			draw_rect(box, Color("8d6e63"))
			draw_rect(box, OUTLINE, false, 2.0)
			draw_line(box.position, box.end, OUTLINE, 1.5)
			draw_line(box.position + Vector2(box.size.x, 0), box.position + Vector2(0, box.size.y), OUTLINE, 1.5)
		"water_wheel", "grindstone":
			var col := Color("2a9d8f") if b["type"] == "water_wheel" else Color("adb5bd")
			var spinning: bool = b["type"] == "water_wheel" or working
			var ang := time * 2.0 if spinning else 0.0
			_outlined_circle(c, 11.0, col)
			for i in 4:
				var a := ang + i * PI / 4.0
				draw_line(c - Vector2.from_angle(a) * 10.0, c + Vector2.from_angle(a) * 10.0, OUTLINE, 2.0)
			draw_circle(c, 3.0, OUTLINE)

	# Progress bar and held output.
	if def.has("time") and working:
		var frac: float = b["progress"] / def["time"]
		draw_rect(Rect2(r.position + Vector2(2, r.size.y - 5), Vector2((r.size.x - 4) * frac, 3)), Color("ffd166"))
	var held := state.buffered(b["out"])
	if held > 0:
		var badge := r.position + Vector2(r.size.x - 2, 2)
		_outlined_circle(badge, 7.0, Color("ffd166") if held < Data.BUFFER_CAP else Color("ef476f"))
		draw_string(
			ThemeDB.fallback_font,
			badge + Vector2(-4 if held < 10 else -7, 4),
			str(held),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			OUTLINE
		)
	if b["status"].begins_with("Hungry") or b["status"].begins_with("No power"):
		draw_string(
			ThemeDB.fallback_font, r.position + Vector2(-2, 10), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ef476f")
		)


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
		_outlined_circle(c, 5.0, KITH.lightened(0.25) if k["job"] == "haul" else KITH)
		for id in k["carry"]:
			draw_rect(Rect2(c + Vector2(-4, -13), Vector2(8, 7)), Data.ITEMS[id]["color"])
			draw_rect(Rect2(c + Vector2(-4, -13), Vector2(8, 7)), OUTLINE, false, 1.5)


func _draw_roads() -> void:
	var dirt := Data.BUILDINGS["road"]["color"]
	for p in state.roads:
		var c := _tile_center(p)
		if state.tile_at(p) == "river":
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
				draw_colored_polygon(
					PackedVector2Array([c - w, c + w, c + half + w, c + half - w]), dirt
				)


func _outlined_circle(c: Vector2, radius: float, color: Color) -> void:
	draw_circle(c, radius, color)
	draw_arc(c, radius, 0, TAU, 24, OUTLINE, 2.0, true)


func _outlined_poly(pts: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(pts, color)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, OUTLINE, 2.0, true)
