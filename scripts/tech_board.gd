extends Control
## The tech board: lane bands, tier columns, one compact card per tech and neutral lines between them. Hovering a card
## lights the lines to the techs it needs and the ones it leads to (one step each way) and dims the rest.
##
## The board always opens fitted: scaled to show a whole era in the space it has. From there the wheel (or the + and
## - buttons, or a pinch) zooms about the pointer, dragging empty space or a card pans, arrows or WASD pan while the
## board is open, and Fit (F) snaps back. The view eases to where it is going, and it is clamped so the tree can never
## be moved out of sight: zoomed out it is centred, zoomed in its edges stop at the edges of the board.
##
## Everything is drawn in screen space, so text stays sharp at any zoom. A label is never drawn under MIN_PX (14): at a
## low zoom the icon goes first so the name keeps the room, and a name too long for its card is trimmed with an ellipsis.

signal card_clicked(tech: String)
signal hover_changed(tech: String)

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const Ui = preload("res://scripts/ui.gd")
const TechLayout = preload("res://scripts/tech_layout.gd")
const Ranks = preload("res://scripts/ranks.gd")
const Rules = preload("res://scripts/rules.gd")

const MET := Ui.TEXT_DIM
const NEEDED := Ui.EDGE
const GOLD := Ui.HIGHLIGHT
const DONE_BG := Ui.CARD_DONE
const READY_BG := Ui.CARD
const LOCKED_BG := Ui.CARD_LOCKED
const LOCKED_TEXT := Ui.TEXT_DIM
const HIDDEN_EDGE := Ui.TEXT_DIM
const GATE := Ui.HIGHLIGHT
const GATE_BG := Ui.BAR

const MIN_ZOOM := 0.25  # a floor for the fit, so a tiny window never divides by nothing
const MAX_ZOOM := 2.0
const MAX_FIT := 1.3  # a small board is not blown up past this when it is fitted
const PAD := 6.0  # the margin the fit leaves around the board, in screen px
const WHEEL_STEP := 1.2  # one wheel notch zooms by this much
const BUTTON_STEP := 1.25  # the + and - buttons
const KEY_SPEED := 650.0  # screen px a second while an arrow or WASD key is held
const PAN_GESTURE := 14.0  # a trackpad's two-finger scroll, in px per unit of its delta
const EASE := 14.0  # how fast the view eases to its goal
const DRAG_START := 5.0  # px the pointer moves with the button down before a press becomes a pan
const NAME_PX := 15.0  # a card's name, in board px (its screen size is this times the zoom)
const MIN_PX := 14  # no label is drawn smaller than this on screen (the HUD's own minimum)
const ICON_ZOOM := 0.8  # below this zoom a card drops its icon to leave room for the name

var state: Sim
var lay: Dictionary
var era := 1  # the era whose board is shown
var selected := ""  # persistent presentation focus after a card click
var hovered := ""
var chain := {}  # techs lit by the hover: the hovered one, what it directly needs and what directly needs it
var bold: Font
var zoom := 1.0  # the view now: board px to screen px
var origin := Vector2.ZERO  # and where the board's top left is, in this control's pixels
var goal_zoom := 1.0  # the view the eased motion is heading for
var goal_origin := Vector2.ZERO
var fitted := true  # the whole era is in view (kept so across window resizes)
var pressing := false  # the left button is down on the board
var dragging := false  # ...and has moved far enough to be a pan, not a click
var press_at := Vector2.ZERO
var press_tech := ""  # the card under the press, if any: released without a drag it is a click


func setup(game: Sim) -> void:
	state = game
	lay = TechLayout.build(era)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 160)
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.6
	bold = fv
	resized.connect(_on_resized)


# --- Cards and the view ------------------------------------------------------


## A card's rectangle in board px (the layout's own coordinates).
func card_rect(tech: String) -> Rect2:
	return lay["rects"].get(tech, Rect2())


## A card's rectangle in this control's pixels, as it is drawn now.
func card_screen_rect(tech: String) -> Rect2:
	var r := card_rect(tech)
	return Rect2(origin + r.position * zoom, r.size * zoom)


## The whole board in this control's pixels, as it is drawn now.
func board_screen_rect() -> Rect2:
	return Rect2(origin, lay["size"] * zoom)


## A point on the board, in this control's pixels.
func to_screen(p: Vector2) -> Vector2:
	return origin + p * zoom


## A point of this control, on the board.
func to_board(p: Vector2) -> Vector2:
	return (p - origin) / zoom


## Whether the board has a card for this tech.
func shows(tech: String) -> bool:
	return lay["rects"].has(tech)


## Show another era's board (each era has its own tree), fitted.
func set_era(e: int) -> void:
	if e == era:
		return
	era = e
	selected = ""
	lay = TechLayout.build(era)
	_set_hover("")
	_rebuild_chain()
	fit(true)


## The zoom and origin that put a board of size `content` in a view of size `view`: as big as fits (never past
## MAX_FIT), centred, with PAD to spare. Pure, so the tests can ask it about any window.
static func fit_for(content: Vector2, view: Vector2) -> Dictionary:
	var z := 1.0
	if view.x > 0.0 and view.y > 0.0 and content.x > 0.0 and content.y > 0.0:
		z = clampf(minf((view.x - PAD * 2.0) / content.x, (view.y - PAD * 2.0) / content.y), MIN_ZOOM, MAX_FIT)
	return {"zoom": z, "origin": ((view - content * z) / 2.0).round()}


## The smallest zoom: the one that fits the whole era.
func min_zoom() -> float:
	return fit_for(lay["size"], size)["zoom"]


## Where the board's top left may sit at zoom `z`: centred along an axis where the board is smaller than the view,
## otherwise held so the board's edges never leave the view's.
func clamp_origin(o: Vector2, z: float) -> Vector2:
	var board: Vector2 = lay["size"] * z
	var out := o
	for axis in 2:
		if board[axis] <= size[axis]:
			out[axis] = ((size[axis] - board[axis]) / 2.0)
		else:
			out[axis] = clampf(o[axis], size[axis] - board[axis], 0.0)
	return out


## Fit the whole era in view (the Fit button, F, a new era, a new window size). `snap` skips the easing.
func fit(snap := false) -> void:
	var f := fit_for(lay["size"], size)
	goal_zoom = f["zoom"]
	goal_origin = f["origin"]
	fitted = true
	if snap:
		settle()
	queue_redraw()


## Zoom by `factor` about the screen point `at`, which stays under the pointer. Clamped between the fit and MAX_ZOOM.
func zoom_at(factor: float, at: Vector2) -> void:
	var lo := min_zoom()
	var z := clampf(goal_zoom * factor, lo, maxf(MAX_ZOOM, lo))
	if is_equal_approx(z, goal_zoom):
		return
	var anchor := (at - goal_origin) / goal_zoom
	goal_zoom = z
	goal_origin = clamp_origin(at - anchor * z, z)
	fitted = z <= lo + 0.001
	queue_redraw()


## Move the view by `by` screen px (the content follows the pointer), at once and clamped.
func pan_by(by: Vector2) -> void:
	goal_origin = clamp_origin(goal_origin + by, goal_zoom)
	origin = clamp_origin(origin + by, zoom)
	fitted = goal_zoom <= min_zoom() + 0.001
	queue_redraw()


## Jump to the goal view without easing (what a test or a new window wants).
func settle() -> void:
	zoom = goal_zoom
	origin = goal_origin
	queue_redraw()


func _on_resized() -> void:
	if lay.is_empty():
		return
	if fitted:
		fit(true)
		return
	goal_zoom = maxf(goal_zoom, min_zoom())
	goal_origin = clamp_origin(goal_origin, goal_zoom)
	settle()


func _process(delta: float) -> void:
	if state == null or not is_visible_in_tree():
		return
	var dir := Vector2(
		(
			float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
			- float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		),
		(
			float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
			- float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
		)
	)
	if dir != Vector2.ZERO:
		pan_by(-dir.normalized() * KEY_SPEED * delta)  # moving the view right moves the board left
	if absf(zoom - goal_zoom) > 0.0005 or origin.distance_to(goal_origin) > 0.3:
		var k := 1.0 - exp(-EASE * delta)
		zoom = lerpf(zoom, goal_zoom, k)
		origin = origin.lerp(goal_origin, k)
		queue_redraw()
	elif zoom != goal_zoom or origin != goal_origin:
		settle()


# --- Input -------------------------------------------------------------------


func _tech_at(p: Vector2) -> String:
	var at := to_board(p)
	for tech in Rules.era_techs(era):
		if shows(tech) and state.tech_tree.tech_visible(tech) and card_rect(tech).has_point(at):
			return tech
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if pressing:
			if not dragging and event.position.distance_to(press_at) >= DRAG_START:
				dragging = true
				_set_hover("")
			if dragging:
				pan_by(event.relative)
			return
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			pan_by(event.relative)
			return
		_set_hover(_tech_at(event.position))
	elif event is InputEventMouseButton:
		_on_button(event)
	elif event is InputEventMagnifyGesture:
		zoom_at(event.factor, event.position)
	elif event is InputEventPanGesture:
		pan_by(-event.delta * PAN_GESTURE)


func _on_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressing = true
				dragging = false
				press_at = event.position
				press_tech = _tech_at(event.position)
			else:
				var clicked := pressing and not dragging and press_tech != "" and _tech_at(event.position) == press_tech
				pressing = false
				dragging = false
				if clicked:
					card_clicked.emit(press_tech)
				press_tech = ""
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				zoom_at(pow(WHEEL_STEP, maxf(event.factor, 1.0)), event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				zoom_at(1.0 / pow(WHEEL_STEP, maxf(event.factor, 1.0)), event.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_set_hover("")


func focus_tech() -> String:
	return hovered if hovered != "" else selected


func set_selected(tech: String) -> void:
	selected = tech if shows(tech) and state.tech_tree.tech_visible(tech) else ""
	_rebuild_chain()
	queue_redraw()


func _rebuild_chain() -> void:
	chain = {}
	var tech := focus_tech()
	if tech != "":
		chain[tech] = true
		_add_neighbors(tech)


func _set_hover(tech: String) -> void:
	if tech == hovered:
		return
	hovered = tech
	tooltip_text = Data.TECHS[tech]["name"] if tech != "" else ""
	_rebuild_chain()
	hover_changed.emit(tech)
	queue_redraw()


## Light one step each way: the techs `tech` needs and the techs that need it. Nothing further.
func _add_neighbors(tech: String) -> void:
	for e in lay["edges"]:
		if e["to"] == tech and state.tech_tree.tech_visible(e["from"]):
			chain[e["from"]] = true
		elif e["from"] == tech and state.tech_tree.tech_visible(e["to"]):
			chain[e["to"]] = true


# --- Drawing (all in screen px) ----------------------------------------------


func _p(v: Vector2) -> Vector2:
	return origin.round() + v * zoom


func _r(r: Rect2) -> Rect2:
	return Rect2(_p(r.position), r.size * zoom)


## A label's size on screen for a board size of `base`: it scales with the zoom but is never under MIN_PX.
func _px(base: float) -> int:
	return maxi(roundi(base * zoom), MIN_PX)


## A line's width on screen: it scales a little, so it never vanishes zoomed out or turns heavy zoomed in.
func _w(base: float) -> float:
	return base * clampf(zoom, 0.8, 1.5)


func _text(at: Vector2, s: String, px: int, col: Color, width := -1.0, heavy := false) -> void:
	draw_string(
		bold if heavy else ThemeDB.fallback_font,
		at,
		s,
		HORIZONTAL_ALIGNMENT_LEFT,
		width,
		px,
		col,
		TextServer.JUSTIFICATION_NONE,
		TextServer.DIRECTION_AUTO,
		TextServer.ORIENTATION_HORIZONTAL,
		TextServer.OVERRUN_TRIM_ELLIPSIS
	)


func _draw() -> void:
	if lay.is_empty() or state == null:
		return
	var board_w: float = lay["size"].x
	for i in lay["lanes"].size():
		var lane: Dictionary = lay["lanes"][i]
		var band := _r(Rect2(0, lane["top"] - 6.0, board_w, lane["bottom"] - lane["top"] + 12.0))
		draw_rect(band, Color(0, 0, 0, 0.14 if i % 2 == 0 else 0.07))
		var col: Color = Ui.LANE_COLORS[lane["id"]]
		draw_rect(Rect2(band.position, Vector2(4, band.size.y)), col)
		var spaced := ""
		for ch in Data.LANES[lane["id"]]["name"].to_upper():
			spaced += ch + " "
		_text(_p(Vector2(TechLayout.LEFT, lane["top"] - 8.0)), spaced, _px(NAME_PX - 1.0), col)
	var captions: Array = Data.ERA_TIER_NAMES[era]
	for t in captions.size():
		var x := TechLayout.LEFT + t * TechLayout.PITCH
		_text(_p(Vector2(x, 15)), captions[t], _px(NAME_PX - 1.0), Color(Ui.TEXT, 0.75))
	for lit in [false, true]:
		for e in lay["edges"]:
			_draw_edge(e, lit)
	_draw_or_pills()
	for tech in Rules.era_techs(era):
		_draw_card(tech)


func _edge_visible(e: Dictionary) -> bool:
	return state.tech_tree.tech_visible(e["from"]) and state.tech_tree.tech_visible(e["to"])


## Focused prerequisites use brass, outgoing unlocks moss; other connections recede.
func _draw_edge(e: Dictionary, lit_pass: bool) -> void:
	if not _edge_visible(e):
		return
	var focused := focus_tech()
	var lit: bool = focused != "" and (e["from"] == focused or e["to"] == focused)
	if lit != lit_pass:
		return
	var met: bool = state.tech_tree.researched.has(e["from"])
	var col := MET if met else NEEDED
	var w := 2.5 if met else 2.0
	if lit:
		col = Ui.GOOD if e["from"] == focused else GOLD
		w = 3.5
	elif not chain.is_empty():
		col.a = 0.25
	var pts := PackedVector2Array()
	for p in e["pts"]:
		pts.append(_p(p))
	pts = Art.rounded(pts, 14.0 * zoom)
	draw_polyline(pts, col, _w(w), true)
	Art.small_head(self, pts[pts.size() - 1], col, 7.0 * clampf(zoom, 0.8, 1.4))


## "or" where either-or parents share one way in: only when both parents show.
func _draw_or_pills() -> void:
	for tech in lay["pills"]:
		var shown: Array = Data.TECHS[tech]["requires_any"].filter(func(p): return state.tech_tree.tech_visible(p))
		if shown.size() < 2:
			continue
		var c: Vector2 = lay["pills"][tech]
		var r := _r(Rect2(c - Vector2(14, 9), Vector2(28, 18)))
		var box := StyleBoxFlat.new()
		box.bg_color = Ui.BAR
		box.border_color = GOLD if chain.has(tech) else NEEDED
		box.set_border_width_all(2)
		box.set_corner_radius_all(8)
		draw_style_box(box, r)
		var px := _px(NAME_PX - 2.0)
		_text(Vector2(r.position.x + (r.size.x - px) / 2.0, r.get_center().y + px * 0.35), "or", px, Ui.TEXT)


func _draw_card(tech: String) -> void:
	var sr := _r(card_rect(tech))
	var t: Dictionary = Data.TECHS[tech]
	var dim := not chain.is_empty() and not chain.has(tech)
	var a := 0.55 if dim else 1.0
	if not state.tech_tree.tech_visible(tech):
		_draw_hidden(sr, a)
		return
	if t["lane"] == "gate":
		_draw_gate(tech, sr, a)
		return
	var done: bool = state.tech_tree.researched.has(tech)
	var is_ready := state.tech_tree.can_research(tech)
	var unbuilt := not Rules.tech_enabled(tech)  # its effect ships in the next update: shown, locked, never bought
	var open := state.tech_tree.requirements_met(tech) and not unbuilt
	var bg := Ui.SELECTED if tech == selected else (DONE_BG if done else (READY_BG if open else LOCKED_BG))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(bg, a)
	box.border_color = GOLD if tech == selected else Color(GOLD if is_ready or tech == hovered else Ui.EDGE, a)
	box.set_border_width_all(2 if is_ready or tech == selected or tech == hovered else 1)
	box.set_corner_radius_all(Ui.RADIUS)
	draw_style_box(box, sr)
	if tech == selected:
		draw_rect(Rect2(sr.position + Vector2(1, 1), Vector2(2, sr.size.y - 2)), GOLD)
	var pad := 6.0 * clampf(zoom, 0.8, 1.3)
	var x := sr.position.x + pad
	if card_icon_fits(tech, sr):
		var side := minf(sr.size.y - 8.0, 24.0 * zoom)
		var icon := Rect2(Vector2(x, sr.position.y + (sr.size.y - side) / 2.0 - 1.0), Vector2(side, side))
		draw_rect(icon, Color(Ui.BAR, a))
		Art.tech_icon(self, t["icon"], icon, 0.0)
		if not open and not done:
			draw_rect(icon, Color(Ui.BAR, 0.55))  # locked: washed out
		if dim:
			draw_rect(icon, Color(Ui.BAR, 0.75))
		draw_rect(icon, Color(Ui.EDGE, a), false, 1.0)
		x += side + pad
	var ranked := Ranks.has_ranks(tech)
	var right := sr.end.x - (34.0 if ranked else 24.0) * clampf(zoom, 0.8, 1.3)
	var text := Ui.TEXT if open or done else LOCKED_TEXT
	var px := _px(NAME_PX)
	var mid := sr.position.y + sr.size.y * 0.5 - 1.0
	_text(Vector2(x, mid + px * 0.35), t["name"], px, text, maxf(right - x, 10.0), true)
	if open and not done and not unbuilt:
		_draw_afford(tech, sr, is_ready, a)
	_draw_marks(tech, sr, a, is_ready, open, done)


## Names take priority over pictures. Keep status marks and 14 px text at every zoom.
func card_icon_fits(tech: String, sr: Rect2) -> bool:
	if zoom < ICON_ZOOM:
		return false
	var k := clampf(zoom, 0.8, 1.3)
	var side := minf(sr.size.y - 8.0, 24.0 * zoom)
	var reserve := (34.0 if Ranks.has_ranks(tech) else 24.0) * k
	var room := sr.size.x - 18.0 * k - side - reserve
	return bold.get_string_size(Data.TECHS[tech]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, _px(NAME_PX)).x <= room


## Gate titles wrap rather than losing the era's destination to an ellipsis.
func title_lines(text: String, width: float, px: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if line != "" and bold.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
			lines.append(line)
			line = word
		else:
			line = next
	if line != "":
		lines.append(line)
	return lines


## A thin bar along the foot of a card that can be discovered: how much of its price is in the stockpile. Gold, and full,
## when it can be paid for now.
func _draw_afford(tech: String, sr: Rect2, is_ready: bool, a: float) -> void:
	var cost := state.tech_tree.cost_of(tech)
	var total := 0
	var got := 0
	for id in cost:
		total += int(cost[id])
		got += mini(int(state.economy.inv.get(id, 0)), int(cost[id]))
	var h := maxf(3.0 * zoom, 3.0)
	var track := Rect2(sr.position.x + 5.0, sr.end.y - h - 4.0, sr.size.x - 10.0, h)
	draw_rect(track, Color(0, 0, 0, 0.35 * a))
	var fill := Rect2(track.position, Vector2(track.size.x * float(got) / float(maxi(total, 1)), h))
	draw_rect(fill, Color(GOLD if is_ready else Ui.TEXT_DIM, (1.0 if is_ready else 0.7) * a))


## The right end of a card: a check when discovered, a gold dot when it can be paid for now, a lock when it waits on
## others, the queue place when it is queued; and the diamonds of the optional upgrades for a tech that has them.
func _draw_marks(tech: String, sr: Rect2, a: float, is_ready: bool, open: bool, done: bool) -> void:
	var k := clampf(zoom, 0.8, 1.3)
	var ranked := Ranks.has_ranks(tech)
	var c := Vector2(sr.end.x - 14.0 * k, sr.position.y + sr.size.y * (0.36 if ranked else 0.5))
	var q := state.tech_tree.queue.find(tech)
	if done:
		var pts := PackedVector2Array([c + Vector2(-5, 0) * k, c + Vector2(-1, 4) * k, c + Vector2(6, -4) * k])
		draw_polyline(pts, Color(Ui.GOOD, a), 2.5, true)
	elif is_ready:
		Art.outlined_circle(self, c, 5.0 * k, Color(GOLD, a))
	elif q >= 0:
		Art.outlined_circle(self, c, 8.0 * k, Color(GOLD, a))
		var px := _px(NAME_PX - 2.0)
		_text(c + Vector2(-px * 0.3, px * 0.33), str(q + 1), px, Art.OUTLINE, -1.0, true)
	elif not open:
		draw_arc(c + Vector2(0, -1) * k, 3.5 * k, PI, TAU, 8, Color(LOCKED_TEXT, a * 0.8), 1.5, true)
		draw_rect(Rect2(c + Vector2(-4, -1) * k, Vector2(8, 7) * k), Color(LOCKED_TEXT, a * 0.8))
	if ranked:
		_draw_rank_pips(tech, Vector2(sr.end.x - 14.0 * k, sr.position.y + sr.size.y * 0.72), a, k)


## Ranks I to III as three small diamonds, gold for each rank held.
func _draw_rank_pips(tech: String, center: Vector2, a: float, k: float) -> void:
	var held := Ranks.rank(state, tech)
	for i in Data.MAX_RANK:
		var c := center + Vector2((i - 1) * 9.0 * k, 0)
		var s := 3.5 * k
		var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
		draw_colored_polygon(pts, Color(GOLD, a) if i < held else Color(Ui.TEXT, 0.18 * a))
		pts.append(pts[0])
		draw_polyline(pts, Color(Art.OUTLINE, a), 1.5, true)


## A tech the player has not met yet (Star Lore): a dashed outline and where to look, once the Strange Stone is seen.
func _draw_hidden(sr: Rect2, a: float) -> void:
	if not state.fog.is_revealed(state.world.shard_pos):
		return  # nothing to give away before the Strange Stone has been seen
	Art.dashed_rect(self, sr, Color(HIDDEN_EDGE, a), 2.0, 6.0, 4.0)
	var px := _px(NAME_PX - 1.0)
	_text(
		Vector2(sr.position.x + 10.0, sr.get_center().y + px * 0.35),
		"? " + Data.HIDDEN_CARD_HINT,
		px,
		Color(HIDDEN_EDGE, a),
		sr.size.x - 16.0
	)


## Bronze Dawn and the era's last gate: one tall card spanning every lane, listing what it needs and costs. The list of
## what it needs drops out when the board is small, and its count stays.
func _draw_gate(tech: String, sr: Rect2, a: float) -> void:
	var t: Dictionary = Data.TECHS[tech]
	var is_ready := state.tech_tree.can_research(tech)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(GATE_BG, a)
	box.border_color = GOLD if tech == selected else Color(GOLD if is_ready or tech == hovered else Ui.EDGE, a)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	draw_style_box(box, sr)
	draw_rect(Rect2(sr.position + Vector2(1, 1), Vector2(3, sr.size.y - 2)), Color(GATE, a))
	var side := clampf(34.0 * zoom, 24.0, 48.0)
	var x := sr.position.x + 12.0
	var width := sr.size.x - 22.0
	var y := sr.position.y + 12.0
	Art.tech_icon(
		self, t["icon"], Rect2(Vector2(sr.position.x + (sr.size.x - side) / 2.0, y), Vector2(side, side)), 0.0
	)
	var px := _px(NAME_PX)
	var line := float(px) + 4.0
	y += side + line
	for title_line in title_lines(t["name"], width, px):
		_text(Vector2(x, y), title_line, px, GATE, width, true)
		y += line
	y -= line
	var needs: Array = t["requires"]
	var left := needs.filter(func(n): return not state.tech_tree.researched.has(n)).size()
	var small := _px(NAME_PX - 2.0)
	y += line
	_text(Vector2(x, y), Data.GATE_NEEDS % needs.size() if left > 0 else Data.GATE_MET, small, Color(Ui.TEXT, 0.8 * a))
	if zoom >= ICON_ZOOM:
		for n in needs:
			y += line
			var col := Color(Ui.GOOD, a) if state.tech_tree.researched.has(n) else Color(LOCKED_TEXT, a)
			_text(Vector2(x, y), Data.TECHS[n]["name"], small, col, width)
	else:
		y += line
		_text(Vector2(x, y), Data.GATE_COUNT % [needs.size() - left, needs.size()], small, Color(Ui.TEXT, 0.8 * a))
	y += line * 1.3
	if not Rules.tech_enabled(tech):
		_text(Vector2(x, y), Data.TECH_UNBUILT, small, Color(GOLD, 0.8 * a), width)
		return
	_text(Vector2(x, y), Data.GATE_COST, small, Color(Ui.TEXT, 0.8 * a))
	var cost := state.tech_tree.cost_of(tech)
	for id in cost:
		y += line
		var have: int = state.economy.inv.get(id, 0)
		var need: int = cost[id]
		var col := Color(Ui.TEXT, a) if have >= need else Color(Ui.SHORT, a)
		Art.item_icon(self, id, Rect2(x, y - small - 1.0, small + 2.0, small + 2.0), a)
		_text(Vector2(x + small + 6.0, y), "%d/%d" % [mini(have, need), need], small, col, width - small - 6.0)
