extends Node2D
## Draws the map in a flat, bold-outlined vector style and builds the UI in code.

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")

const TILE := 32.0
const MAP_ORIGIN := Vector2.ZERO  # the node itself is moved and scaled to fit the window
const GOAL_W := 300.0
const READY := Color("ffd166")
const SHORT := Color("ffb3c1")
const OUTLINE := Color("1b1b1f")
const OUTLINE_W := 2.5
const KITH := Color("e76f51")

var state: GameState
var placing := ""  # building type being placed, "" when not placing
var hover := Vector2i(-1, -1)
var time := 0.0
var popups: Array = []  # {pos: Vector2, text: String, t: float}

var item_labels := {}
var kith_label: Label
var food_label: Label
var top_bar: PanelContainer
var bottom_bar: PanelContainer
var goal_step: Label
var goal_text: Label
var goal_hint: Label
var build_buttons := {}
var craft_buttons := {}
var tech_cards := {}
var info_label: Label
var toast_label: Label
var toast_time := 0.0
var tech_panel: PanelContainer
var win_overlay: Control
var ui_refresh := 0.0


func _ready() -> void:
	state = GameState.new()
	state.generate(randi())
	_build_ui()
	_toast("The Kith make camp. Click the land to gather. Press T for the tech tree.", 6.0)


func _process(delta: float) -> void:
	time += delta
	_fit_map()
	hover = _tile_under(get_local_mouse_position())
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
	ui_refresh -= delta
	if ui_refresh <= 0.0:
		ui_refresh = 0.2
		_refresh_ui()
	queue_redraw()


# --- Input -------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var p := _tile_under(to_local(event.position))
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


## `local` is in this node's coordinates (see _fit_map).
func _tile_under(local: Vector2) -> Vector2i:
	var t := (local - MAP_ORIGIN) / TILE
	return Vector2i(floori(t.x), floori(t.y))


## Scale and center the map in the space between the bars, left of the goal panel.
func _fit_map() -> void:
	var vp := get_viewport_rect().size
	var top_h := top_bar.size.y + 12.0
	var bottom_h := bottom_bar.size.y + 36.0  # room for the hover line
	var avail := Rect2(Vector2(16, top_h), Vector2(vp.x - GOAL_W - 40.0, vp.y - top_h - bottom_h))
	var map_px := Vector2(GameState.WIDTH, GameState.HEIGHT) * TILE
	var sc := maxf(minf(avail.size.x / map_px.x, avail.size.y / map_px.y), 0.1)
	scale = Vector2(sc, sc)
	position = (avail.position + (avail.size - map_px * sc) / 2.0).round()


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

	# Top bar: the stockpile.
	top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.add_theme_stylebox_override("panel", _panel_style(Color("264653")))
	layer.add_child(top_bar)
	var items := HFlowContainer.new()
	items.add_theme_constant_override("h_separation", 14)
	top_bar.add_child(items)
	kith_label = _label("", 15)
	kith_label.mouse_filter = Control.MOUSE_FILTER_PASS
	kith_label.tooltip_text = (
		(
			"Your people. Every hut and workshop needs one Kith to run.\n"
			+ "Keep %d food stored per Kith and a new one joins every %d seconds.\n"
			+ "With no food, Kith leave."
		)
		% [int(Data.GROWTH_FOOD_PER_KITH), int(Data.GROWTH_SECONDS)]
	)
	items.add_child(kith_label)
	food_label = _label("", 15)
	food_label.mouse_filter = Control.MOUSE_FILTER_PASS
	food_label.tooltip_text = (
		(
			"Berries are worth 1 food and Flour 3. Each Kith eats 1 food every %d seconds.\n"
			+ "Flour needed for research is kept back and never eaten."
		)
		% roundi(1.0 / Data.FOOD_PER_KITH_PER_SEC)
	)
	items.add_child(food_label)
	items.add_child(VSeparator.new())
	for id in Data.ITEM_ORDER:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 5)
		box.tooltip_text = _item_tooltip(id)
		items.add_child(box)
		box.add_child(_swatch(Data.ITEMS[id]["color"], 12))
		var l := _label("", 15)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(l)
		item_labels[id] = l

	# Bottom bar: build, craft, tech.
	bottom_bar = PanelContainer.new()
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_bar.add_theme_stylebox_override("panel", _panel_style(Color("264653")))
	layer.add_child(bottom_bar)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bottom_bar.add_child(bar)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	bar.add_child(flow)
	flow.add_child(_label("Build:", 14))
	for type in Data.BUILD_ORDER:
		var b := _button(Data.BUILDINGS[type]["name"])
		b.icon = _swatch_tex(Data.TECHS[Data.BUILDINGS[type]["tech"]]["color"])
		b.pressed.connect(func(): placing = "" if placing == type else type)
		flow.add_child(b)
		build_buttons[type] = b
	flow.add_child(VSeparator.new())
	flow.add_child(_label("Craft by hand:", 14))
	for r in Data.RECIPES:
		var b := _button("Craft " + Data.RECIPES[r]["name"])
		b.icon = _swatch_tex(Data.TECHS[Data.RECIPES[r]["tech"]]["color"])
		b.pressed.connect(func(): state.craft(r))
		flow.add_child(b)
		craft_buttons[r] = b
	var tech_btn := _button("Tech Tree (T)")
	tech_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tech_btn.pressed.connect(func(): tech_panel.visible = not tech_panel.visible)
	bar.add_child(tech_btn)

	# Hover info, just above the bottom bar.
	info_label = _label("", 14)
	info_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	info_label.offset_left = 12
	info_label.offset_top = -76
	info_label.offset_bottom = -52
	info_label.add_theme_color_override("font_outline_color", OUTLINE)
	info_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(info_label)
	bottom_bar.resized.connect(
		func():
			info_label.offset_bottom = -bottom_bar.size.y - 4.0
			info_label.offset_top = info_label.offset_bottom - 24.0
	)

	# Toasts, centered under the top bar.
	toast_label = _label("", 17)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -500
	toast_label.offset_right = 500
	toast_label.offset_top = 52
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	toast_label.add_theme_color_override("font_outline_color", OUTLINE)
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(toast_label)

	_build_goal_panel(layer)
	_build_tech_panel(layer)
	_build_win_overlay(layer)


func _build_goal_panel(layer: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("1d3557"), 12))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -GOAL_W - 12.0
	panel.offset_right = -12
	panel.offset_top = 64
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	goal_step = _label("", 12)
	goal_step.add_theme_color_override("font_color", READY)
	v.add_child(goal_step)
	goal_text = _label("", 18)
	goal_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	goal_text.custom_minimum_size = Vector2(GOAL_W - 24.0, 0)
	v.add_child(goal_text)
	goal_hint = _label("", 13)
	goal_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	goal_hint.custom_minimum_size = Vector2(GOAL_W - 24.0, 0)
	v.add_child(goal_hint)
	# Keep it under the top bar, which wraps to two rows on narrow windows.
	top_bar.resized.connect(func(): panel.offset_top = top_bar.size.y + 12.0)


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
	var key := _label("Each tech has a color. Its chips under Needs and Leads to show how the tree connects.", 12)
	v.add_child(key)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for tech in Data.TECH_ORDER:
		var t: Dictionary = Data.TECHS[tech]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(290, 120)
		var style := _panel_style(Color("32607f"), 8)
		card.add_theme_stylebox_override("panel", style)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		card.add_child(cv)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(_swatch(t["color"], 16))
		head.add_child(_label(t["name"], 17))
		cv.add_child(head)
		var desc := _label(t["desc"], 12)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.custom_minimum_size = Vector2(270, 0)
		cv.add_child(desc)
		var chips := {}
		cv.add_child(_chip_row("Needs:", t["requires"], chips))
		var leads: Array = Data.TECH_ORDER.filter(func(o): return tech in Data.TECHS[o]["requires"])
		cv.add_child(_chip_row("Leads to:", leads, {}))
		var btn := _button("Research: " + _cost_text(t["cost"]))
		btn.pressed.connect(func(): state.research(tech))
		cv.add_child(btn)
		grid.add_child(card)
		tech_cards[tech] = {"card": card, "style": style, "chips": chips, "button": btn}
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
		var l: Label = item_labels[id]
		var kept := state.research_reserve(id) if Data.FOOD_VALUE.has(id) else 0
		l.text = "%s %d" % [Data.ITEMS[id]["name"], n] + (" (%d kept)" % mini(n, kept) if kept > 0 and n > 0 else "")
		l.add_theme_color_override("font_color", SHORT if n == 0 else Color.WHITE)
	var jobs := state.workers_needed()
	kith_label.text = "Kith %d  (jobs %d/%d)" % [state.population, mini(jobs, state.population), jobs]
	kith_label.add_theme_color_override("font_color", SHORT if jobs > state.population else READY)
	var food := state.food_total()
	food_label.text = "Food %d  (-%.2f/s)" % [floori(food), state.food_per_sec()]
	if not state.fed:
		food_label.text = "Food 0: HUNGRY"
	food_label.add_theme_color_override("font_color", SHORT if not state.fed or food < 5.0 else READY)
	for type in build_buttons:
		var b: Button = build_buttons[type]
		var def: Dictionary = Data.BUILDINGS[type]
		b.disabled = not state.building_unlocked(type) or (not state.can_afford(def["cost"]) and placing != type)
		if not state.building_unlocked(type):
			b.text = "%s: needs %s" % [def["name"], Data.TECHS[def["tech"]]["name"]]
		elif placing == type:
			b.text = "> Placing %s (right-click to stop)" % def["name"]
		elif not state.can_afford(def["cost"]):
			b.text = "%s: short %s" % [def["name"], _short_text(def["cost"])]
		else:
			b.text = "%s (%s)" % [def["name"], _cost_text(def["cost"])]
		b.tooltip_text = "%s\nCost: %s" % [def["desc"], _cost_text(def["cost"])]
	for r in craft_buttons:
		var b: Button = craft_buttons[r]
		var rec: Dictionary = Data.RECIPES[r]
		b.disabled = not state.recipe_unlocked(r) or not state.can_afford(rec["in"])
		if not state.recipe_unlocked(r):
			b.text = "Craft %s: needs %s" % [rec["name"], Data.TECHS[rec["tech"]]["name"]]
		elif not state.can_afford(rec["in"]):
			b.text = "Craft %s: short %s" % [rec["name"], _short_text(rec["in"])]
		else:
			b.text = "Craft %s (%s)" % [rec["name"], _cost_text(rec["in"])]
	for tech in tech_cards:
		var c: Dictionary = tech_cards[tech]
		var done: bool = state.researched.has(tech)
		for req in c["chips"]:
			c["chips"][req].modulate = Color.WHITE if state.researched.has(req) else Color(1, 1, 1, 0.5)
		c["button"].disabled = not state.can_research(tech)
		if done:
			c["button"].text = "Discovered"
		elif not state.requirements_met(tech):
			c["button"].text = "Locked: research its Needs first"
		elif not state.can_afford(Data.TECHS[tech]["cost"]):
			c["button"].text = "Short " + _short_text(Data.TECHS[tech]["cost"])
		else:
			c["button"].text = "Research: " + _cost_text(Data.TECHS[tech]["cost"])
		var style: StyleBoxFlat = c["style"]
		style.border_color = READY if state.can_research(tech) else OUTLINE
		style.bg_color = Color("24475e") if done else Color("32607f")
		c["card"].modulate = Color(1, 1, 1, 1) if done or state.requirements_met(tech) else Color(1, 1, 1, 0.55)
	var goal := state.current_goal()
	if goal.is_empty():
		goal_step.text = "ALL GOALS DONE"
		goal_text.text = "The stone age is yours."
		goal_hint.text = ""
	else:
		goal_step.text = "GOAL %d OF %d" % [state.goal_index + 1, Data.GOALS.size()]
		goal_text.text = goal["text"]
		goal_hint.text = goal["hint"]
	info_label.text = _hover_text()


func _hover_text() -> String:
	if placing != "":
		var err := state.placement_error(placing, hover) if state.in_bounds(hover) else ""
		var s := "Placing %s. " % Data.BUILDINGS[placing]["name"]
		if err != "":
			s += err + ". "
		if Data.BUILDINGS[placing]["kind"] == "gatherer" and state.in_bounds(hover):
			s += "Will gather: %s. " % state.gather_summary(placing, hover)
		return s + "Right-click to stop."
	if not state.in_bounds(hover):
		return ""
	if state.building_at.has(hover):
		var b: Dictionary = state.buildings[state.building_at[hover]]
		var s: String = Data.BUILDINGS[b["type"]]["name"] + ": " + b["status"]
		if Data.BUILDINGS[b["type"]]["kind"] == "gatherer":
			s += "  |  Gathers " + state.gather_summary(b["type"], hover)
		if state.buffered(b["out"]) > 0:
			s += "  |  Holding " + _cost_text(b["out"])
		return s
	var t: Dictionary = Data.TILES[state.tile_at(hover)]
	if t["yields"] != "":
		return "%s: click to gather %s" % [t["name"], Data.ITEMS[t["yields"]]["name"]]
	return t["name"]


func _toast(text: String, seconds: float) -> void:
	toast_label.text = text
	toast_time = seconds


func _cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for id in cost:
		parts.append("%d %s" % [cost[id], Data.ITEMS[id]["name"]])
	return ", ".join(parts)


## What still needs gathering: "10 Clay, 2 Wood".
func _short_text(cost: Dictionary) -> String:
	var parts: Array = []
	for id in cost:
		var short: int = cost[id] - state.inv.get(id, 0)
		if short > 0:
			parts.append("%d %s" % [short, Data.ITEMS[id]["name"]])
	return ", ".join(parts)


## Explains an item: whether it's food, and everything that uses it.
func _item_tooltip(id: String) -> String:
	var lines: Array = [Data.ITEMS[id]["name"]]
	if Data.FOOD_VALUE.has(id):
		lines.append("Food: worth %d. The Kith eat it to stay and to grow." % int(Data.FOOD_VALUE[id]))
	var uses: Array = []
	for tech in Data.TECH_ORDER:
		if Data.TECHS[tech]["cost"].has(id):
			uses.append(Data.TECHS[tech]["name"] + " (research)")
	for type in Data.BUILD_ORDER:
		var def: Dictionary = Data.BUILDINGS[type]
		if def["cost"].has(id) or def.get("in", {}).has(id):
			uses.append(def["name"])
	for r in Data.RECIPES:
		if Data.RECIPES[r]["in"].has(id):
			uses.append("Craft " + Data.RECIPES[r]["name"])
	if id == "flint_tools":
		lines.append("Held tools double what you gather by hand.")
	if not uses.is_empty():
		lines.append("Used for: " + ", ".join(uses))
	return "\n".join(lines)


## "Needs:" or "Leads to:" followed by a color chip per tech. Fills `out` with tech -> chip.
func _chip_row(title: String, techs: Array, out: Dictionary) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_child(_label(title, 12))
	if techs.is_empty():
		row.add_child(_label("nothing", 12))
	for tech in techs:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)
		chip.add_child(_swatch(Data.TECHS[tech]["color"], 11))
		chip.add_child(_label(Data.TECHS[tech]["name"], 12))
		row.add_child(chip)
		out[tech] = chip
	return row


func _swatch_tex(color: Color, size: int = 14) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(OUTLINE)
	img.fill_rect(Rect2i(2, 2, size - 4, size - 4), color)
	return ImageTexture.create_from_image(img)


func _swatch(color: Color, size: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _swatch_tex(color, size)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	return b


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

	# Features.
	for y in GameState.HEIGHT:
		for x in GameState.WIDTH:
			var p := Vector2i(x, y)
			_draw_feature(state.tile_at(p), _tile_center(p), p)

	# Power range while placing power, and haul paths.
	if placing == "water_wheel" and state.in_bounds(hover):
		draw_circle(_tile_center(hover), Data.BUILDINGS["water_wheel"]["radius"] * TILE, Color(0.16, 0.62, 0.56, 0.18))
	_draw_gather_range()
	if state.has_haulers():
		_draw_haulers()

	for b in state.buildings:
		_draw_building(b)

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


## While placing a Gatherer's Hut or hovering one: its range, and the tiles it will work.
func _draw_gather_range() -> void:
	var center := Vector2i(-1, -1)
	var type := ""
	if placing != "" and Data.BUILDINGS[placing]["kind"] == "gatherer" and state.in_bounds(hover):
		center = hover
		type = placing
	elif placing == "" and state.building_at.has(hover):
		var b: Dictionary = state.buildings[state.building_at[hover]]
		if Data.BUILDINGS[b["type"]]["kind"] == "gatherer":
			center = hover
			type = b["type"]
	if type == "":
		return
	var r: int = Data.BUILDINGS[type]["radius"]
	var area := Rect2(_tile_rect(center - Vector2i(r, r)).position, Vector2.ONE * TILE * (r * 2 + 1))
	draw_rect(area, Color(1, 0.85, 0.4, 0.14))
	draw_rect(area, READY, false, 2.0)
	for spot in state.gather_spots(type, center):
		draw_rect(_tile_rect(spot).grow(-3), READY, false, 3.0)


func _draw_haulers() -> void:
	var home := _tile_center(state.camp_pos)
	for i in state.buildings.size():
		var b: Dictionary = state.buildings[i]
		if b["type"] == "camp" or Data.BUILDINGS[b["type"]]["kind"] == "power":
			continue
		var to := _tile_center(b["pos"])
		if b["pos"] == hover:
			draw_line(home, to, Color(0.95, 0.85, 0.6, 0.6), 2.0)
		var t := fmod(time * 0.35 + i * 0.37, 1.0)
		var k := 1.0 - absf(t * 2.0 - 1.0)  # out and back
		_outlined_circle(home.lerp(to, k), 3.5, KITH.lightened(0.3))


func _outlined_circle(c: Vector2, radius: float, color: Color) -> void:
	draw_circle(c, radius, color)
	draw_arc(c, radius, 0, TAU, 24, OUTLINE, 2.0, true)


func _outlined_poly(pts: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(pts, color)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, OUTLINE, 2.0, true)
