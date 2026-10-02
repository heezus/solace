extends Control
## The tech board: lane bands, tier columns, one card per tech and neutral lines between them. Hovering a card
## lights the lines to the techs it needs and the ones it leads to (one step each way) and dims the rest.
## Two views: the whole board, or "next steps", a plain grid of just what can be discovered next.
## Drag empty space to pan.

signal card_clicked(tech: String)
signal hover_changed(tech: String)

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const TechLayout = preload("res://scripts/tech_layout.gd")
const Ranks = preload("res://scripts/ranks.gd")
const Rules = preload("res://scripts/rules.gd")

const MET := Color("d3e2ef")
const NEEDED := Color("5f7d9c")
const GOLD := Color("ffd166")
const DONE_BG := Color("24475e")
const READY_BG := Color("32607f")
const LOCKED_BG := Color("1f3b53")
const LOCKED_TEXT := Color("b9c6d0")
const GRID_COLS := 4  # the next-steps view: cards per row
const GRID_GAP := 24.0
const GRID_MARGIN := 16.0
const PIP := 20.0  # a cost item's sprite
const HIDDEN_EDGE := Color("8fb3c9")
const GATE := Color("e3a857")
const GATE_BG := Color("3a2f1f")

var state: Sim
var lay: Dictionary
var era := 1  # the era whose board is shown
var hovered := ""
var chain := {}  # techs lit by the hover: the hovered one, what it directly needs and what directly needs it
var view := "all"  # "next": a grid of what can be discovered next; "all": the whole board
var grid := {}  # tech -> Rect2, the cards in the next-steps view
var bold: Font
var pan_from := Vector2(-1, -1)


func setup(game: Sim) -> void:
	state = game
	lay = TechLayout.build(era)
	custom_minimum_size = lay["size"]
	mouse_filter = Control.MOUSE_FILTER_PASS  # unhandled wheel events reach the ScrollContainer
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.6
	bold = fv


func card_rect(tech: String) -> Rect2:
	if view == "next" and grid.has(tech):
		return grid[tech]
	return lay["rects"].get(tech, Rect2())


## Whether the current view shows this tech's card.
func shows(tech: String) -> bool:
	return lay["rects"].has(tech) if view == "all" else grid.has(tech)


## Show another era's board (each era has its own tree).
func set_era(e: int) -> void:
	if e == era:
		return
	era = e
	lay = TechLayout.build(era)
	_set_hover("")
	grid = {}
	update_view()
	queue_redraw()


## The techs that can be discovered next: not done, everything they need is, built, and in this era's tree. Affordable
## ones first.
func next_techs() -> Array:
	var out: Array = Rules.era_techs(era).filter(
		func(t):
			return (
				not state.tech_tree.researched.has(t) and Rules.tech_enabled(t) and state.tech_tree.requirements_met(t)
			)
	)
	out.sort_custom(func(a, b): return state.tech_tree.can_research(a) and not state.tech_tree.can_research(b))
	return out


## Switch views, and lay out the grid of next steps when that is the view.
func set_view(v: String) -> void:
	view = v
	_set_hover("")
	update_view()


## Keep the view's layout and size right (the grid follows what is next as techs are discovered).
func update_view() -> void:
	if view == "all":
		grid = {}
		custom_minimum_size = lay["size"]
		return
	var techs := next_techs()
	if techs.size() != grid.size() or techs.any(func(t): return not grid.has(t)):
		grid = {}
		for i in techs.size():
			var col := i % GRID_COLS
			var row := floori(float(i) / GRID_COLS)
			grid[techs[i]] = Rect2(
				Vector2(
					GRID_MARGIN + col * (TechLayout.CARD_W + GRID_GAP),
					GRID_MARGIN + row * (TechLayout.CARD_H + GRID_GAP)
				),
				TechLayout.CARD
			)
	var rows := ceili(float(maxi(grid.size(), 1)) / GRID_COLS)
	custom_minimum_size = Vector2(
		GRID_MARGIN * 2 + GRID_COLS * (TechLayout.CARD_W + GRID_GAP),
		GRID_MARGIN * 2 + rows * (TechLayout.CARD_H + GRID_GAP)
	)
	queue_redraw()


func _tech_at(p: Vector2) -> String:
	for tech in Rules.era_techs(era):
		if shows(tech) and state.tech_tree.tech_visible(tech) and card_rect(tech).has_point(p):
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
	if tech != "" and view == "all":
		chain[tech] = true
		_add_neighbors(tech)
	hover_changed.emit(tech)
	queue_redraw()


## Light one step each way: the techs `tech` needs and the techs that need it. Nothing further.
func _add_neighbors(tech: String) -> void:
	for e in lay["edges"]:
		if e["to"] == tech and state.tech_tree.tech_visible(e["from"]):
			chain[e["from"]] = true
		elif e["from"] == tech and state.tech_tree.tech_visible(e["to"]):
			chain[e["to"]] = true


func _draw() -> void:
	if view == "next":
		_draw_next()
		return
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
	var captions: Array = Data.ERA_TIER_NAMES[era]
	for t in captions.size():
		var x := TechLayout.LEFT + t * TechLayout.PITCH
		draw_string(font, Vector2(x, 16), captions[t], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.75))
	for lit in [false, true]:
		for e in lay["edges"]:
			_draw_edge(e, lit)
	_draw_or_pills()
	for tech in Rules.era_techs(era):
		_draw_card(tech)


## The next-steps view: just the cards, in a grid, or a note when there is nothing to discover yet.
func _draw_next() -> void:
	if grid.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			Vector2(GRID_MARGIN, 40),
			Data.NEXT_NONE,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color(1, 1, 1, 0.7)
		)
	for tech in grid:
		_draw_card(tech)


func _edge_visible(e: Dictionary) -> bool:
	return state.tech_tree.tech_visible(e["from"]) and state.tech_tree.tech_visible(e["to"])


## Lines under the hover chain are drawn last, in gold, over the rest.
func _draw_edge(e: Dictionary, lit_pass: bool) -> void:
	if not _edge_visible(e):
		return
	var lit: bool = hovered != "" and (e["from"] == hovered or e["to"] == hovered)
	if lit != lit_pass:
		return
	var met: bool = state.tech_tree.researched.has(e["from"])
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
		var shown: Array = Data.TECHS[tech]["requires_any"].filter(func(p): return state.tech_tree.tech_visible(p))
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
	if not state.tech_tree.tech_visible(tech):
		if not state.fog.is_revealed(state.world.shard_pos):
			return  # nothing to give away before the Strange Stone has been seen
		Art.dashed_rect(self, r, Color(HIDDEN_EDGE, a), 2.0, 6.0, 4.0)
		draw_string(bold, r.position + Vector2(16, 28), "? ? ?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, a))
		draw_string(
			ThemeDB.fallback_font,
			r.position + Vector2(16, 46),
			Data.HIDDEN_CARD_HINT,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Color(HIDDEN_EDGE, a)
		)
		return
	if t["lane"] == "gate":
		_draw_gate(tech, r, a)
		return
	var done: bool = state.tech_tree.researched.has(tech)
	var is_ready := state.tech_tree.can_research(tech)
	var unbuilt := not Rules.tech_enabled(tech)  # its effect ships in the next update: shown, locked, never bought
	var open := state.tech_tree.requirements_met(tech) and not unbuilt
	var bg := DONE_BG if done else (READY_BG if open else LOCKED_BG)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(bg, a)
	box.border_color = Color(GOLD if is_ready else Art.OUTLINE, a)
	box.set_border_width_all(3 if is_ready or not t.get("side", false) else 2)
	box.set_corner_radius_all(6)
	draw_style_box(box, r)
	var icon := Rect2(r.position + Vector2(8, 8), Vector2(36, 36))
	draw_rect(icon, Color(0.1, 0.16, 0.24, a))
	Art.tech_icon(self, t["icon"], icon, 0.0)
	if not open and not done:
		draw_rect(icon, Color(0.12, 0.17, 0.22, 0.55))  # locked: washed out
	if dim:
		draw_rect(icon, Color(0.09, 0.17, 0.29, 0.75))
	draw_rect(icon, Color(Art.OUTLINE, a), false, 2.0)
	var text := Color(1, 1, 1, a) if open or done else Color(LOCKED_TEXT, a)
	var x := r.position.x + 52.0  # the text beside the icon
	var x0 := r.position.x + 8.0  # the cost rows run the whole width under it
	draw_string(bold, Vector2(x, r.position.y + 22), t["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 78.0, 14, text)
	var builds := Rules.buildings_of(tech)
	var shows_build := not done and not builds.is_empty() and not unbuilt  # a second cost row: what the building costs after
	var unlock: String = t["unlock"] + ("  ·  " + Data.TECH_OPTIONAL if t.get("side", false) else "")
	var sub := Color(text, text.a * 0.8)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(x, r.position.y + 37),
		unlock,
		HORIZONTAL_ALIGNMENT_LEFT,
		r.size.x - (100.0 if Ranks.has_ranks(tech) else 62.0),
		10,
		sub
	)
	var next_rank := Ranks.next_cost(state, tech)
	if done and not next_rank.is_empty():
		# The next rank's cost, bought by clicking the card.
		var label := "Rank %s:" % Data.RANK_NAMES[Ranks.rank(state, tech) + 1]
		var col := Color(GOLD, a) if Ranks.can_buy(state, tech) else Color(1, 1, 1, 0.7 * a)
		draw_string(
			ThemeDB.fallback_font, Vector2(x0, r.position.y + 62), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col
		)
		var w := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		_draw_cost(next_rank, Vector2(x0 + w + 5.0, r.position.y + 48), a)
		_draw_check(r.position + Vector2(r.size.x - 16, 13), a)
	elif done:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(x0, r.position.y + 62),
			Data.TECH_DONE,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color(Ui.GOOD, a)
		)
		_draw_check(r.position + Vector2(r.size.x - 16, 13), a)
	elif unbuilt:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(x0, r.position.y + 62),
			Data.TECH_UNBUILT,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color(GOLD, 0.8 * a)
		)
	else:
		_draw_cost(state.tech_tree.cost_of(tech), Vector2(x0, r.position.y + 48), a)
		if shows_build:
			_draw_build_cost(tech, builds[0], Vector2(x0, r.position.y + 70), a)
	if is_ready:
		draw_circle(r.position + Vector2(r.size.x - 12, 12), 4.0, Color(GOLD, a))
	elif not open and not done:
		_draw_lock(r.position + Vector2(r.size.x - 16, 8), a * 0.7)
	if Ranks.has_ranks(tech):
		_draw_rank_pips(tech, r, a)
	var q := state.tech_tree.queue.find(tech)
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


## Cost as item sprites with have/need counts, the count red where the stockpile is short.
func _draw_cost(cost: Dictionary, at: Vector2, a: float, stock: Dictionary = {}) -> void:
	var x := at.x
	var held: Dictionary = stock if not stock.is_empty() else state.economy.inv
	var font := ThemeDB.fallback_font
	for id in cost:
		var have: int = held.get(id, 0)
		var need: int = cost[id]
		Art.item_icon(self, id, Rect2(x, at.y, PIP, PIP), a)
		var s := "%d/%d" % [mini(have, need), need]
		var col := Color(1, 1, 1, 0.9 * a) if have >= need else Color(Ui.SHORT, a)
		draw_string(font, Vector2(x + PIP + 1, at.y + 15), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		x += PIP + 1.0 + font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0


## "Builds:" and what the tech's first building costs, in the same colored squares. A count is red where paying
## for the tech would leave the stockpile short of it (shown as what you'd have left over the cost).
func _draw_build_cost(tech: String, type: String, at: Vector2, a: float) -> void:
	var label := "builds:"
	draw_string(
		ThemeDB.fallback_font,
		Vector2(at.x, at.y + 14),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		9,
		Color(1, 1, 1, 0.6 * a)
	)
	var w := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var left := Rules.left_after(state.economy.inv, state.tech_tree.cost_of(tech))
	_draw_cost(Data.BUILDINGS[type]["cost"], Vector2(at.x + w + 5.0, at.y), a, left)


## Ranks I to III as three small diamonds at the end of the summary line, gold for each rank held.
func _draw_rank_pips(tech: String, r: Rect2, a: float) -> void:
	var held := Ranks.rank(state, tech)
	for i in Data.MAX_RANK:
		var c := r.position + Vector2(r.size.x - 44 + i * 11, 32.0)
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
	var is_ready := state.tech_tree.can_research(tech)
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
	var left := needs.filter(func(n): return not state.tech_tree.researched.has(n)).size()
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
		var col := Color(Ui.GOOD, a) if state.tech_tree.researched.has(n) else Color(LOCKED_TEXT, a)
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
	if not Rules.tech_enabled(tech):
		draw_string(
			ThemeDB.fallback_font,
			Vector2(r.position.x + 12, y),
			Data.TECH_UNBUILT,
			HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - 20,
			11,
			Color(GOLD, 0.8 * a)
		)
		return
	draw_string(
		ThemeDB.fallback_font,
		Vector2(r.position.x + 12, y),
		"COST",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		Color(1, 1, 1, 0.75 * a)
	)
	var cost := state.tech_tree.cost_of(tech)
	for id in cost:
		y += 16
		var have: int = state.economy.inv.get(id, 0)
		var need: int = cost[id]
		var col := Color(1, 1, 1, a) if have >= need else Color(Ui.SHORT, a)
		var line := "%d/%d" % [mini(have, need), need]
		Art.item_icon(self, id, Rect2(r.position.x + 10, y - 13, 16, 16), a)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(r.position.x + 30, y),
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - 40,
			11,
			col
		)
