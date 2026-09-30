extends Node2D
## Draws the map in a flat, bold-outlined vector style and builds the UI in code.

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")
const Art = preload("res://scripts/art.gd")

const TILE := 32.0
const MAP_ORIGIN := Vector2.ZERO  # the node's transform scales and centers the map
const OUTLINE: Color = Art.OUTLINE
const OUTLINE_W := 2.5
const KITH := Color("e76f51")
const SIDE_W := 290.0
const BAD := Color("ef476f")
const GOOD := Color("80ed99")
const GOAL_COLOR := Color("ffd166")
const CARD := Vector2(186, 54)
const COL_W := 238.0
const ROW_H := 64.0
const DIM_ARROW := Color(0.75, 0.8, 0.85, 0.35)
const AURA_FILL := Color(0.55, 0.45, 0.6, 0.2)

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
var tech_graph: Control
var selected_tech := "foraging"
var tech_detail := {}
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
	if event is InputEventMouseMotion and placing in ["road", "field"] and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var p := _tile_under()
		if state.placement_error(placing, p) == "":
			state.place(placing, p)
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
	var first_look := not state.shard_seen
	var msg := state.gather_by_hand(p)
	if msg == Data.SHARD_TEXT:
		_toast(msg + ("\nA new idea stirs in the tech tree: Star Lore." if first_look else ""), 8.0)
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
	food_label.tooltip_text = "Every Kith eats food: Berries, Fish and Flour. Hover one to see what it's worth."
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


## The tech tree: cards laid out by tier, with arrows from each tech to what it leads to.
## Click a card to see its details below and research it.
func _build_tech_panel(layer: CanvasLayer) -> void:
	tech_panel = PanelContainer.new()
	tech_panel.add_theme_stylebox_override("panel", _panel_style(Color("1d3557"), 16))
	tech_panel.set_anchors_preset(Control.PRESET_CENTER)
	tech_panel.visible = false
	layer.add_child(tech_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	tech_panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(_label("Stone Age: Tech Tree", 22))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := _button("Close (T)")
	close.pressed.connect(func(): tech_panel.visible = false)
	head.add_child(close)
	v.add_child(head)
	v.add_child(
		_label("Arrows show what each tech leads to. Dashed arrows: either one will do. Gold outline: ready now.", 13)
	)

	tech_graph = Control.new()
	var span := Vector2.ZERO
	for tech in Data.TECHS:
		span = span.max(Data.TECHS[tech]["pos"])
	tech_graph.custom_minimum_size = Vector2(span.x * COL_W, span.y * ROW_H) + CARD
	tech_graph.draw.connect(_draw_tech_arrows)
	v.add_child(tech_graph)
	for tech in Data.TECH_ORDER:
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.position = _card_pos(tech)
		card.size = CARD
		card.tooltip_text = Data.TECHS[tech]["desc"]
		card.pressed.connect(_select_tech.bind(tech))
		var h := HBoxContainer.new()
		h.position = Vector2(8, 8)
		h.add_theme_constant_override("separation", 8)
		h.add_child(_badge(tech))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		var name_label := _label(Data.TECHS[tech]["name"], 14)
		tv.add_child(name_label)
		var status := _label("", 11)
		tv.add_child(status)
		h.add_child(tv)
		card.add_child(h)
		_ignore_mouse(h)
		tech_graph.add_child(card)
		tech_cards[tech] = {"card": card, "status": status}

	# Details of the selected tech.
	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", _panel_style(Color("264653"), 10))
	v.add_child(detail)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 16)
	detail.add_child(dh)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(dv)
	tech_detail["title"] = _label("", 18)
	dv.add_child(tech_detail["title"])
	for key in ["desc", "needs", "unlocks", "cost"]:
		var l := _label("", 13)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(700, 0)
		dv.add_child(l)
		tech_detail[key] = l
	var research := _button("Research")
	research.custom_minimum_size = Vector2(220, 48)
	research.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	research.add_theme_font_size_override("font_size", 16)
	research.pressed.connect(
		func():
			state.research(selected_tech)
			_refresh_ui()
	)
	dh.add_child(research)
	tech_detail["button"] = research

	# Center after layout settles, and whenever it opens.
	var center := func(): tech_panel.position = (get_viewport_rect().size - tech_panel.size) / 2.0
	tech_panel.resized.connect(center)
	tech_panel.visibility_changed.connect(center)


func _card_pos(tech: String) -> Vector2:
	var p: Vector2 = Data.TECHS[tech]["pos"]
	return Vector2(p.x * COL_W, p.y * ROW_H)


func _select_tech(tech: String) -> void:
	if selected_tech == tech and state.can_research(tech):
		state.research(tech)  # second click on a ready tech researches it
	selected_tech = tech
	_refresh_ui()


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


## Curved arrows from each requirement to the tech that needs it. Lit once the requirement is done;
## the selected tech's arrows are drawn thick. Hidden techs and their arrows are left out.
func _draw_tech_arrows() -> void:
	for tech in Data.TECHS:
		if not state.tech_visible(tech):
			continue
		var to := _card_pos(tech) + Vector2(-2, CARD.y / 2.0)
		for r in Data.TECHS[tech]["requires"]:
			_draw_link(r, tech, to)
		var any := _visible_any(tech)
		if any.size() == 1:
			_draw_link(any[0], tech, to)
		elif any.size() > 1:
			_draw_or_links(tech, any)


## The `requires_any` techs the player can see. With Star Lore hidden, Megaliths shows a plain arrow.
func _visible_any(tech: String) -> Array:
	return Data.TECHS[tech].get("requires_any", []).filter(func(r): return state.tech_visible(r))


func _draw_link(r: String, tech: String, to: Vector2) -> void:
	var focus: bool = selected_tech in [r, tech]
	var col := _arrow_color(r, state.researched.has(r), focus)
	Art.draw_curve(tech_graph, Art.curve(_card_out(r), to), col, 4.0 if focus else 2.5, false)
	Art.draw_head(tech_graph, to, col)


## Either-or parents: dashed curves merge at a dot, then one arrow enters the card low on its left edge.
## Each dash lights with its own parent; the merged arrow lights once any parent is done.
func _draw_or_links(tech: String, any: Array) -> void:
	var to := _card_pos(tech) + Vector2(-2, CARD.y * 0.8)
	var merge := to - Vector2(22, 0)
	var src: String = any[0]
	for r in any:
		var focus: bool = selected_tech in [r, tech]
		var col := _arrow_color(r, state.researched.has(r), focus)
		Art.draw_curve(tech_graph, Art.curve(_card_out(r), merge), col, 3.0 if focus else 2.0, true)
		if state.researched.has(r) and not state.researched.has(src):
			src = r
	var lit: bool = state.researched.has(src)
	var focused: bool = selected_tech == tech or selected_tech in any
	var col := _arrow_color(src, lit, focused)
	Art.draw_curve(tech_graph, PackedVector2Array([merge, to]), col, 4.0 if focused else 2.5, false)
	Art.draw_head(tech_graph, to, col)
	tech_graph.draw_circle(merge, 5.0, col)
	tech_graph.draw_arc(merge, 5.0, 0, TAU, 16, OUTLINE, 1.5, true)
	var font := ThemeDB.fallback_font
	tech_graph.draw_string_outline(font, merge + Vector2(-7, -8), "or", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, OUTLINE)
	tech_graph.draw_string(font, merge + Vector2(-7, -8), "or", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _arrow_color(r: String, lit: bool, focus: bool) -> Color:
	var col: Color = _tech_color(r) if lit else DIM_ARROW
	if focus:
		col = col.lightened(0.2) if lit else Color(1, 1, 1, 0.9)
	return col


## Where arrows leave a tech's card: the middle of its right edge.
func _card_out(tech: String) -> Vector2:
	return _card_pos(tech) + Vector2(CARD.x, CARD.y / 2.0)


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
		item_boxes[id].tooltip_text = _item_tooltip(id)
		var zero_color := BAD if Data.FOOD_VALUE.has(id) else Color(1, 1, 1, 0.45)
		item_labels[id].add_theme_color_override("font_color", zero_color if n == 0 else Color.WHITE)
	var note := state.growth_note()
	var idle := state.idle_kith()
	kith_label.text = (
		"Kith %d/%d%s%s"
		% [
			state.kith.size(),
			state.housing(),
			(", %d %s" % [idle, "hauling" if state.has_haulers() else "idle"]) if idle > 0 else "",
			"  (" + note + ")" if note != "" else "  (growing)",
		]
	)
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
		var label: String = (
			def["name"] + " (" + (_progress_text(def["cost"], 99) if short != "" else _cost_text(def["cost"])) + ")"
		)
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
		b.text = (
			"Craft %s (%s)" % [rec["name"], _progress_text(rec["in"], 99) if short != "" else _cost_text(rec["in"])]
		)
		b.disabled = short != ""

	_refresh_tech_panel()

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


func _refresh_tech_panel() -> void:
	for tech in tech_cards:
		var c: Dictionary = tech_cards[tech]
		c["card"].visible = state.tech_visible(tech)
		var done: bool = state.researched.has(tech)
		var ready := state.requirements_met(tech)
		var can := state.can_research(tech)
		var col := _tech_color(tech)
		var style := _panel_style(Color("32607f"), 8)
		style.border_color = col
		if done:
			style.bg_color = col.darkened(0.55)
			c["status"].text = "Discovered"
		elif can:
			style.border_color = GOAL_COLOR
			style.set_border_width_all(4)
			c["status"].text = "Ready to research"
		elif ready:
			c["status"].text = _progress_text(Data.TECHS[tech]["cost"], 2)
		else:
			style.bg_color = Color("22384f")
			style.border_color = col.darkened(0.4)
			var missing := state.missing_requirements(tech)
			c["status"].text = "Needs %d more tech%s" % [missing, "" if missing == 1 else "s"]
		if tech == selected_tech:
			style.border_color = Color.WHITE
			style.set_border_width_all(4)
		var hover_style := style.duplicate()
		hover_style.bg_color = style.bg_color.lightened(0.12)
		for st in ["normal", "pressed", "focus"]:
			c["card"].add_theme_stylebox_override(st, style)
		c["card"].add_theme_stylebox_override("hover", hover_style)
		c["card"].modulate = Color(1, 1, 1, 1) if done or ready else Color(1, 1, 1, 0.6)

	var t: Dictionary = Data.TECHS[selected_tech]
	tech_detail["title"].text = t["name"]
	tech_detail["title"].add_theme_color_override("font_color", _tech_color(selected_tech).lightened(0.3))
	tech_detail["desc"].text = t["desc"]
	tech_detail["needs"].text = "Needs: " + _needs_text(selected_tech)
	tech_detail["unlocks"].text = "Unlocks: " + _unlocks_text(selected_tech)
	tech_detail["cost"].text = "Cost: " + _progress_text(t["cost"], 99)
	var b: Button = tech_detail["button"]
	b.disabled = not state.can_research(selected_tech)
	if state.researched.has(selected_tech):
		b.text = "Discovered"
	elif not state.requirements_met(selected_tech):
		b.text = "Research what it needs first"
	elif b.disabled:
		b.text = "Gather more to research"
	else:
		b.text = "Research " + t["name"]
	if tech_panel.visible:
		tech_graph.queue_redraw()


## "Masonry (done), one of Storytelling (not yet) or Star Lore (not yet)", or "nothing, start here".
func _needs_text(tech: String) -> String:
	var parts: Array = Data.TECHS[tech]["requires"].map(_need_name)
	var any: Array = _visible_any(tech).map(_need_name)
	if any.size() == 1:
		parts.append(any[0])
	elif any.size() > 1:
		parts.append("one of " + " or ".join(any))
	return ", ".join(parts) if not parts.is_empty() else "nothing, start here"


func _need_name(r: String) -> String:
	return Data.TECHS[r]["name"] + (" (done)" if state.researched.has(r) else " (not yet)")


## "Wood 5/20, Stone 10/10": what you have toward each cost. Shows at most `limit` entries.
func _progress_text(cost: Dictionary, limit: int) -> String:
	var parts: Array = []
	for id in cost:
		parts.append("%s %d/%d" % [Data.ITEMS[id]["name"], mini(state.inv.get(id, 0), cost[id]), cost[id]])
	if parts.size() > limit:
		return ", ".join(parts.slice(0, limit)) + ", ..."
	return ", ".join(parts)


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
			var speed := state.work_speed(b)
			if speed > 1.0:
				s += "\nWorks %d%% faster (Ochre, Standing Stones)" % roundi((speed - 1.0) * 100.0)
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
	var r := state.hut_radius()
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
		var d: Dictionary = Data.TECHS[t]
		if state.tech_visible(t) and (tech in d["requires"] or tech in d.get("requires_any", [])):
			next.append(d["name"])
	var s := ", ".join(parts) if not parts.is_empty() else "nothing to build"
	if not next.is_empty():
		s += ". Leads to " + ", ".join(next)
	return s


func _item_tooltip(id: String) -> String:
	var s: String = Data.ITEMS[id]["name"]
	if Data.FOOD_VALUE.has(id):
		s += ": food worth %d. The Kith eat it." % int(state.food_value(id))
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
		Art.outlined_circle(self, c, 5.0, KITH.lightened(0.25) if k["job"] == "haul" else KITH)
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
				draw_colored_polygon(PackedVector2Array([c - w, c + w, c + half + w, c + half - w]), dirt)
