extends RefCounted
## Blueprints, the Exodus's gift (design-system/12-knowledge-is-progress.md, 18-roadmap.md): a boxed part of the town (its roads,
## fields and buildings) saved under a name, and laid down again anywhere as plans. A blueprint keeps kinds and offsets, never
## places: [{"t": building type, "x": column, "y": row}] from the box's top left corner. Up to Data.EXODUS["bp_max"] are held. They live
## in the run's Carry (scripts/carry.gd), which begins with the ones banked in the profile (only an Exodus banks a run's blueprints,
## scripts/profile.gd).
## Laying one down queues a plan for every part. A plan is built when its turn comes and its tech is known, its ground is open and the
## stockpile pays for it, exactly as if the player had placed it: nothing is free, though a plan laid from a banked blueprint (one an
## Exodus carried from an earlier run: the Kin have built it before) costs Data.EXODUS["bp_share"] of the price, each item rounded up.
## materials holds what follows it back, so a road grid does not eat the stone its smelter is waiting on. A part whose tech is not known
## or whose ground is still in the fog is passed over until it can go. A part that can never go (the ground is wrong, something stands
## there) is dropped. Nothing here happens in a first run that never saves a blueprint.

const Data = preload("res://scripts/data.gd")

const WAITS := ["Not enough materials", "Not discovered yet"]  # the reasons a plan stays queued; anything else drops it
const UNEXPLORED := "Unexplored"


## The parts of the town inside `box` (tile corners inclusive), in the order they should go down: roads and bridges, then fields, then
## buildings, each by row then column. The Hearth is never kept, nor any part whose kind is in `skip` (a tool for a player who boxes
## a yard and leaves its gatherers behind, and for the bots).
static func parts_in(s, box: Rect2i, skip := []) -> Array:
	var roads := []
	var fields := []
	var buildings := []
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var p := Vector2i(x, y)
			var type: String = s.town.built_type(p)
			if type == "":
				continue
			var kind: String = Data.BUILDINGS[type]["kind"]
			var part := {"t": type, "x": x - box.position.x, "y": y - box.position.y}
			if kind == "camp" or kind in skip:
				continue
			if kind in ["road", "bridge"]:
				roads.append(part)
			elif kind == "field":
				fields.append(part)
			else:
				buildings.append(part)
	return roads + fields + buildings


## The blueprint of the part of the town in `box`, named `label`: {} when there is nothing in it to keep. It is not put in the book.
static func make(s, box: Rect2i, label: String, skip := []) -> Dictionary:
	var parts := parts_in(s, box, skip)
	if parts.is_empty():
		return {}
	# banked false: saved this run, full price; an Exodus banks it, and a later run lays it at Data.EXODUS["bp_share"]
	return {"name": label, "w": box.size.x, "h": box.size.y, "items": parts, "banked": false}


## Keep the part of the town in `box` as a new blueprint. Returns "" when it was saved, otherwise the reason it was not.
static func save(s, box: Rect2i, label := "", skip := []) -> String:
	if s.carry.blueprints.size() >= int(Data.EXODUS["bp_max"]):
		return Data.EXODUS["bp_full"]
	var n: int = s.carry.blueprints.size() + 1
	var bp := make(s, box, label if label != "" else Data.EXODUS["bp_name"] % n, skip)
	if bp.is_empty():
		return Data.EXODUS["bp_nothing"]
	s.carry.blueprints.append(bp)
	s.events.append(Data.EXODUS["bp_saved"] % [s.carry.blueprints[n - 1]["name"], bp["items"].size()])
	return ""


## Throw blueprint `i` away. False when there is none.
static func drop(s, i: int) -> bool:
	if i < 0 or i >= s.carry.blueprints.size():
		return false
	s.carry.blueprints.remove_at(i)
	return true


## Lay blueprint `i` down with its top left corner at `at`: queue a plan for every part that falls on the map. Returns how many were queued.
## A part already queued at the same tile is replaced, so laying the same blueprint twice queues it once.
static func lay(s, i: int, at: Vector2i) -> int:
	if i < 0 or i >= s.carry.blueprints.size():
		return 0
	return lay_plan(s, s.carry.blueprints[i], at)


## Queue a plan for every part of blueprint `bp` (one of the book's, or the founding plan) with its top left corner at `at`.
static func lay_plan(s, bp: Dictionary, at: Vector2i) -> int:
	var n := 0
	for part in bp["items"]:
		var p := at + Vector2i(int(part["x"]), int(part["y"]))
		if not s.world.in_bounds(p):
			continue
		s.carry.plans = s.carry.plans.filter(func(q): return Vector2i(int(q["x"]), int(q["y"])) != p)
		s.carry.plans.append({"t": part["t"], "x": p.x, "y": p.y, "b": bool(bp.get("banked", false))})
		n += 1
	if n > 0:
		s.events.append(Data.EXODUS["bp_laid"] % [n, bp["name"]])
	return n


## The queued plans in order, as tile positions.
static func plan_tiles(s) -> Array:
	return s.carry.plans.map(func(q): return Vector2i(int(q["x"]), int(q["y"])))


## Build what the plans allow now: walk the queue in order, place each part that can go, keep the ones that are waiting, drop the ones
## that never can. Called every tick of the Sim; does nothing while there are no plans.
static func tick(s) -> void:
	if s.carry.plans.is_empty():
		return
	var keep := []
	var dropped := []  # the kinds of the parts that never can go
	var held := false  # a part waits on materials: the ones behind it wait their turn
	for q in s.carry.plans:
		var p := Vector2i(int(q["x"]), int(q["y"]))
		s.town.plan_share = float(Data.EXODUS["bp_share"]) if q.get("b", false) else 1.0
		var err: String = s.town.placement_error(q["t"], p)
		var built: bool = err == "" and not held and s.place(q["t"], p)
		s.town.plan_share = 1.0
		if built:
			continue
		if err in WAITS or err.begins_with(UNEXPLORED) or (err == "" and held):
			keep.append(q)
			held = held or err == WAITS[0]
		else:
			dropped.append(q["t"])
	if not dropped.is_empty():
		var kinds := []
		for type in dropped:
			var name: String = Data.BUILDINGS[type]["name"]
			if not name in kinds:
				kinds.append(name)
		s.events.append(Data.EXODUS["bp_dropped"] % [dropped.size(), ", ".join(kinds)])
	if keep.is_empty() and not s.carry.plans.is_empty():
		s.events.append(Data.EXODUS["bp_done"])
	s.carry.plans = keep
