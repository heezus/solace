extends Node2D
## Draws the map in a flat, bold-outlined vector style and builds the UI in code.

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")

const TILE := 32.0
const MAP_ORIGIN := Vector2(64, 48)
const OUTLINE := Color("1b1b1f")
const OUTLINE_W := 2.5
const KITH := Color("e76f51")

var state: GameState
var placing := ""  # building type being placed, "" when not placing
var hover := Vector2i(-1, -1)
var time := 0.0
var popups: Array = []  # {pos: Vector2, text: String, t: float}

var item_labels := {}
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
	if event is InputEventMouseMotion:
		hover = _tile_under(event.position)
	elif event is InputEventMouseButton and event.pressed:
		var p := _tile_under(event.position)
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


func _tile_under(screen_pos: Vector2) -> Vector2i:
	var local := (screen_pos - MAP_ORIGIN) / TILE
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

	# Top bar: the stockpile.
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_stylebox_override("panel", _panel_style(Color("264653")))
	layer.add_child(top)
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 14)
	top.add_child(items)
	for id in Data.ITEM_ORDER:
		var swatch := ColorRect.new()
		swatch.color = Data.ITEMS[id]["color"]
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		items.add_child(swatch)
		var l := _label("", 15)
		l.tooltip_text = Data.ITEMS[id]["name"]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		items.add_child(l)
		item_labels[id] = l

	# Bottom bar: build, craft, tech.
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_stylebox_override("panel", _panel_style(Color("264653")))
	layer.add_child(bottom)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bottom.add_child(bar)
	for type in Data.BUILD_ORDER:
		var b := _button(Data.BUILDINGS[type]["name"])
		b.pressed.connect(func(): placing = "" if placing == type else type)
		bar.add_child(b)
		build_buttons[type] = b
	bar.add_child(VSeparator.new())
	for r in Data.RECIPES:
		var b := _button("Craft " + Data.RECIPES[r]["name"])
		b.pressed.connect(func(): state.craft(r))
		bar.add_child(b)
		craft_buttons[r] = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var tech_btn := _button("Tech Tree (T)")
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

	_build_tech_panel(layer)
	_build_win_overlay(layer)


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
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for tech in Data.TECH_ORDER:
		var t: Dictionary = Data.TECHS[tech]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(290, 120)
		card.add_theme_stylebox_override("panel", _panel_style(Color("32607f"), 8))
		var cv := VBoxContainer.new()
		card.add_child(cv)
		var title := _label(t["name"], 17)
		cv.add_child(title)
		var desc := _label(t["desc"], 12)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.custom_minimum_size = Vector2(270, 0)
		cv.add_child(desc)
		var needs := _label("", 12)
		cv.add_child(needs)
		var btn := _button("Research: " + _cost_text(t["cost"]))
		btn.pressed.connect(func(): state.research(tech))
		cv.add_child(btn)
		grid.add_child(card)
		tech_cards[tech] = {"card": card, "needs": needs, "button": btn}
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
		item_labels[id].text = "%s %d" % [Data.ITEMS[id]["name"], state.inv.get(id, 0)]
		item_labels[id].visible = state.inv.get(id, 0) > 0 or id in ["wood", "stone", "berries"]
	for type in build_buttons:
		var b: Button = build_buttons[type]
		var def: Dictionary = Data.BUILDINGS[type]
		b.visible = state.building_unlocked(type)
		b.text = ("> " if placing == type else "") + def["name"] + " (" + _cost_text(def["cost"]) + ")"
		b.disabled = not state.can_afford(def["cost"]) and placing != type
		b.tooltip_text = def["desc"]
	for r in craft_buttons:
		var b: Button = craft_buttons[r]
		var rec: Dictionary = Data.RECIPES[r]
		b.visible = state.recipe_unlocked(r)
		b.text = "Craft %s (%s)" % [rec["name"], _cost_text(rec["in"])]
		b.disabled = not state.can_afford(rec["in"])
	for tech in tech_cards:
		var c: Dictionary = tech_cards[tech]
		var done: bool = state.researched.has(tech)
		var req: Array = Data.TECHS[tech]["requires"]
		var names: Array = req.map(func(r): return Data.TECHS[r]["name"])
		c["needs"].text = "Needs: " + (", ".join(names) if not names.is_empty() else "nothing")
		c["button"].disabled = not state.can_research(tech)
		c["button"].text = "Discovered" if done else "Research: " + _cost_text(Data.TECHS[tech]["cost"])
		c["card"].modulate = Color(1, 1, 1, 1) if done or state.requirements_met(tech) else Color(1, 1, 1, 0.45)
	info_label.text = _hover_text()


func _hover_text() -> String:
	if placing != "":
		var err := state.placement_error(placing, hover) if state.in_bounds(hover) else ""
		return "Placing %s. %s Right-click to stop." % [Data.BUILDINGS[placing]["name"], err + "." if err != "" else ""]
	if not state.in_bounds(hover):
		return ""
	if state.building_at.has(hover):
		var b: Dictionary = state.buildings[state.building_at[hover]]
		var s: String = Data.BUILDINGS[b["type"]]["name"] + ": " + b["status"]
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


func _draw_haulers() -> void:
	var home := _tile_center(state.camp_pos)
	for i in state.buildings.size():
		var b: Dictionary = state.buildings[i]
		if b["type"] == "camp" or Data.BUILDINGS[b["type"]]["kind"] == "power":
			continue
		var to := _tile_center(b["pos"])
		draw_line(home, to, Color(0.95, 0.85, 0.6, 0.35), 3.0)
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
