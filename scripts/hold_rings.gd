extends RefCounted
## The rings drawn over a resource tile while the player gathers by hand: the hold ring, a ring waiting out its time and the
## hint after a click that let go too soon. Static; `m` is the map (scripts/main.gd), which these draw on.

const Data = preload("res://scripts/data.gd")
const Art = preload("res://scripts/art.gd")
const Hands = preload("res://scripts/hands.gd")


static func draw(m) -> void:
	_hold_ring(m)
	_waiting_ring(m)
	_nudge(m)


## Hold to harvest: an outline ring over the held tile, with a highlight arc filling clockwise from the top.
static func _hold_ring(m) -> void:
	if (
		not m.holding
		or not m.state.world.in_bounds(m.state.harvest_tile)
		or Hands.item_at(m.state, m.state.harvest_tile) == ""
	):
		return
	var c: Vector2 = m._tile_center(m.state.harvest_tile)
	var radius: float = m.TILE * 0.42
	m.draw_arc(c, radius, 0.0, TAU, 40, m.OUTLINE, 7.0, true)
	m.draw_arc(c, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.3), 3.0, true)
	if m.state.harvest_frac > 0.0:
		var to: float = -PI / 2.0 + TAU * m.state.harvest_frac
		m.draw_arc(c, radius, -PI / 2.0, to, maxi(4, int(40 * m.state.harvest_frac)), m.GOAL_COLOR, 4.0, true)


## A ring that is waiting (a tap that let go early, a slip off the tile): it stays on its tile, fading as its time runs out.
static func _waiting_ring(m) -> void:
	var w: Dictionary = m.state.harvest_ring["aside"]
	if (
		w.is_empty()
		or Hands.item_at(m.state, w["tile"]) == ""
		or (not m.nudge.is_empty() and m.nudge["tile"] == w["tile"])
	):
		return  # (a quick click's hint already draws that ring)
	var fade: float = clampf(w["left"] / Data.HOLD_KEEP, 0.0, 1.0)
	var c: Vector2 = m._tile_center(w["tile"])
	var radius: float = m.TILE * 0.42
	m.draw_arc(c, radius, 0.0, TAU, 40, Color(m.OUTLINE, 0.6 * fade), 7.0, true)
	m.draw_arc(c, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.2 * fade), 3.0, true)
	var frac: float = w["held"] / Hands.hold_time(m.state, Hands.item_at(m.state, w["tile"]))
	var to: float = -PI / 2.0 + TAU * clampf(frac, 0.0, 1.0)
	m.draw_arc(c, radius, -PI / 2.0, to, maxi(4, int(40 * frac)), Color(m.GOAL_COLOR, fade), 4.0, true)


## A quick click on a resource: the ring shows how far the hold got and fades, with a hint to keep the button down.
static func _nudge(m) -> void:
	if m.nudge.is_empty():
		return
	var p: Vector2i = m.nudge["tile"]
	var fade: float = clampf(2.0 * (1.0 - m.nudge["t"] / m.NUDGE_TIME), 0.0, 1.0)
	var c: Vector2 = m._tile_center(p)
	var radius: float = m.TILE * 0.42
	m.draw_arc(c, radius, 0.0, TAU, 40, Color(m.OUTLINE, fade), 7.0, true)
	m.draw_arc(c, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.3 * fade), 3.0, true)
	var to: float = -PI / 2.0 + TAU * maxf(m.nudge["frac"], 0.12)  # always a little arc, so the ring reads as unfinished
	m.draw_arc(c, radius, -PI / 2.0, to, 12, Color(m.GOAL_COLOR, fade), 4.0, true)
	var item: String = Hands.item_at(m.state, p)
	if item != "":
		var secs: String = str(snappedf(Hands.hold_time(m.state, item), 0.1))
		Art.pill(
			m, c + Vector2(0, m.TILE * 0.7), "Hold the mouse down for %ss to gather" % secs, m.GOAL_COLOR, m.OUTLINE, 12
		)
