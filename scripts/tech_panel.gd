extends PanelContainer
## The tech tree: cards laid out by tier, with arrows from each tech to what it leads to.
## Click a card to see its details below it; click a ready card again to research it.

const Data = preload("res://scripts/data.gd")
const GameState = preload("res://scripts/game_state.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")

const CARD := Vector2(186, 54)
const COL_W := 238.0
const ROW_H := 64.0
const DIM_ARROW := Color(0.75, 0.8, 0.85, 0.35)

var state: GameState
var selected_tech := "foraging"
var tech_cards := {}
var tech_graph: Control
var tech_detail := {}


func setup(game: GameState) -> void:
	state = game
	add_theme_stylebox_override("panel", Ui.panel_style(Ui.PANEL, 16))
	set_anchors_preset(Control.PRESET_CENTER)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_child(Ui.label("Stone Age: Tech Tree", 22))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := Ui.button("Close (T)")
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	v.add_child(head)
	v.add_child(
		Ui.label("Arrows show what each tech leads to. Dashed arrows: either one will do. Gold outline: ready now.", 13)
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
		card.position = card_pos(tech)
		card.size = CARD
		card.tooltip_text = Data.TECHS[tech]["desc"]
		card.pressed.connect(_select_tech.bind(tech))
		var h := HBoxContainer.new()
		h.position = Vector2(8, 8)
		h.add_theme_constant_override("separation", 8)
		h.add_child(Ui.badge(tech))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.add_child(Ui.label(Data.TECHS[tech]["name"], 14))
		var status := Ui.label("", 11)
		tv.add_child(status)
		h.add_child(tv)
		card.add_child(h)
		Ui.ignore_mouse(h)
		tech_graph.add_child(card)
		tech_cards[tech] = {"card": card, "status": status}

	# Details of the selected tech.
	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", Ui.panel_style(Ui.BAR, 10))
	v.add_child(detail)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 16)
	detail.add_child(dh)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(dv)
	tech_detail["title"] = Ui.label("", 18)
	dv.add_child(tech_detail["title"])
	for key in ["desc", "needs", "unlocks", "cost"]:
		var l := Ui.label("", 13)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(700, 0)
		dv.add_child(l)
		tech_detail[key] = l
	var research := Ui.button("Research")
	research.custom_minimum_size = Vector2(220, 48)
	research.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	research.add_theme_font_size_override("font_size", 16)
	research.pressed.connect(
		func():
			state.research(selected_tech)
			refresh()
	)
	dh.add_child(research)
	tech_detail["button"] = research

	# Center after layout settles, and whenever it opens.
	resized.connect(_center)
	visibility_changed.connect(_center)


func _center() -> void:
	position = (get_viewport_rect().size - size) / 2.0


static func card_pos(tech: String) -> Vector2:
	var p: Vector2 = Data.TECHS[tech]["pos"]
	return Vector2(p.x * COL_W, p.y * ROW_H)


func _select_tech(tech: String) -> void:
	if selected_tech == tech and state.can_research(tech):
		state.research(tech)  # second click on a ready tech researches it
	selected_tech = tech
	refresh()


## Curved arrows from each requirement to the tech that needs it. Lit once the requirement is done;
## the selected tech's arrows are drawn thick. Hidden techs and their arrows are left out.
func _draw_tech_arrows() -> void:
	for tech in Data.TECHS:
		if not state.tech_visible(tech):
			continue
		var to := card_pos(tech) + Vector2(-2, CARD.y / 2.0)
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
	var to := card_pos(tech) + Vector2(-2, CARD.y * 0.8)
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
	tech_graph.draw_arc(merge, 5.0, 0, TAU, 16, Ui.OUTLINE, 1.5, true)
	var font := ThemeDB.fallback_font
	tech_graph.draw_string_outline(
		font, merge + Vector2(-7, -8), "or", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Ui.OUTLINE
	)
	tech_graph.draw_string(font, merge + Vector2(-7, -8), "or", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _arrow_color(r: String, lit: bool, focus: bool) -> Color:
	var col: Color = Ui.tech_color(r) if lit else DIM_ARROW
	if focus:
		col = col.lightened(0.2) if lit else Color(1, 1, 1, 0.9)
	return col


## Where arrows leave a tech's card: the middle of its right edge.
func _card_out(tech: String) -> Vector2:
	return card_pos(tech) + Vector2(CARD.x, CARD.y / 2.0)


func refresh() -> void:
	for tech in tech_cards:
		var c: Dictionary = tech_cards[tech]
		c["card"].visible = state.tech_visible(tech)
		var done: bool = state.researched.has(tech)
		var ready := state.requirements_met(tech)
		var can := state.can_research(tech)
		var col := Ui.tech_color(tech)
		var style := Ui.panel_style(Ui.CARD, 8)
		style.border_color = col
		if done:
			style.bg_color = Color("24475e")  # card-done
			c["status"].text = "Discovered"
		elif can:
			style.border_color = Ui.HIGHLIGHT
			style.set_border_width_all(4)
			c["status"].text = "Ready to research"
		elif ready:
			c["status"].text = Ui.progress_text(state.inv, Data.TECHS[tech]["cost"], 2)
		else:
			style.bg_color = Color("1f3b53")  # card-locked
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
	tech_detail["title"].add_theme_color_override("font_color", Ui.tech_color(selected_tech).lightened(0.3))
	tech_detail["desc"].text = t["desc"]
	tech_detail["needs"].text = "Needs: " + _needs_text(selected_tech)
	tech_detail["unlocks"].text = "Unlocks: " + _unlocks_text(selected_tech)
	tech_detail["cost"].text = "Cost: " + Ui.progress_text(state.inv, t["cost"], 99)
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
	if visible:
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
