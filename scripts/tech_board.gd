extends Control
## The research board: lane bands, tier columns, one card per tech and neutral lines between them.
## Hovering a card lights its whole chain in gold. Drag empty space to pan.

signal card_clicked(tech: String)
signal hover_changed(tech: String)

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const TechLayout = preload("res://scripts/tech_layout.gd")
const Ranks = preload("res://scripts/ranks.gd")

const MET := Color("d3e2ef")
const NEEDED := Color("5f7d9c")
const GOLD := Color("ffd166")
const DONE_BG := Color("24475e")
const READY_BG := Color("32607f")
const LOCKED_BG := Color("1f3b53")
const LOCKED_TEXT := Color("b9c6d0")
const HIDDEN_EDGE := Color("8fb3c9")
const GATE := Color("e3a857")
const GATE_BG := Color("3a2f1f")

var state: Sim
var lay: Dictionary
var hovered := ""
var chain := {}  # techs lit by the hover: the hovered one, its ancestors and descendants
var bold: Font
var pan_from := Vector2(-1, -1)


func setup(game: Sim) -> void:
	state = game
	lay = TechLayout.build()
	custom_minimum_size = lay["size"]
	mouse_filter = Control.MOUSE_FILTER_PASS  # unhandled wheel events reach the ScrollContainer
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.6
	bold = fv


func card_rect(tech: String) -> Rect2:
	return lay["rects"][tech]


func _tech_at(p: Vector2) -> String:
	for tech in Data.TECH_ORDER:
		if card_rect(tech).has_point(p):
			return tech
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if pan_from.x >= 0.0 and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_pan(event.relative)
			return
		_set_hover(_tech_at(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var tech := _tech_at(event.position)
			if tech != "":
				card_clicked.emit(tech)
			else:
				pan_from = event.position
		else:
			pan_from = Vector2(-1, -1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_set_hover("")


func _pan(by: Vector2) -> void:
	var scroll := get_parent() as ScrollContainer
	if scroll != null:
		scroll.scroll_horizontal -= int(by.x)
		scroll.scroll_vertical -= int(by.y)


func _set_hover(tech: String) -> void:
	if tech == hovered:
		return
	hovered = tech
	chain = {}
	if tech != "":
		chain[tech] = true
		_walk(tech, true)
		_walk(tech, false)
	hover_changed.emit(tech)
	queue_redraw()


## Mark every visible ancestor (up) or descendant (down) of tech.
func _walk(tech: String, up: bool) -> void:
	for e in lay["edges"]:
		var near: String = e["to"] if up else e["from"]
		var far: String = e["from"] if up else e["to"]
		if near == tech and state.tech_visible(far) and not chain.has(far):
			chain[far] = true
			_walk(far, up)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for i in lay["lanes"].size():
		var lane: Dictionary = lay["lanes"][i]
		var band := Rect2(0, lane["top"] - 6.0, size.x, lane["bottom"] - lane["top"] + 12.0)
		draw_rect(band, Color(0, 0, 0, 0.14 if i % 2 == 0 else 0.07))
		var col: Color = Data.LANES[lane["id"]]["color"]
		draw_rect(Rect2(band.position, Vector2(4, band.size.y)), col)
		var lane_name: String = Data.LANES[lane["id"]]["name"].to_upper()
		var spaced := ""
		for ch in lane_name:
			spaced += ch + " "
		draw_string(font, Vector2(TechLayout.LEFT, lane["top"] - 10.0), spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
	for t in Data.TIER_NAMES.size():
		var x := TechLayout.LEFT + t * TechLayout.PITCH
		draw_string(font, Vector2(x, 16), Data.TIER_NAMES[t], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.75))
	for lit in [false, true]:
		for e in lay["edges"]:
			_draw_edge(e, lit)
	_draw_or_pills()
	for tech in Data.TECH_ORDER:
		_draw_card(tech)


func _edge_visible(e: Dictionary) -> bool:
	return state.tech_visible(e["from"]) and state.tech_visible(e["to"])


## Lines under the hover chain are drawn last, in gold, over the rest.
func _draw_edge(e: Dictionary, lit_pass: bool) -> void:
	if not _edge_visible(e):
		return
	var lit: bool = not chain.is_empty() and chain.has(e["from"]) and chain.has(e["to"])
	if lit != lit_pass:
		return
	var met: bool = state.researched.has(e["from"])
	var col := MET if met else NEEDED
	var w := 2.5 if met else 2.0
	if lit:
		col = GOLD
		w = 3.5
	elif not chain.is_empty():
		col.a = 0.25
	var pts := Art.rounded(e["pts"], 14.0)
	draw_polyline(pts, col, w, true)
	Art.small_head(self, pts[pts.size() - 1], col, 7.0)


## "or" where either-or parents share one way in: only when both parents show.
func _draw_or_pills() -> void:
	for tech in lay["pills"]:
		var shown: Array = Data.TECHS[tech]["requires_any"].filter(func(p): return state.tech_visible(p))
		if shown.size() < 2:
			continue
		var c: Vector2 = lay["pills"][tech]
		var r := Rect2(c - Vector2(11, 8), Vector2(22, 16))
		var box := StyleBoxFlat.new()
		box.bg_color = Color("172c4a")
		box.border_color = GOLD if chain.has(tech) else NEEDED
		box.set_border_width_all(2)
		box.set_corner_radius_all(8)
		draw_style_box(box, r)
		draw_string(
			ThemeDB.fallback_font, r.position + Vector2(5, 12), "or", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE
		)


func _draw_card(tech: String) -> void:
	var r := card_rect(tech)
	var t: Dictionary = Data.TECHS[tech]
	var dim := not chain.is_empty() and not chain.has(tech)
	var a := 0.25 if dim else 1.0
	if not state.tech_visible(tech):
		Art.dashed_rect(self, r, Color(HIDDEN_EDGE, a), 2.0, 6.0, 4.0)
		draw_string(bold, r.position + Vector2(16, 28), "? ? ?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, a))
		draw_string(
			ThemeDB.fallback_font,
			r.position + Vector2(16, 46),
			"Click the Strange Stone",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Color(HIDDEN_EDGE, a)
		)
		return
	if t["lane"] == "gate":
		_draw_gate(tech, r, a)
		return
	var done: bool = state.researched.has(tech)
	var is_ready := state.can_research(tech)
	var open := state.requirements_met(tech)
	var bg := DONE_BG if done else (READY_BG if open else LOCKED_BG)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(bg, a)
	box.border_color = Color(GOLD if is_ready else Art.OUTLINE, a)
	box.set_border_width_all(3 if is_ready or not t.get("side", false) else 2)
	box.set_corner_radius_all(6)
	draw_style_box(box, r)
	var icon := Rect2(r.position + Vector2(9, 9), Vector2(44, 44))
	draw_rect(icon, Color(0.1, 0.16, 0.24, a))
	Art.tech_icon(self, t["icon"], icon, 0.0)
	if not open and not done:
		draw_rect(icon, Color(0.12, 0.17, 0.22, 0.55))  # locked: washed out
	if dim:
		draw_rect(icon, Color(0.09, 0.17, 0.29, 0.75))
	draw_rect(icon, Color(Art.OUTLINE, a), false, 2.0)
	var text := Color(1, 1, 1, a) if open or done else Color(LOCKED_TEXT, a)
	var x := r.position.x + 62.0
	draw_string(bold, Vector2(x, r.position.y + 21), t["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 70.0, 13, text)
	var unlock: String = t["unlock"] + ("  ·  side branch" if t.get("side", false) else "")
	var sub := Color(text, text.a * 0.8)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(x, r.position.y + 37),
		unlock,
		HORIZONTAL_ALIGNMENT_LEFT,
		r.size.x - 70.0,
		10,
		sub
	)
	var next_rank := Ranks.next_cost(state, tech)
	if done and not next_rank.is_empty():
		# The next rank's cost, bought by clicking the card.
		var label := "Rank %s:" % Data.RANK_NAMES[Ranks.rank(state, tech) + 1]
		var col := Color(GOLD, a) if Ranks.can_buy(state, tech) else Color(1, 1, 1, 0.7 * a)
		draw_string(ThemeDB.fallback_font, Vector2(x, r.position.y + 54), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
		var w := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		_draw_cost(next_rank, Vector2(x + w + 5.0, r.position.y + 45), a)
		_draw_check(r.position + Vector2(r.size.x - 16, 13), a)
	elif done:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(x, r.position.y + 53),
			"Researched",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color(Ui.GOOD, a)
		)
		_draw_check(r.position + Vector2(r.size.x - 16, 13), a)
	else:
		_draw_cost(t["cost"], Vector2(x, r.position.y + 45), a)
	if is_ready:
		draw_circle(r.position + Vector2(r.size.x - 12, 12), 4.0, Color(GOLD, a))
	elif not open and not done:
		_draw_lock(r.position + Vector2(r.size.x - 16, 8), a * 0.7)
	if Ranks.has_ranks(tech):
		_draw_rank_pips(tech, r, a)
	var q := state.research_queue.find(tech)
	if q >= 0 and not is_ready:
		Art.outlined_circle(self, r.position + Vector2(r.size.x - 14, r.size.y - 13), 8.0, Color(GOLD, a))
		draw_string(
			bold,
			r.position + Vector2(r.size.x - 18, r.size.y - 9),
			str(q + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Art.OUTLINE
		)


## Cost as colored squares with have/need counts: red where the stockpile is short.
func _draw_cost(cost: Dictionary, at: Vector2, a: float) -> void:
	var x := at.x
	for id in cost:
		var have: int = state.inv.get(id, 0)
		var need: int = cost[id]
		draw_rect(Rect2(x, at.y + 1, 8, 8), Color(Data.ITEMS[id]["color"], a))
		draw_rect(Rect2(x, at.y + 1, 8, 8), Color(Art.OUTLINE, a), false, 1.0)
		var s := "%d" % need if have >= need else "%d/%d" % [have, need]
		var col := Color(1, 1, 1, 0.85 * a) if have >= need else Color(Color("ff9aa9"), a)
		draw_string(ThemeDB.fallback_font, Vector2(x + 11, at.y + 9), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
		x += 15.0 + ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 6.0


## Ranks I to III as three small diamonds under the icon, gold for each rank held.
func _draw_rank_pips(tech: String, r: Rect2, a: float) -> void:
	var held := Ranks.rank(state, tech)
	for i in Data.MAX_RANK:
		var c := r.position + Vector2(20 + i * 11, 57.5)
		var pts := PackedVector2Array(
			[c + Vector2(0, -3.5), c + Vector2(3.5, 0), c + Vector2(0, 3.5), c + Vector2(-3.5, 0)]
		)
		draw_colored_polygon(pts, Color(GOLD, a) if i < held else Color(1, 1, 1, 0.12 * a))
		pts.append(pts[0])
		draw_polyline(pts, Color(Art.OUTLINE, a), 1.5, true)


func _draw_check(c: Vector2, a: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-1, 4), c + Vector2(6, -4)])
	draw_polyline(pts, Color(Ui.GOOD, a), 2.5, true)


func _draw_lock(p: Vector2, a: float) -> void:
	draw_arc(p + Vector2(4, 5), 3.5, PI, TAU, 8, Color(LOCKED_TEXT, a), 1.5, true)
	draw_rect(Rect2(p + Vector2(0, 5), Vector2(8, 7)), Color(LOCKED_TEXT, a))


## Bronze Dawn: one tall card spanning every lane, listing what it needs and costs.
func _draw_gate(tech: String, r: Rect2, a: float) -> void:
	var t: Dictionary = Data.TECHS[tech]
	var is_ready := state.can_research(tech)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(GATE_BG, a)
	box.border_color = Color(GOLD if is_ready else Art.OUTLINE, a)
	box.set_border_width_all(3)
	box.set_corner_radius_all(8)
	draw_style_box(box, r)
	draw_rect(r.grow(-5), Color(GATE, a), false, 3.0)
	var icon := Rect2(r.position + Vector2((r.size.x - 44) / 2.0, 18), Vector2(44, 44))
	Art.tech_icon(self, t["icon"], icon, 0.0)
	var y := r.position.y + 84
	draw_string(
		bold, Vector2(r.position.x + 12, y), t["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 14, Color(GATE, a)
	)
	y += 22
	var needs: Array = t["requires"]
	var left := needs.filter(func(n): return not state.researched.has(n)).size()
	var head := "NEEDS ALL %d" % needs.size() if left > 0 else "ALL MET"
	draw_string(
		ThemeDB.fallback_font,
		Vector2(r.position.x + 12, y),
		head,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		Color(1, 1, 1, 0.75 * a)
	)
	for n in needs:
		y += 16
		var col := Color(Ui.GOOD, a) if state.researched.has(n) else Color(LOCKED_TEXT, a)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(r.position.x + 12, y),
			Data.TECHS[n]["name"],
			HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - 20,
			11,
			col
		)
	y += 26
	draw_string(
		ThemeDB.fallback_font,
		Vector2(r.position.x + 12, y),
		"COST",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		Color(1, 1, 1, 0.75 * a)
	)
	for id in t["cost"]:
		y += 16
		var have: int = state.inv.get(id, 0)
		var need: int = t["cost"][id]
		var col := Color(1, 1, 1, a) if have >= need else Color(Color("ff9aa9"), a)
		var line := "%s %d/%d" % [Data.ITEMS[id]["name"], mini(have, need), need]
		draw_string(
			ThemeDB.fallback_font,
			Vector2(r.position.x + 12, y),
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - 20,
			11,
			col
		)
