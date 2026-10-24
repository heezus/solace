extends RefCounted
## Sight: hold Alt and the map shows where goods move and where the town is stuck (the director's Step 5). `gather` reads the
## sim once a second into plain lists; `draw` paints them on the map. Nothing here changes the sim, and with Sight off nothing runs
## but the key check (scripts/sight_layer.gd).
##
## gaps    {pos, code, text, loud}: every waiting building. `code` is WaitWhy's, or "held", "full", "resting", "paused", "alert".
##         A loud gap has words on the map; a quiet one (resting, paused, a hauler already on the way) is a dim dot.
## flows   {from, to, item, per_min}: what haulers delivered in the last minute, merged per place pair and good.
## depots  {pos, have, want, reach}: each Storehouse and the Hearth, its haulers, and its average trip in tiles.
## nets    {poles, at, asks, given}: each Power Pole net.
## lamps   {pos, r} and breaks (tiles): what slows the Bloom.

const Art = preload("res://scripts/art.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Data = preload("res://scripts/data.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Roads = preload("res://scripts/roads.gd")
const Ui = preload("res://scripts/ui.gd")
const WaitWhy = preload("res://scripts/wait_why.gd")

const QUIET := ["on_the_way", "free_hauler", "walking", "resting", "paused"]  # gap codes drawn as a dim dot
const FLOW_SPACING := 36.0  # px between the dots that travel along a flow
const FLOW_SPEED := 40.0  # px a second they travel
const HOVER_PX := 14.0  # a flow shows its label when the cursor is this close to it

## When true (the player asked for reduced motion) the flow dashes stand still. No settings page sets it yet.
static var reduced_motion := false

var gaps: Array = []
var flows: Array = []
var depots: Array = []
var nets: Array = []
var lamps: Array = []
var breaks: Array = []
var _view := Rect2()
var _sizes := {}  # label text -> its width in px at the current UI scale


## Read everything Sight shows from the sim `s`. Meant to be called about once a second.
func gather(s) -> void:
	gaps = _gaps(s)
	flows = _flows(s)
	depots = _depots(s)
	nets = _nets(s)
	lamps = []
	breaks = []
	for b in s.town.buildings:
		if b["type"] == "firebreak":
			breaks.append(b["pos"])
		elif b["type"] == "arc_lamp" and s.town.is_powered(b["pos"]):
			lamps.append({"pos": b["pos"], "r": float(Data.BUILDINGS["arc_lamp"]["light"])})


func gap_at(pos: Vector2i) -> Dictionary:
	for g in gaps:
		if g["pos"] == pos:
			return g
	return {}


func _gaps(s) -> Array:
	var out: Array = []
	for b in s.town.buildings:
		var g := _gap_of(s, b)
		if not g.is_empty():
			g["pos"] = b["pos"]
			out.append(g)
	return out


## {code, text, loud} for a waiting building, {} for one that works.
func _gap_of(s, b: Dictionary) -> Dictionary:
	if b["paused"]:
		return _gap("paused", Data.SIGHT_PAUSED)
	if b["status"] == Data.STORE_FULL_STATUS:
		return _gap("resting", Data.SIGHT_RESTING)
	var alert: String = b["alert"]
	if alert == "":
		return {}
	if alert == Data.HOLD_BACK_ALERT:
		return _gap("held", Data.SIGHT_HELD)
	if alert.begins_with("Full") and Roads.automated(s, b):
		return _gap("full", Data.SIGHT_FULL)
	if alert.begins_with("Needs "):
		if Roads.automated(s, b):
			var missing := WaitWhy.missing(s, b, Buildings.recipe_in(b))
			if missing != "":
				return _why(s, b, missing)
		elif s.tech_tree.researched.has("haulers"):
			return _gap("no_road", Data.SIGHT_NO_ROAD)
	return _gap("alert", Overlays.pill_text(alert) if alert.length() > 36 else alert)


## The gap WaitWhy finds for `b` lacking `item`, in Sight's short words.
func _why(s, b: Dictionary, item: String) -> Dictionary:
	return words(s, b, item, WaitWhy.of(s, b, item)["code"])


## The label for a WaitWhy `code` on `b` lacking `item`.
func words(s, b: Dictionary, item: String, code: String) -> Dictionary:
	var depot := Roads.depot_of(s, b)
	var name: String = s.hauling.names.get(depot, Data.HEARTH_NAME)
	var have: int = s.hauling.have(depot)
	var want: int = s.hauling.wanted(depot)
	match code:
		"out":
			return _gap(code, Data.SIGHT_OUT % Data.ITEMS[item]["name"])
		"no_road":
			return _gap(code, Data.SIGHT_NO_ROAD)
		"cut":
			return _gap(code, Data.SIGHT_CUT)
		"on_the_way":
			return _gap(code, Data.SIGHT_ON_THE_WAY)
		"no_hauler":
			return _gap(code, Data.SIGHT_NO_HAULER % [name, have, want])
		"kept_back":
			return _gap(code, Data.SIGHT_KEPT)
		"order_first":
			return _gap(code, Data.SIGHT_AHEAD)
		"free_hauler":
			return _gap(code, Data.SIGHT_FREE)
		"walking":
			return _gap(code, Data.SIGHT_WALKING)
	return _gap(code, Data.SIGHT_BUSY % [name, have, want])


func _gap(code: String, text: String) -> Dictionary:
	return {"code": code, "text": text, "loud": not code in QUIET}


## The last minute of deliveries, merged per (from, to, good), as amounts a minute.
func _flows(s) -> Array:
	var sums := {}
	for e in s.hauling.trip_log:
		var key := "%s>%s>%s" % [e["from"], e["to"], e["item"]]
		if not sums.has(key):
			sums[key] = {"from": e["from"], "to": e["to"], "item": e["item"], "per_min": 0.0}
		sums[key]["per_min"] += e["amount"] * 60.0 / s.hauling.LOG_WINDOW
	return sums.values()


func _depots(s) -> Array:
	var out: Array = []
	for d in Roads.depots(s):
		var have: int = s.hauling.have(d)
		var want: int = s.hauling.wanted(d)
		if have + want > 0:
			out.append({"pos": d, "have": have, "want": want, "reach": float(s.hauling.trip_tiles.get(d, 0.0))})
	return out


func _nets(s) -> Array:
	var out: Array = []
	for n in s.livewire.nets:
		if n["poles"].is_empty():
			continue
		out.append({"poles": n["poles"], "at": n["poles"][0], "asks": n["asks"], "given": n["given"]})
	return out


# --- Drawing -------------------------------------------------------------------------------------------------------------


## Paint Sight on the map `ci` (in map pixels). `mouse` is the cursor in the same space, `time` the animation clock and `view`
## the part of the map on screen: nothing outside it is drawn.
func draw(ci: CanvasItem, mouse: Vector2, time: float, view: Rect2) -> void:
	_view = view.grow(Overlays.TILE * 2.0)
	_draw_slowed(ci)
	_draw_nets(ci)
	_draw_depots(ci)
	_draw_flows(ci, mouse, time)
	_draw_gaps(ci, mouse)


func _draw_slowed(ci: CanvasItem) -> void:
	var col := Color(Ui.ACTION, 0.1)
	for l in lamps:
		var c := Overlays.center(l["pos"])
		if _view.grow(l["r"] * Overlays.TILE).has_point(c):
			ci.draw_circle(c, l["r"] * Overlays.TILE, col)
	for p in breaks:
		if _view.has_point(Overlays.center(p)):
			ci.draw_rect(Overlays.rect(p).grow(-4.0), Color(Ui.ACTION, 0.25), false, 2.0 * Art.ui_k)


func _draw_nets(ci: CanvasItem) -> void:
	var k := Art.ui_k
	for n in nets:
		var poles: Array = n["poles"]
		for i in poles.size():
			if not _view.has_point(Overlays.center(poles[i])):
				continue
			ci.draw_circle(Overlays.center(poles[i]), 4.0 * k, Ui.ACTION)
			for j in range(i + 1, poles.size()):
				if Vector2(poles[i]).distance_to(Vector2(poles[j])) <= Data.POLE_LINK:
					ci.draw_line(
						Overlays.center(poles[i]), Overlays.center(poles[j]), Color(Ui.ACTION, 0.8), 2.0 * k, true
					)
		var col: Color = Ui.BAD if n["asks"] > n["given"] else Ui.GOOD
		Art.outlined_text(
			ci, Overlays.center(n["at"]) + Vector2(8, -10) * k, Data.SIGHT_NET % [n["asks"], n["given"]], 14, col
		)


func _draw_depots(ci: CanvasItem) -> void:
	var k := Art.ui_k
	for d in depots:
		var c := Overlays.center(d["pos"])
		if not _view.grow(d["reach"] * Overlays.TILE).has_point(c):
			continue
		if d["reach"] > 0.0:
			ci.draw_arc(c, d["reach"] * Overlays.TILE, 0.0, TAU, 72, Color(Ui.ACTION, 0.4), 2.0 * k, true)
		var col: Color = Ui.GOOD if d["have"] >= d["want"] else Ui.BAD
		Art.outlined_text(ci, c + Vector2(-34, -30) * k, Data.SIGHT_DEPOT % [d["have"], d["want"]], 14, col)


func _draw_flows(ci: CanvasItem, mouse: Vector2, time: float) -> void:
	var k := Art.ui_k
	var shift := 0.0 if reduced_motion else time * FLOW_SPEED * k
	var spacing := FLOW_SPACING * k
	var hovered: Array = []
	for f in flows:
		var a := Overlays.center(f["from"])
		var b := Overlays.center(f["to"])
		if not _view.intersects(Rect2(a, b - a).abs()) or a.distance_to(b) < 2.0:
			continue
		var width := (2.0 + minf(f["per_min"] / 12.0, 4.0)) * k
		ci.draw_line(a, b, Color(Ui.ACTION, 0.4), width)
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var at := fposmod(shift, spacing)
		while at < length:
			ci.draw_circle(a + dir * at, width * 0.9, Ui.ACTION)
			at += spacing
		if _near(mouse, a, b) <= HOVER_PX * k:
			hovered.append(f)
	for row in hovered.size():
		var f: Dictionary = hovered[row]
		var text: String = Data.SIGHT_FLOW % [Data.ITEMS[f["item"]]["name"], roundi(f["per_min"])]
		Art.outlined_text(ci, mouse + Vector2(14, 18 + 18 * row) * k, text, 14, Ui.ACTION)


## The distance from point p to the segment a-b.
static func _near(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Loud gaps get words (the nearest to the cursor first, none over another); the rest, and any left out, a dot.
func _draw_gaps(ci: CanvasItem, mouse: Vector2) -> void:
	var k := Art.ui_k
	var font := ThemeDB.fallback_font
	var px := roundi(14.0 * k)
	var order := gaps.filter(func(g): return _view.has_point(Overlays.center(g["pos"])))
	order.sort_custom(
		func(x, y): return Overlays.center(x["pos"]).distance_to(mouse) < Overlays.center(y["pos"]).distance_to(mouse)
	)
	var taken: Array = []
	for g in order:
		var r := Overlays.rect(g["pos"])
		var dot := r.position + Vector2(9, 9) * k  # the alert badge already sits at the lower right
		if not g["loud"]:
			ci.draw_circle(dot, 4.0 * k, Color(Ui.TEXT_DIM, 0.7))
			continue
		if not _sizes.has(g["text"]):
			_sizes[g["text"]] = font.get_string_size(g["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var size: Vector2 = _sizes[g["text"]]
		var box := Rect2(
			Vector2(r.get_center().x - size.x / 2.0, r.position.y - size.y - 2.0 * k), size + Vector2(4, 4) * k
		)
		var clear := true
		for o in taken:
			if box.intersects(o):
				clear = false
				break
		ci.draw_circle(dot, 5.0 * k, Ui.BAD)
		if clear:
			taken.append(box)
			Art.outlined_text(ci, box.position + Vector2(2, size.y - 2), g["text"], 14, Ui.BAD)
