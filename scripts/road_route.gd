extends RefCounted
## Routes for roads (fun playtest 6: roads could not cross flax, berries, grain or ore, and nothing said so until a line failed; both
## players lost 8 minutes or more). Two pure helpers on the Sim: `line`, the tiles a dragged road runs when the straight way is blocked
## (it goes around, and `note` says "Went around 3 Wild Flax tiles"), and `to_lay`, the tiles a building must lay to reach a depot by
## road ("Lay 4 road: (12,5) to (15,5)"). Both read the town's own placement rules, so a tile they offer is a tile a road takes.

const Data = preload("res://scripts/data.gd")
const Rules = preload("res://scripts/rules.gd")
const Roads = preload("res://scripts/roads.gd")

const MARGIN := 10  # tiles around the dragged corners a way round may use
const STEP := 10  # the cost of one tile
const TURN := 1  # the cost of a turn: a way round runs straight where it can
const LAY_RANGE := 16  # tiles from a building the search for a way to a depot goes
const SEGMENTS := 3  # runs of tiles the lay text names before it says "and more"
const LAY := "Lay %d road: %s"
const AROUND := "Went around %s"
const MORE := " and more"

static var _lines := {}  # a dragged line's key -> {"tiles": Array, "note": String}
static var _lays := {}  # a building's key -> {"tiles": Array, "to": Vector2i}


## True when a road of `type` takes tile `p` now, or one already runs there. Stock is no reason: the price is the line's to pay.
static func takes(s, type: String, p: Vector2i) -> bool:
	if not s.world.in_bounds(p):
		return false
	var err: String = s.town.placement_error(type, p)
	return err == "" or err == "Not enough materials" or err.begins_with("Already") or err.begins_with("A better")


## The tiles a drag from `a` to `b` covers: the straight way (along the row, then the column) when every tile takes the road, else
## the shortest way round the ground a road can't take, with the fewest turns. A bridge or a field keeps the straight way.
static func line(s, type: String, a: Vector2i, b: Vector2i) -> Array:
	var straight: Array = Rules.line_tiles(a, b)
	if not _is_road(type) or a == b or not _is_blocked(s, type, straight):
		return straight
	return _routed(s, type, a, b, straight)["tiles"]


## "Went around 3 Wild Flax tiles" for a line that was routed (what the straight way would have crossed), "" for a straight one.
static func note(s, type: String, line_tiles: Array) -> String:
	if line_tiles.size() < 2 or not _is_road(type):
		return ""
	var a: Vector2i = line_tiles[0]
	var b: Vector2i = line_tiles[line_tiles.size() - 1]
	var straight: Array = Rules.line_tiles(a, b)
	if straight == line_tiles or not _is_blocked(s, type, straight):
		return ""
	return _routed(s, type, a, b, straight)["note"]


static func _is_road(type: String) -> bool:
	return Data.BUILDINGS.has(type) and Data.BUILDINGS[type]["kind"] == "road"


static func _is_blocked(s, type: String, tiles: Array) -> bool:
	for p in tiles:
		if not takes(s, type, p):
			return true
	return false


static func _routed(s, type: String, a: Vector2i, b: Vector2i, straight: Array) -> Dictionary:
	var key := [type, a, b, s.town.road_rev, s.town.buildings.size()]
	if _lines.has(key):
		return _lines[key]
	if _lines.size() > 64:
		_lines.clear()
	var tiles: Array = []
	if takes(s, type, a) and takes(s, type, b):
		tiles = _dijkstra(s, type, a, b)
	var out := {"tiles": straight, "note": ""}
	if not tiles.is_empty():
		var named := {}
		for p in straight:
			if not takes(s, type, p):
				var name: String = Data.TILES[s.world.tile_at(p)]["name"]
				named[name] = int(named.get(name, 0)) + 1
		var parts: Array = []
		for name in named:
			parts.append("%d %s tile%s" % [named[name], name, "" if named[name] == 1 else "s"])
		out = {"tiles": tiles, "note": AROUND % " and ".join(parts) if not parts.is_empty() else ""}
	_lines[key] = out
	return out


## The cheapest way from a to b over the tiles a road takes: one tile costs STEP and a turn costs TURN more, so a way round is as
## straight as the ground allows. [] when there is none within MARGIN of the corners.
static func _dijkstra(s, type: String, a: Vector2i, b: Vector2i) -> Array:
	var lo := Vector2i(mini(a.x, b.x) - MARGIN, mini(a.y, b.y) - MARGIN).clamp(
		Vector2i.ZERO, Vector2i(s.world.width - 1, s.world.height - 1)
	)
	var hi := Vector2i(maxi(a.x, b.x) + MARGIN, maxi(a.y, b.y) + MARGIN).clamp(
		Vector2i.ZERO, Vector2i(s.world.width - 1, s.world.height - 1)
	)
	var ok := {}
	var best := {}  # (tile, heading) -> the cost so far
	var back := {}  # (tile, heading) -> the (tile, heading) before it
	var buckets := {0: [[a, -1]]}
	var cost := 0
	var left := 1
	var max_cost := (hi.x - lo.x + hi.y - lo.y + 8) * (STEP + TURN) * 3
	best[[a, -1]] = 0
	while left > 0 and cost <= max_cost:
		if not buckets.has(cost):
			cost += 1
			continue
		var at: Array = buckets[cost]
		buckets.erase(cost)
		for node in at:
			left -= 1
			if int(best.get(node, 1 << 30)) < cost:
				continue
			var p: Vector2i = node[0]
			if p == b:
				return _unwind(back, node)
			for h in Roads.SIDES.size():
				var q: Vector2i = p + Roads.SIDES[h]
				if q.x < lo.x or q.y < lo.y or q.x > hi.x or q.y > hi.y:
					continue
				if not ok.has(q):
					ok[q] = takes(s, type, q)
				if not ok[q]:
					continue
				var c: int = cost + STEP + (TURN if node[1] != -1 and node[1] != h else 0)
				var nxt := [q, h]
				if c < int(best.get(nxt, 1 << 30)):
					best[nxt] = c
					back[nxt] = node
					if not buckets.has(c):
						buckets[c] = []
					buckets[c].append(nxt)
					left += 1
	return []


static func _unwind(back: Dictionary, node: Array) -> Array:
	var out: Array = []
	var cur: Variant = node
	while cur != null:
		out.push_front(cur[0])
		cur = back.get(cur)
	return out


## The road a building at `p` must lay to reach a depot: {"tiles": the tiles to lay in order, "to": where it joins} ("tiles" is [] when
## no way is found within LAY_RANGE, or nothing is needed). It joins a road of a net that reaches a depot, or stops beside a depot.
static func to_lay(s, p: Vector2i) -> Dictionary:
	var key := [p, s.town.road_rev, s.town.buildings.size()]
	if _lays.has(key):
		return _lays[key]
	if _lays.size() > 128:
		_lays.clear()
	var out := {"tiles": [], "to": Vector2i(-1, -1)}
	var c: Dictionary = Roads._cache(s)
	var depots: Array = Roads.depots(s)
	var seen := {}
	var parent := {}
	var todo: Array = []
	for n in Roads.SIDES:
		var q: Vector2i = p + n
		if s.world.in_bounds(q) and (s.world.roads.has(q) or takes(s, "road", q)):
			seen[q] = true
			todo.append(q)
	var head := 0
	while head < todo.size():
		var q: Vector2i = todo[head]
		head += 1
		if _reaches_depot(c, depots, q):
			var path: Array = []
			var t: Vector2i = q
			while true:
				path.push_front(t)
				if not parent.has(t):
					break
				t = parent[t]
			out = {"tiles": path.filter(func(x): return not s.world.roads.has(x)), "to": q}
			break
		for n in Roads.SIDES:
			var r: Vector2i = q + n
			if seen.has(r) or maxi(absi(r.x - p.x), absi(r.y - p.y)) > LAY_RANGE:
				continue
			if s.world.roads.has(r) or takes(s, "road", r):
				seen[r] = true
				parent[r] = q
				todo.append(r)
	_lays[key] = out
	return out


## True when a road on `q` would touch a depot, or already sits in (or beside) a net that touches one.
static func _reaches_depot(c: Dictionary, depots: Array, q: Vector2i) -> bool:
	if c["net"].has(q) and _net_has_depot(c, c["net"][q]):
		return true
	for n in Roads.SIDES:
		var r: Vector2i = q + n
		if depots.has(r):
			return true
		if c["net"].has(r) and _net_has_depot(c, c["net"][r]):
			return true
	return false


static func _net_has_depot(c: Dictionary, id: int) -> bool:
	for depot in c["depot_nets"]:
		if id in c["depot_nets"][depot]:
			return true
	return false


## "Lay 4 road: (12,5) to (15,5)" for the tiles `tiles` in the order a road runs: each straight run is named by its two ends (a single
## tile by itself), the first SEGMENTS runs, then " and more". "" for no tiles.
static func lay_text(tiles: Array) -> String:
	if tiles.is_empty():
		return ""
	var runs: Array = []
	var start: Vector2i = tiles[0]
	var prev: Vector2i = tiles[0]
	var dir := Vector2i.ZERO
	for i in range(1, tiles.size()):
		var t: Vector2i = tiles[i]
		var step: Vector2i = t - prev
		if (
			(dir == Vector2i.ZERO or step == dir)
			and maxi(absi(step.x), absi(step.y)) == 1
			and absi(step.x) + absi(step.y) == 1
		):
			dir = step
			prev = t
			continue
		runs.append([start, prev])
		start = t
		prev = t
		dir = Vector2i.ZERO
	runs.append([start, prev])
	var parts: Array = []
	for i in mini(runs.size(), SEGMENTS):
		var r: Array = runs[i]
		parts.append(
			"(%d,%d)" % [r[0].x, r[0].y] if r[0] == r[1] else "(%d,%d) to (%d,%d)" % [r[0].x, r[0].y, r[1].x, r[1].y]
		)
	return LAY % [tiles.size(), ", ".join(parts)] + (MORE if runs.size() > SEGMENTS else "")
