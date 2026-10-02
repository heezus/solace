extends RefCounted
## Haulers need roads (design-system/14-hands-to-haulers.md): after Paths & Haulers, a building runs
## on its own and haulers serve it only while a road links it to the Hearth or a Storehouse. A building
## is linked when it touches (side by side, not diagonally) a road tile of a network that also touches
## a depot, or the depot itself (right next door, no road is needed). Haulers walk that network only;
## unlinked buildings work as before Haulers (click to send a trip, click to load or collect). Static,
## and works on the Sim passed in: it reads the map and the roads from its World and walk costs
## from its Pathing. It is not part of either block, because the networks also depend on the buildings.
##
## The networks are cached in s.town.road_net and rebuilt when s.town.road_rev changes (place and demolish bump
## it): {"rev", "depots", "posts", "net": road tile -> network id, "depot_nets": depot pos -> [ids] (each depot's
## own doorstep id first), "link": building pos -> [network id, depot pos], "grid": an AStarGrid2D where
## only road tiles are open, "cart_grid": the same without the Wooden Bridges: a cart will not cross one}.

const Data = preload("res://scripts/data.gd")
const Kith = preload("res://scripts/kith.gd")
const Buildings = preload("res://scripts/buildings.gd")

const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## True once a road links building b to a depot.
static func linked(s, b: Dictionary) -> bool:
	return _cache(s)["link"].has(b["pos"])


## True when a road tile that was laid touches b and its network reaches a depot. Standing right beside a
## depot links a building too (linked), but that is not a road: the "Lay a Road" goal asks for this.
static func road_linked(s, b: Dictionary) -> bool:
	var c := _cache(s)
	for n in SIDES:
		var q: Vector2i = b["pos"] + n
		if c["net"].has(q) and _net_has_depot(c, c["net"][q]):
			return true
	return false


## True while b runs on its own with haulers: Paths & Haulers is in and a road links it.
static func automated(s, b: Dictionary) -> bool:
	return s.tech_tree.researched.has("haulers") and linked(s, b)


## The depot a road links b to (the nearest one on its network), or (-1, -1).
static func depot_of(s, b: Dictionary) -> Vector2i:
	var l: Array = _cache(s)["link"].get(b["pos"], [])
	return l[1] if not l.is_empty() else Vector2i(-1, -1)


## The depots that road-linked workshops and huts depend on (each building's `depot_of`), in depot order: where
## idle haulers should wait, so every depot with work has haulers and not only the Hearth.
static func posts(s) -> Array:
	return _cache(s)["posts"]


## Network ids touching the depot at p ([] when no road reaches it).
static func depot_nets(s, p: Vector2i) -> Array:
	return _cache(s)["depot_nets"].get(p, [])


## The road network id b is linked by, or -1.
static func net_of(s, b: Dictionary) -> int:
	var l: Array = _cache(s)["link"].get(b["pos"], [])
	return l[0] if not l.is_empty() else -1


## The Hearth and every Storehouse.
static func depots(s) -> Array:
	return _cache(s)["depots"]


static func _find_depots(s) -> Array:
	var out: Array = [s.world.camp_pos]
	for b in s.town.buildings:
		if Data.BUILDINGS[b["type"]]["kind"] == "depot":
			out.append(b["pos"])
	return out


## Walk Kith k to `to` along roads only (its own tile and `to` may be off the road: a depot or a
## building beside it). Returns false if the roads don't join them.
static func walk(s, k: Dictionary, to: Vector2i) -> bool:
	var from: Vector2i = Kith.tile_of(k)
	if from == to:
		k["path"] = []
		return true
	var path := _route(s, from, to, bool(k.get("cart", false)))
	if path.is_empty():
		return false
	path.remove_at(0)
	k["path"] = Array(path)
	return true


## True when a cart can roll from `from` to `to` along the roads (a Wooden Bridge in the way stops it).
static func cart_can_reach(s, from: Vector2i, to: Vector2i) -> bool:
	return from == to or not _route(s, from, to, true).is_empty()


## The road tiles from `from` to `to`, both ends included ([] when the roads don't join them). The two ends may be
## off the road.
static func _route(s, from: Vector2i, to: Vector2i, cart: bool) -> Array:
	var grid: AStarGrid2D = _cache(s)["cart_grid" if cart else "grid"]
	var ends := [from, to]
	var was: Array = ends.map(func(p): return grid.is_point_solid(p))
	for p in ends:
		grid.set_point_solid(p, false)
	var path := Array(grid.get_id_path(from, to))
	for i in ends.size():
		grid.set_point_solid(ends[i], was[i])
	return path


## The road tiles a new road from p should run along to join the nearest network that reaches a
## depot, or the nearest depot itself: a straight-line guide for the hover text and the bot.
## Returns {"to": Vector2i, "tiles": int}, "to" is (-1, -1) when p is already linked.
static func gap(s, p: Vector2i) -> Dictionary:
	var c := _cache(s)
	for n in SIDES:
		if c["depot_nets"].has(p + n) or (c["net"].has(p + n) and _net_has_depot(c, c["net"][p + n])):
			return {"to": Vector2i(-1, -1), "tiles": 0}
	var best := Vector2i(-1, -1)
	var best_d := 99999
	var targets: Array = depots(s).duplicate()
	for q in c["net"]:
		if _net_has_depot(c, c["net"][q]):
			targets.append(q)
	for q in targets:
		var d := maxi(absi(q.x - p.x), absi(q.y - p.y))
		if d < best_d:
			best = q
			best_d = d
	return {"to": best, "tiles": maxi(best_d - 1, 0)}


static func _net_has_depot(c: Dictionary, id: int) -> bool:
	for depot in c["depot_nets"]:
		if id in c["depot_nets"][depot]:
			return true
	return false


static func _cache(s) -> Dictionary:
	var c: Dictionary = s.town.road_net
	var fast: Array = [s.tech_tree.researched.has("paved_roads"), s.tech_tree.researched.has("causeways")]
	if c.get("rev", -1) == s.town.road_rev and c.get("fast", []) == fast:
		return c
	c = _build(s)
	s.town.road_net = c
	return c


static func _build(s) -> Dictionary:
	var net := {}
	var next_id := 0
	for start in s.world.roads:
		if net.has(start):
			continue
		var todo: Array = [start]
		net[start] = next_id
		while not todo.is_empty():
			var p: Vector2i = todo.pop_back()
			for n in SIDES:
				var q: Vector2i = p + n
				if s.world.roads.has(q) and not net.has(q):
					net[q] = next_id
					todo.append(q)
		next_id += 1
	var at_depot := {}
	var all_depots := _find_depots(s)
	for depot in all_depots:
		var ids: Array = [-2 - all_depots.find(depot)]  # its own doorstep: buildings right beside it
		for n in SIDES:
			if net.has(depot + n) and not net[depot + n] in ids:
				ids.append(net[depot + n])
		at_depot[depot] = ids
	var link := {}
	for b in s.town.buildings:
		if not Buildings.needs_worker(b):
			continue
		var best: Array = []
		var best_d := INF
		for n in SIDES:
			var q: Vector2i = b["pos"] + n
			if at_depot.has(q):
				best = [at_depot[q][0], q]
				best_d = -1.0  # right beside a depot beats any road
				continue
			if not net.has(q):
				continue
			for depot in at_depot:
				if net[q] in at_depot[depot]:
					var d := Vector2(depot).distance_to(Vector2(b["pos"]))
					if d < best_d:
						best = [net[q], depot]
						best_d = d
		if not best.is_empty():
			link[b["pos"]] = best
	var grid := _road_grid(s, false)
	var cart_grid := _road_grid(s, true)
	var waiting_posts: Array = []
	for depot in all_depots:
		for b in link:
			if link[b][1] == depot:
				waiting_posts.append(depot)
				break
	return {
		"rev": s.town.road_rev,
		"depots": all_depots,
		"posts": waiting_posts,
		"fast": [s.tech_tree.researched.has("paved_roads"), s.tech_tree.researched.has("causeways")],
		"net": net,
		"depot_nets": at_depot,
		"link": link,
		"grid": grid,
		"cart_grid": cart_grid,
	}


## An AStarGrid2D where only the road tiles are open (not the Wooden Bridges, for a cart).
static func _road_grid(s, cart: bool) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, s.world.width, s.world.height)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	grid.fill_solid_region(grid.region, true)
	for p in s.world.roads:
		if cart and s.world.is_wooden_bridge(p):
			continue
		grid.set_point_solid(p, false)
		grid.set_point_weight_scale(p, s.pathing.walk_cost(p))
	return grid
