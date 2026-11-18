extends RefCounted
## The founding (Step 9B): what a run after an ending begins with, because the Kin have done it before. Static, and works on the
## Sim passed in. The founders are ten, and know every job the last telling learned. Every tech the Kin learned costs nothing, except
## the four gates (Bronze Dawn, The Falling Star, Livewire, Skyward) which keep their full price, and is learned as soon as it can
## be (`tick`). An era the last telling finished has one goal, "Reach <its gate>", with the last telling's minutes beside the
## live clock, instead of its tutorial goals (Story.goal_list). The town as it stood when the Falling Star came is kept as the
## founding plan (`snapshot`), and the card of the new land offers to lay it on the new land (`lay`): every part that fits is
## paid as it is built (scripts/blueprints.gd), and the ones that need ground this land lacks are listed in the log when dropped.

const Blueprints = preload("res://scripts/blueprints.gd")
const Data = preload("res://scripts/data.gd")
const RoadRoute = preload("res://scripts/road_route.gd")
const Roads = preload("res://scripts/roads.gd")

const START_KITH := 10
const GATES := ["bronze_dawn", "falling_star", "livewire", "skyward"]  # known from before, but they keep their price
# the last goal of each era's list, the stone age first
const GATE_GOALS := ["bronze", "falling_star", "warning_read", "livewire", "skyward"]
const GATE_TECHS := ["bronze_dawn", "falling_star", "", "livewire", "skyward"]  # the gate of each era that is a tech
const ERA_NAMES := ["the Stone Age", "Bronze Dawn", "the Starfall", "Ironfall", "Livewire"]
const FIRST_TICK := 1.0  # seconds between looks for a tech that can be learned for free
const PLAN_NAME := "The founding"
const REACH := "Reach %s: the gate costs {cost}"
const REACH_WARNING := "Reach the Warning: answer the strangers and read it"
const CLOCK := "Last telling: %d min. This telling: %d min"
const REMEMBER_TITLE := "What the Kin remember"
const REMEMBER_KITH := "%d of them walk out knowing every job"
const REMEMBER_ERAS := "%s: %d min last time"  # the era, the minutes
const PLAN_BUTTON := "Lay the founding plan"
const BEGIN_NOTE := "Begin, and place each building yourself"
const PLAN_NOTE := "Every part of the old town that fits this land, each paid as it is built"
const REMEMBERED_MARK := "Remembered: free to learn"
const JOIN_RANGE := 30  # tiles from the Hearth the search for a way to join the plan's roads to it goes
const MOVED_LINE := "%d parts move to the nearest ground that fits: %s"
const LEFT_LINE := "Still to place yourself (no ground that fits within %d tiles): %s"
const GATE_MARK := "Remembered, but a gate asks its full price"


## True for a tech the Kin knew from before and learn for nothing: not a gate.
static func is_free(s, tech: String) -> bool:
	return s.carry.knows_tech(tech) and not tech in GATES


## True for a run that begins after an ending that finished at least one era: the Kin know something to start with.
static func active(s) -> bool:
	return s.carry.remembers_era(0)


## The mark on a tech card: "" for a tech the Kin did not learn before.
static func mark(s, tech: String) -> String:
	if not s.carry.knows_tech(tech):
		return ""
	return GATE_MARK if tech in GATES else REMEMBERED_MARK


## Set up a run that has just been made on its map (Launch.begin_new): ten founders who know the jobs of the last telling.
static func apply(s) -> void:
	if not active(s):
		return
	s.people.found(START_KITH)
	var who: String = s.people.kith[0]["name"]
	for item in s.carry.jobs:
		if not s.people.knows(item):
			s.people.learn(item, who)


## The goal that stands for era `i` (0 the stone age) when the Kin remember it: its gate, with "reach" marking it as the one-goal list.
static func reach_goal(i: int) -> Dictionary:
	var gate: Dictionary = _gate_goal(i)
	var goal := {"id": gate["id"], "reach": i, "text": REACH_WARNING}
	if gate.has("tech"):
		goal["tech"] = gate["tech"]
		goal["text"] = REACH % Data.TECHS[gate["tech"]]["name"]
	if gate.has("building"):
		goal["building"] = gate["building"]
	return goal


## The goal's words with the clock under them: the minutes the last telling took in this era, and the ones this telling has taken.
static func clock_line(s, i: int) -> String:
	var last := 0.0
	if i < s.carry.last_eras.size():
		last = float(s.carry.last_eras[i])
	var start := 0.0
	if i > 0:
		var opening: String = s.story.ERA_OPENINGS[i - 1]
		start = float(s.story.stamps.get(opening, s.seasons.time))
	return CLOCK % [roundi(last), roundi(maxf(s.seasons.time - start, 0.0) / 60.0)]


static func _gate_goal(i: int) -> Dictionary:
	var lists := [Data.GOALS, Data.GOALS_ERA2, Data.GOALS_ERA3, Data.GOALS_ERA4, Data.GOALS_ERA5]
	for g in lists[i]:
		if g["id"] == GATE_GOALS[i]:
			return g
	return lists[i][lists[i].size() - 1]


## Called every tick: learn, for nothing, each tech the Kin knew that can be learned now. Once a second.
static func tick(s, delta: float) -> void:
	if s.carry.exodus <= 0 or s.carry.techs.is_empty():
		return
	s.carry.free_clock += delta
	if s.carry.free_clock < FIRST_TICK:
		return
	s.carry.free_clock = 0.0
	for tech in Data.TECH_ORDER:
		if s.carry.knows_tech(tech) and not tech in GATES and s.tech_tree.research(tech):
			s._tech_done(tech)


## The town as it stands, kept as the founding plan: every part around the Hearth, with where its corner sat from the Hearth.
## Called when the Falling Star comes (Sim). A town with nothing but the Hearth keeps nothing.
static func snapshot(s) -> void:
	var camp: Vector2i = s.world.camp_pos
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-1, -1)
	for b in s.town.buildings:
		if Data.BUILDINGS[b["type"]]["kind"] == "camp":
			continue
		lo = Vector2i(mini(lo.x, b["pos"].x), mini(lo.y, b["pos"].y))
		hi = Vector2i(maxi(hi.x, b["pos"].x), maxi(hi.y, b["pos"].y))
	if hi.x < 0:
		return
	var plan := Blueprints.make(s, Rect2i(lo, hi - lo + Vector2i.ONE), PLAN_NAME)
	if plan.is_empty():
		return
	plan["run"] = s.carry.exodus  # the telling it was kept in
	plan["banked"] = true  # the Kin have built all of it before: it is laid at the share of the price a carried plan costs
	plan["ax"] = lo.x - camp.x
	plan["ay"] = lo.y - camp.y
	s.carry.founding = plan


## The parts in the order they are bought: the gatherers' huts first (they bring in what the rest costs), then roads and fields, then the
## other buildings of the earliest tech first. The plan pays for each part in turn, so an early era's needs come before a later era's town.
## Ties keep their order.
static func _in_era_order(items: Array) -> Array:
	var keyed := []
	for i in items.size():
		var def: Dictionary = Data.BUILDINGS[items[i]["t"]]
		var rank := 0  # the gatherers first: they bring in what everything after them costs
		if def["kind"] in ["road", "bridge", "field"]:
			rank = 1
		elif def["kind"] != "gatherer":
			rank = maxi(Data.TECH_ORDER.find(def.get("tech", "")), 0) + 2
		keyed.append([rank, i, items[i]])
	keyed.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return keyed.map(func(k): return k[2])


## True when there is a founding plan to offer.
static func has_plan(s) -> bool:
	return not s.carry.founding.is_empty() and not s.carry.founding.get("items", []).is_empty()


## Lay the founding plan on this land: its corner sits where it sat from the Hearth. Returns how many parts were queued.
static func lay(s) -> int:
	if not has_plan(s):
		return 0
	var plan: Dictionary = s.carry.founding
	var at: Vector2i = s.world.camp_pos + Vector2i(int(plan.get("ax", 0)), int(plan.get("ay", 0)))
	var ordered := plan.duplicate()
	ordered["items"] = _in_era_order(plan["items"])
	var joins := join_items(s, ordered["items"], at)
	var first := 0  # the joining roads go after the gatherers, with the other roads
	while first < ordered["items"].size() and Data.BUILDINGS[ordered["items"][first]["t"]]["kind"] == "gatherer":
		first += 1
	for i in joins.size():
		ordered["items"].insert(first + i, joins[i])
	return Blueprints.lay_plan(s, ordered, at)


## The road tiles that join every road of the plan (laid with its corner at `at`) to the Hearth, as plan parts: the plan's roads came from
## a town whose roads met the Hearth where it stood, and on this land they may not (fun playtest 6: workshops sat at "Needs road" for
## 4 minutes). A breadth-first look out from the Hearth's doorstep over the tiles a road takes (the plan's own roads cost nothing): the
## first time it reaches a planned road not yet joined, the tiles on the way back that are not planned roads are added.
static func join_items(s, items: Array, at: Vector2i) -> Array:
	var roads := {}
	var blocked := {}  # the tiles the plan puts a building or a field on
	for part in items:
		var p := at + Vector2i(int(part["x"]), int(part["y"]))
		if Data.BUILDINGS[part["t"]]["kind"] in ["road", "bridge"]:
			roads[p] = true
		else:
			blocked[p] = true
	var out: Array = []
	if roads.is_empty():
		return out
	var camp: Vector2i = s.world.camp_pos
	var parent := {}
	var todo: Array = []
	for n in Roads.SIDES:
		var q: Vector2i = camp + n
		if roads.has(q) or (not blocked.has(q) and RoadRoute.takes(s, "road", q)):
			parent[q] = camp
			todo.append(q)
	var joined := {}
	var head := 0
	while head < todo.size():
		var p: Vector2i = todo[head]
		head += 1
		if roads.has(p) and not joined.has(p):
			var t: Vector2i = p
			while t != camp:  # the way back to the Hearth: every planned road on it is joined, every other tile is laid
				if roads.has(t):
					_join(roads, joined, t)
				elif not joined.has(t):
					joined[t] = true
					out.append({"t": "road", "x": t.x - at.x, "y": t.y - at.y})
				t = parent[t]
		for n in Roads.SIDES:
			var q: Vector2i = p + n
			if parent.has(q) or maxi(absi(q.x - camp.x), absi(q.y - camp.y)) > JOIN_RANGE:
				continue
			if roads.has(q) or (not blocked.has(q) and RoadRoute.takes(s, "road", q)):
				parent[q] = p
				todo.append(q)
	return out


## Mark every planned road touching `from` (side by side, through other planned roads) as joined.
static func _join(roads: Dictionary, joined: Dictionary, from: Vector2i) -> void:
	var todo: Array = [from]
	joined[from] = true
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		for n in Roads.SIDES:
			var q: Vector2i = p + n
			if roads.has(q) and not joined.has(q):
				joined[q] = true
				todo.append(q)


## The lines of the new-land card: the founders, what is free, how long each remembered era took.
static func card_lines(s) -> Array:
	var lines := []
	if not active(s):
		return lines
	lines.append(REMEMBER_TITLE.to_upper())
	lines.append(REMEMBER_KITH % START_KITH)
	for i in 5:
		if s.carry.remembers_era(i):
			lines.append(REMEMBER_ERAS % [ERA_NAMES[i].capitalize(), roundi(float(s.carry.last_eras[i]))])
	lines.append_array(fit_lines(s))
	return lines


## What laying the founding plan on this land would do (scripts/blueprints.gd preview): the parts that move to the nearest ground that
## fits, and a short to-place list of the ones that fit nowhere within reach. [] when there is no plan, or everything fits as it was.
static func fit_lines(s) -> Array:
	var lines := []
	if not has_plan(s):
		return lines
	var plan: Dictionary = s.carry.founding
	var at: Vector2i = s.world.camp_pos + Vector2i(int(plan.get("ax", 0)), int(plan.get("ay", 0)))
	var seen: Dictionary = Blueprints.preview(s, plan["items"], at)
	if not seen["moved"].is_empty():
		lines.append(MOVED_LINE % [seen["moved"].size(), ", ".join(_once(seen["moved"]))])
	if not seen["left"].is_empty():
		lines.append(LEFT_LINE % [Blueprints.MOVE_RANGE, ", ".join(_once(seen["left"]))])
	return lines


static func _once(names: Array) -> Array:
	var out := []
	for name in names:
		if not name in out:
			out.append(name)
	return out
