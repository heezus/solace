extends RefCounted
## Where each card sits on the research board and how the lines between cards run.
## Pure geometry from Data.TECHS, so the headless tests can check that no line passes under a card.
##
## Columns are tiers and bands are lanes (Data.LANE_ORDER). Lines are orthogonal: a line to the next
## tier takes one vertical run in the gutter between the tiers; a line that skips tiers drops into the
## channel between lanes, runs along it, and climbs back up in the gutter before its target. Vertical
## runs get their own 7px track in a gutter and horizontal runs their own track in a channel.

const Data = preload("res://scripts/data.gd")

const CARD_W := 212.0
const CARD_H := 94.0
const CARD := Vector2(CARD_W, CARD_H)
const GATE_W := 132.0
const LEFT := 10.0
const GUTTER := 56.0
const PITCH := CARD_W + GUTTER
const HEADER := 24.0  # the tier names
const CHANNEL := 30.0  # between lanes, on top of the gap under the last row
const ROW := 102.0  # card height plus the gap between rows
const GAP := ROW - CARD_H
const STEP := 7.0  # track spacing for lines and ports


## {"rects": {tech: Rect2}, "lanes": [{id, top, bottom}], "channels": [Vector2(top, bottom)],
##  "edges": [{from, to, any, pts: PackedVector2Array}], "pills": {tech: Vector2}, "size": Vector2,
##  "overflow": int (runs that found no free track; 0 when the layout is clean)}.
static func build() -> Dictionary:
	var lay := {"rects": {}, "lanes": [], "channels": [], "edges": [], "pills": {}, "overflow": 0}
	var rows := {}
	for tech in Data.TECHS:
		var t: Dictionary = Data.TECHS[tech]
		rows[t["lane"]] = maxi(rows.get(t["lane"], 0), int(t["slot"]) + 1)
	var y := HEADER + CHANNEL
	var tops := {}
	lay["channels"].append(Vector2(HEADER, y))
	for lane in Data.LANE_ORDER:
		tops[lane] = y
		var bottom: float = y + rows[lane] * ROW - GAP
		lay["lanes"].append({"id": lane, "top": y, "bottom": bottom})
		y = bottom + GAP + CHANNEL
		lay["channels"].append(Vector2(bottom, y))
	var first_top: float = lay["lanes"][0]["top"]
	var last_bottom: float = lay["lanes"][-1]["bottom"]
	for tech in Data.TECHS:
		var t: Dictionary = Data.TECHS[tech]
		var x: float = LEFT + t["tier"] * PITCH
		if t["lane"] == "gate":
			lay["rects"][tech] = Rect2(x, first_top, GATE_W, last_bottom - first_top)
		else:
			lay["rects"][tech] = Rect2(x, tops[t["lane"]] + t["slot"] * ROW, CARD_W, CARD_H)
	var max_tier := 0
	for tech in Data.TECHS:
		max_tier = maxi(max_tier, Data.TECHS[tech]["tier"])
	lay["size"] = Vector2(LEFT + max_tier * PITCH + GATE_W + LEFT, y)
	_route(lay)
	return lay


## Every requirement as a line: {from, to, any, i}, `any` for one of an either-or, `i` its place in the list.
static func links() -> Array:
	var out: Array = []
	for tech in Data.TECH_ORDER:
		for r in Data.TECHS[tech]["requires"]:
			out.append({"from": r, "to": tech, "any": false, "i": out.size()})
		for r in Data.TECHS[tech].get("requires_any", []):
			out.append({"from": r, "to": tech, "any": true, "i": out.size()})
	return out


## Sort by y, then by list order, so ties always land the same way.
static func _by_y(lay: Dictionary, a: Dictionary, b: Dictionary, end: String) -> bool:
	var ya := _mid_y(lay, a[end])
	var yb := _mid_y(lay, b[end])
	if ya != yb:
		return ya < yb
	return a["i"] < b["i"]


static func _mid_y(lay: Dictionary, tech: String) -> float:
	var r: Rect2 = lay["rects"][tech]
	return r.position.y + r.size.y / 2.0


static func _key(e: Dictionary) -> String:
	return e["from"] + ">" + e["to"]


## Ports spread down a card's edges, sorted by where the other end is. Either-or parents share one.
static func _ports(lay: Dictionary, all: Array) -> Dictionary:
	var outs := {}
	var ins := {}
	for tech in Data.TECHS:
		var mine: Array = all.filter(func(e): return e["from"] == tech)
		mine.sort_custom(func(a, b): return _by_y(lay, a, b, "to"))
		for i in mine.size():
			outs[_key(mine[i])] = _mid_y(lay, tech) + (i - (mine.size() - 1) / 2.0) * STEP
	for tech in Data.TECHS:
		var mine: Array = all.filter(func(e): return e["to"] == tech)
		if Data.TECHS[tech]["lane"] == "gate":
			for e in mine:
				ins[_key(e)] = outs[_key(e)]  # straight in from the left
			continue
		mine.sort_custom(func(a, b): return _by_y(lay, a, b, "from"))
		var groups: Array = []
		for e in mine:
			var g: String = "any" if e["any"] else e["from"]
			if g not in groups:
				groups.append(g)
		# Keep in-ports off the y of any line leaving the tier before, so stubs never overlap.
		var tier: int = Data.TECHS[tech]["tier"]
		var before: Array = []
		for k in outs:
			if Data.TECHS[k.get_slice(">", 0)]["tier"] == tier - 1:
				before.append(outs[k])
		var shift := 0.0
		for cand in [0.0, 3.5, -3.5, 7.0, -7.0, 10.5, -10.5]:
			var clear := true
			for i in groups.size():
				var py: float = _mid_y(lay, tech) + cand + (i - (groups.size() - 1) / 2.0) * STEP
				for o in before:
					clear = clear and absf(py - o) >= 3.0
			if clear:
				shift = cand
				break
		for e in mine:
			var i := groups.find("any" if e["any"] else e["from"])
			ins[_key(e)] = _mid_y(lay, tech) + shift + (i - (groups.size() - 1) / 2.0) * STEP
	return {"out": outs, "in": ins}


static func _route(lay: Dictionary) -> void:
	var all := links()
	var ports := _ports(lay, all)
	var tracks := {}  # "g3:1" or "c2:0" -> Array of Vector2(lo, hi)
	# Short lines first, so they get the tracks nearest their cards.
	var order := all.duplicate()
	order.sort_custom(
		func(a, b):
			var da: int = Data.TECHS[a["to"]]["tier"] - Data.TECHS[a["from"]]["tier"]
			var db: int = Data.TECHS[b["to"]]["tier"] - Data.TECHS[b["from"]]["tier"]
			if da != db:
				return da < db
			var fa: int = Data.TECHS[a["from"]]["tier"]
			var fb: int = Data.TECHS[b["from"]]["tier"]
			if fa != fb:
				return fa < fb
			return a["i"] < b["i"]
	)
	for e in order:
		var ra: Rect2 = lay["rects"][e["from"]]
		var rb: Rect2 = lay["rects"][e["to"]]
		var yo: float = ports["out"][_key(e)]
		var yi: float = ports["in"][_key(e)]
		var ta: int = Data.TECHS[e["from"]]["tier"]
		var tb: int = Data.TECHS[e["to"]]["tier"]
		var ax := ra.end.x
		var bx := rb.position.x
		var pts := PackedVector2Array()
		if tb == ta + 1:
			if absf(yo - yi) < 0.5:
				pts = PackedVector2Array([Vector2(ax, yo), Vector2(bx, yi)])
			else:
				var gx := _gutter_track(lay, tracks, ta, yo, yi, false)
				pts = PackedVector2Array([Vector2(ax, yo), Vector2(gx, yo), Vector2(gx, yi), Vector2(bx, yi)])
		else:
			var c := _pick_channel(lay, tracks, e, yo, yi, ax, tb)
			var ch: Vector2 = lay["channels"][c]
			var x1 := _gutter_track(lay, tracks, ta, yo, ch.y if yo < ch.x else ch.x, false)
			if Data.TECHS[e["to"]]["lane"] == "gate":
				var hy := _channel_track(lay, tracks, c, x1, bx)
				pts = PackedVector2Array([Vector2(ax, yo), Vector2(x1, yo), Vector2(x1, hy), Vector2(bx, hy)])
			else:
				var x2 := _gutter_track(lay, tracks, tb - 1, ch.y if yi < ch.x else ch.x, yi, true)
				var hy := _channel_track(lay, tracks, c, x1, x2)
				pts = PackedVector2Array(
					[
						Vector2(ax, yo),
						Vector2(x1, yo),
						Vector2(x1, hy),
						Vector2(x2, hy),
						Vector2(x2, yi),
						Vector2(bx, yi)
					]
				)
		lay["edges"].append({"from": e["from"], "to": e["to"], "any": e["any"], "pts": pts})
		if e["any"]:
			lay["pills"][e["to"]] = Vector2(bx - 24.0, yi)


static func _lane_index(tech: String) -> int:
	return Data.LANE_ORDER.find(Data.TECHS[tech]["lane"])


## The channel a skipping line runs along: the target's `via` hint if it names one, else the one
## beside the source lane, toward the target, or the nearest one with a free track.
static func _pick_channel(
	lay: Dictionary, tracks: Dictionary, e: Dictionary, yo: float, yi: float, ax: float, tb: int
) -> int:
	var la := _lane_index(e["from"])
	var lb := _lane_index(e["to"])
	if lb < 0:
		lb = la
	var cands: Array = []
	if yi > yo + 1.0:
		for c in range(la + 1, maxi(lb, la + 1) + 1):
			cands.append(c)
	elif yi < yo - 1.0:
		for c in range(la, mini(lb + 1, la) - 1, -1):
			cands.append(c)
	else:
		cands = [la + 1, la]
	var hint := via_channel(e["to"], e["from"])
	if hint >= 0:
		cands.erase(hint)
		cands.push_front(hint)
	var first: int = cands[0]
	var rest: Array = []
	for c in lay["channels"].size():
		if c not in cands:
			rest.append(c)
	rest.sort_custom(
		func(a, b): return absi(a - first) < absi(b - first) or (absi(a - first) == absi(b - first) and a < b)
	)
	cands.append_array(rest)
	var x_end := LEFT + (tb - 1) * PITCH + CARD_W + 8.0 + _gutter_tracks() * STEP
	for c in cands:
		if _free_track(lay, tracks, "c%d" % c, _channel_tracks(lay, c), ax + 8.0, x_end) >= 0:
			return c
	return first


## The channel a tech's `via` hint (Data.TECHS) names for the line from `parent`, or -1 for none.
## "top" is the channel above the first lane; a lane id is the channel just below that lane.
static func via_channel(tech: String, parent: String) -> int:
	var via: String = Data.TECHS[tech].get("via", {}).get(parent, "")
	if via == "":
		return -1
	if via == "top":
		return 0
	var lane := Data.LANE_ORDER.find(via)
	return lane + 1 if lane >= 0 else -1


static func _channel_tracks(lay: Dictionary, c: int) -> int:
	var ch: Vector2 = lay["channels"][c]
	return int((ch.y - ch.x - 12.0) / STEP) + 1


static func _gutter_tracks() -> int:
	return int((GUTTER - 12.0) / STEP) + 1


## First track whose runs don't overlap lo..hi (with a margin), or -1.
static func _free_track(_lay: Dictionary, tracks: Dictionary, prefix: String, n: int, a: float, b: float) -> int:
	var lo := minf(a, b) - 4.0
	var hi := maxf(a, b) + 4.0
	for k in n:
		var clear := true
		for run in tracks.get(prefix + ":%d" % k, []):
			clear = clear and (hi < run.x or lo > run.y)
		if clear:
			return k
	return -1


static func _claim(tracks: Dictionary, key: String, a: float, b: float) -> void:
	if not tracks.has(key):
		tracks[key] = []
	tracks[key].append(Vector2(minf(a, b) - 4.0, maxf(a, b) + 4.0))


## x of a free vertical track in the gutter after tier g, covering y0..y1. Lines into a card take
## tracks from the right, lines out of one from the left.
static func _gutter_track(lay: Dictionary, tracks: Dictionary, g: int, y0: float, y1: float, from_right: bool) -> float:
	var n := _gutter_tracks()
	var lo := minf(y0, y1) - 4.0
	var hi := maxf(y0, y1) + 4.0
	for i in n:
		var k: int = n - 1 - i if from_right else i
		var clear := true
		for run in tracks.get("g%d:%d" % [g, k], []):
			clear = clear and (hi < run.x or lo > run.y)
		if clear:
			_claim(tracks, "g%d:%d" % [g, k], y0, y1)
			return LEFT + g * PITCH + CARD_W + 6.0 + k * STEP
	lay["overflow"] += 1
	return LEFT + g * PITCH + CARD_W + 6.0


## y of a free horizontal track in channel c, covering x0..x1.
static func _channel_track(lay: Dictionary, tracks: Dictionary, c: int, x0: float, x1: float) -> float:
	var k := _free_track(lay, tracks, "c%d" % c, _channel_tracks(lay, c), x0, x1)
	var ch: Vector2 = lay["channels"][c]
	if k < 0:
		lay["overflow"] += 1
		return ch.x + 6.0
	_claim(tracks, "c%d:%d" % [c, k], x0, x1)
	return ch.x + 6.0 + k * STEP
