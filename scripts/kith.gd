extends RefCounted
## The Kith block: the people the player leads. It holds the list of them (`kith`, each one a person on the
## map), who has learned to gather what (`learned_by`), the count of births that gives the next name, and the
## birth and starvation timers. It grows the population against housing and food, gives out jobs (staff the
## buildings in the order they were built, then haul once haulers are researched, else wait at the hearth),
## walks people along a Pathing path, wears and hands out tools, names each job and person ("Aro the
## Woodcutter"), and measures a trip to the nearest depot.
## It reads the World (the hearth), the Buildings block (the list, housing, where a hut works), the Pathing
## block (paths and walk cost) and Research (haulers, Storytelling). It pays and eats through the Economy.
## It never writes another block's variables except the worker link on a building's own record (`worker`,
## `claimed`, `incoming`), which the job rules own. What a worker does at their building each tick is still
## in scripts/workers.gd and scripts/haulers.gd. No faction word is spelled here: names and messages are in Data.
## Signals (the owner connects them, the block never calls another block to report):
##   announce(message): tell the player something (the owner shows it)
##   born(name) and left(name): a birth, and a Kith who leaves in search of food (not the starting people)
##   learned(item, name): someone learned to gather `item` by watching the player
##   trip_started: a hut worker set out on a trip the player clicked
## Sim owns one, reached as `sim.people` (the list is `people.kith`, the name count `births` and what they
## learned `learned_by`; a signal has the name `learned`).

signal announce(message: String)
signal born(name: String)
signal left(name: String)
signal learned(item: String, name: String)
signal trip_started

const Buildings = preload("res://scripts/buildings.gd")
const Codec = preload("res://scripts/save_codec.gd")
const Data = preload("res://scripts/data.gd")
const Economy = preload("res://scripts/economy.gd")
const Pathing = preload("res://scripts/pathing.gd")
const Research = preload("res://scripts/research.gd")
const World = preload("res://scripts/world.gd")

const _TASK_POINTS := ["tile", "depot"]  # the task entries that are tile positions (saved as [x, y])

## The people, each: {pos: Vector2 (tile coords), path: Array of Vector2i, job: "" | "work" | "haul",
##  building: int, phase: String, timer: float, carry: Dictionary, task: Dictionary, name: String,
##  tool: int, trip: bool, seen: Vector2i}
var kith: Array = []
var learned_by: Dictionary = {}  # item -> name of the person who learned to gather it by watching you
var births := 0  # people named so far, for the next name
var grow_timer := 0.0
var starve_timer := 0.0
var gift: Callable = func(_set_id: String) -> bool: return false  # (set id) -> true once that glyph set is read (Starfall)
var _world: World
var _pathing: Pathing
var _economy: Economy
var _research: Research
var _town: Buildings


func _init(world: World, pathing: Pathing, economy: Economy, research: Research, town: Buildings) -> void:
	_world = world
	_pathing = pathing
	_economy = economy
	_research = research
	_town = town


# --- Population --------------------------------------------------------------


## Start over with `count` people at the hearth. The births counter keeps counting, so names never repeat.
func found(count: int) -> void:
	kith.clear()
	for i in count:
		add_kith()


## A new person at the hearth, with the next name.
func add_kith() -> void:
	var k := {
		"pos": Vector2(_world.camp_pos),
		"path": [],
		"job": "",
		"building": -1,
		"phase": "",
		"timer": 0.0,
		"carry": {},
		"task": {},
		"seen": Vector2i(-99, -99),  # the tile they last lifted the fog around
		"tool": 0,  # jobs left on the tool they hold, 0 for none
		"tool_id": "",  # which tool it is (Data.TOOL_ITEMS), "" for none
		"cart": false,  # a hauler pulling a hand cart (see Buildings.carts_allowed): carries 3x but walks roads only
		"trip": false,  # a hut worker out on a clicked trip, carrying the bundle to the stockpile
		"name": _next_name(),
	}
	kith.append(k)


## The next name from Data.PEOPLE_NAMES, with " II", " III"... once each name is taken.
func _next_name() -> String:
	var names: Array = Data.PEOPLE_NAMES
	var n: int = births
	births += 1
	var round_no := int(float(n) / names.size()) + 1
	return names[n % names.size()] + ("" if round_no == 1 else " " + Data.RANK_NAMES[mini(round_no, 3)])


## Seconds between births. Storytelling shortens it.
func grow_time() -> float:
	var healed: float = Data.HEALER_GROW if gift.call("body") else 1.0  # the Lumen Healer's leaves
	return Data.GROW_TIME * (Data.STORYTELLING_GROW if _research.unlocked("storytelling") else 1.0) * healed


## True when there is food enough for one more mouth: the stockpile covers the birth (and a small reserve
## for everyone) and the food coming in over the last Data.RATE_WINDOW seconds covers what they eat.
func food_ready_for_birth() -> bool:
	return _economy.food_total() >= kith.size() * Data.BIRTH_RESERVE + Data.BIRTH_FOOD and _economy.food_is_steady()


## One tick of the population. Fed, with room and steady food, a birth comes every grow_time() seconds
## and eats Data.BIRTH_FOOD; unfed, the timer for the next departure runs, and the last one who isn't
## working leaves. The last person never leaves.
func grow(delta: float, fed: bool) -> void:
	if not fed:
		starve_timer += delta
		grow_timer = 0.0
		if starve_timer >= Data.STARVE_TIME and kith.size() > 1:
			starve_timer = 0.0
			_remove_kith()
		return
	starve_timer = 0.0
	if kith.size() >= _town.housing() or not food_ready_for_birth():
		grow_timer = 0.0
		return
	grow_timer += delta
	if grow_timer >= grow_time():
		grow_timer = 0.0
		_economy.eat(Data.BIRTH_FOOD)
		add_kith()
		born.emit(kith[kith.size() - 1]["name"])
		announce.emit(Data.BORN_EVENT % Data.PEOPLE["one"])


## Someone leaves in search of food: the last one not at a building, or the last one of all.
func _remove_kith() -> void:
	var gone := kith.size() - 1
	for j in kith.size():
		if kith[j]["job"] != "work":
			gone = j
	var k: Dictionary = kith[gone]
	drop_task(k)
	if k["job"] == "work":
		var home: Dictionary = _town.buildings[k["building"]]
		for slot in Buildings.CREW_SLOTS:
			if home[slot] == gone:
				home[slot] = -1
	kith.remove_at(gone)
	for b in _town.buildings:
		for slot in Buildings.CREW_SLOTS:
			if b[slot] > gone:
				b[slot] -= 1
	left.emit(k["name"])
	announce.emit(Data.LEFT_EVENT % Data.PEOPLE["one"])


## True once someone has learned to gather `item` by watching you (Data.LEARN_CLICKS clicks).
func knows(item: String) -> bool:
	return learned_by.has(item)


## `who` has learned to gather `item` by watching the player.
func learn(item: String, who: String) -> void:
	learned_by[item] = who
	learned.emit(item, who)


## A hut worker sets out on a trip the player clicked (a road-linked hut runs on its own instead).
func start_trip(k: Dictionary) -> void:
	k["trip"] = true
	trip_started.emit()


## True if a hut at p would find something the people know how to gather.
func knows_any(p: Vector2i) -> bool:
	for t in _town.gather_tiles(p):
		if knows(Data.TILES[_world.tile_at(t)]["yields"]):
			return true
	return false


## True if hut `b` can work its focus: the people know how to gather it and some of it is in reach.
func knows_focus(b: Dictionary) -> bool:
	return b["focus"] != "" and knows(b["focus"]) and not _town.focus_tiles(b).is_empty()


# --- Jobs --------------------------------------------------------------------


## Staff buildings in the order they were built (a building that needs two gets both, one after the other).
## Everyone else hauls (once researched) or waits at camp.
func assign_jobs() -> void:
	var buildings: Array = _town.buildings
	var out_of_hands := false
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		if out_of_hands or not Buildings.needs_worker(b) or b["paused"]:
			continue
		for slot in Buildings.crew_slots(b):
			if b[slot] < 0 and not _staff(i, b, slot):
				out_of_hands = true
				break
	var carts := _town.carts_allowed()  # the first haulers in the list push the carts
	for k in kith:
		if k["job"] == "" and _research.unlocked("haulers"):
			drop_task(k)  # a forager hands in what they carry
			k["job"] = "haul"
			k["phase"] = ""
		k["cart"] = k["job"] == "haul" and carts > 0
		if k["cart"]:
			carts -= 1


## Send the first idle person (else the first hauler) to building `i`, to fill its place `slot`. False when
## nobody is free.
func _staff(i: int, b: Dictionary, slot: String) -> bool:
	var pick := -1
	for j in kith.size():
		if kith[j]["job"] == "":
			pick = j
			break
	if pick < 0:
		for j in kith.size():
			if kith[j]["job"] == "haul":
				pick = j
				break
	if pick < 0:
		return false
	var k: Dictionary = kith[pick]
	drop_task(k)
	k["job"] = "work"
	k["building"] = i
	k["phase"] = "to_site"
	b[slot] = pick
	equip(k)
	walk_to(k, b["pos"])
	return true


## Put back whatever a hauler was carrying or had promised, so nothing is lost when plans change.
func drop_task(k: Dictionary) -> void:
	for id in k["carry"]:
		_economy.add(id, k["carry"][id])
	k["carry"] = {}
	var t: Dictionary = k["task"]
	if t.has("kind"):
		var b: Dictionary = _town.buildings[t["building"]]
		if t["kind"] == "pickup":
			b["claimed"] = false
		elif t["kind"] == "deliver":
			b["incoming"][t["item"]] = b["incoming"].get(t["item"], 0) - t["amount"]
	k["task"] = {}


## Send a building's workers off the job: they drop what they carry at the stockpile and go idle.
func release_worker(b: Dictionary) -> void:
	for slot in Buildings.CREW_SLOTS:
		if b[slot] < 0:
			continue
		var k: Dictionary = kith[b[slot]]
		for id in k["carry"]:
			_economy.add(id, k["carry"][id])
		k["carry"] = {}
		k["task"] = {}
		k["job"] = ""
		k["building"] = -1
		k["phase"] = ""
		k["timer"] = 0.0
		k["path"] = []
		k["trip"] = false
		b[slot] = -1


## Building `i` is about to be removed from the list: whoever was heading there for a pickup or a delivery
## lets it go and stops walking. Call before Buildings.remove_at(i).
func drop_tasks_at(i: int) -> void:
	for k in kith:
		if not k["task"].is_empty() and k["task"].get("building", -1) == i:
			drop_task(k)
			k["path"] = []


## Building `i` was removed from the list: the buildings after it moved up one place, so every reference
## to them (a worker's building, a hauler's task) does too. Call after Buildings.remove_at(i).
func shift_buildings_after(i: int) -> void:
	for k in kith:
		if k["job"] == "work" and k["building"] > i:
			k["building"] -= 1
		if k["task"].get("building", -1) > i:
			k["task"]["building"] -= 1


## Everyone the building needs is standing at it, ready to work it.
func worker_home(b: Dictionary) -> bool:
	for slot in Buildings.crew_slots(b):
		if b[slot] < 0 or kith[b[slot]]["phase"] == "to_site":
			return false
	return true


# --- Tools -------------------------------------------------------------------


## A worker without a tool takes the best one from the stockpile (Bronze Tools before Flint Tools).
func equip(k: Dictionary) -> void:
	if k["tool"] > 0:
		return
	for id in Data.TOOL_ITEMS:
		if _economy.inv.get(id, 0) > 0:
			_economy.pay({id: 1})
			_economy.note(id, -1, Data.FLOW_TOOL_SOURCE)
			k["tool"] = tool_jobs(id)
			k["tool_id"] = id
			return


## How many jobs a new tool of `id` lasts.
static func tool_jobs(id: String) -> int:
	return Data.BRONZE_TOOL_JOBS if id == "bronze_tools" else Data.TOOL_JOBS


## The tool a worker holds: its item id, "" for none. A save from before Bronze Tools holds a Flint Tool.
static func tool_of(k: Dictionary) -> String:
	if k["tool"] <= 0:
		return ""
	return String(k.get("tool_id", "")) if k.get("tool_id", "") != "" else "flint_tools"


## One job done: the worker's tool wears a little, and they pick up a new one when it breaks.
func wear(b: Dictionary) -> void:
	if b["worker"] < 0:
		return
	var k: Dictionary = kith[b["worker"]]
	if k["tool"] > 0:
		var id := tool_of(k)
		k["wear_acc"] = float(k.get("wear_acc", 0.0)) + (Data.HEALER_WEAR if gift.call("body") else 1.0)
		if k["wear_acc"] >= 1.0:
			k["wear_acc"] -= 1.0
			k["tool"] -= 1
		if k["tool"] == 0:
			k["tool_id"] = ""
			announce.emit(Data.TOOL_WORE_OUT % Data.ITEMS[id]["one"])
	equip(k)


# --- Job titles --------------------------------------------------------------


## The job title of whoever works building b: the building's `job`, or for a hut the title of what it
## gathers (its focus; a hut with none is named for what is most in its reach among what the people know).
func building_job(b: Dictionary) -> String:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if def.has("job"):
		return def["job"]
	if def["kind"] != "gatherer":
		return ""
	if b["focus"] != "":
		return Data.HUT_JOBS[b["focus"]]["title"]
	var counts := {}
	for item in b["gather_items"]:
		counts[item] = counts.get(item, 0) + (100 if knows(item) else 1)
	var best := "fiber"
	for item in counts:
		if counts[item] > counts.get(best, 0):
			best = item
	return Data.HUT_JOBS[best]["title"]


## A person's job title: from their building, Hauler, or Idle.
func job_of(k: Dictionary) -> String:
	match k["job"]:
		"work":
			return building_job(_town.buildings[k["building"]])
		"haul":
			return Data.JOB_HAULER
		"scout":
			return Data.JOB_SCOUT
		"expedition":
			return Data.JOB_PARTY
	return Data.JOB_IDLE


## "Aro the Woodcutter".
func title_of(k: Dictionary) -> String:
	return "%s the %s" % [k["name"], job_of(k)]


## "3 Woodcutters, 1 Potter, 2 Haulers": how many people have each job, most first.
func job_counts() -> String:
	var counts := {}
	for k in kith:
		var job := job_of(k)
		counts[job] = counts.get(job, 0) + 1
	var jobs: Array = counts.keys()
	jobs.sort_custom(func(a, b): return counts[a] > counts[b] or (counts[a] == counts[b] and a < b))
	var parts: Array = []
	for job in jobs:
		var many: String = job if counts[job] == 1 or job == Data.JOB_IDLE else job + "s"
		parts.append("%d %s" % [counts[job], many])
	return ", ".join(parts)


# --- Walking -----------------------------------------------------------------


## The tile a person stands on (their position rounded).
static func tile_of(k: Dictionary) -> Vector2i:
	var pos: Vector2 = k["pos"]
	return Vector2i(roundi(pos.x), roundi(pos.y))


## Set a person walking to `to`. Returns false if there's no way there.
func walk_to(k: Dictionary, to: Vector2i) -> bool:
	var from := tile_of(k)
	if from == to:
		k["path"] = []
		return true
	var path := _pathing.path(from, to)  # the start counts as open: a person on a just-blocked tile may step off
	if path.is_empty():
		return false
	path.remove_at(0)
	k["path"] = Array(path)
	return true


## Move along the path for `delta` seconds. Returns true once there.
func step(k: Dictionary, delta: float) -> bool:
	var budget := delta
	while budget > 0.0 and not k["path"].is_empty():
		var next: Vector2i = k["path"][0]
		var speed: float = Data.KITH_SPEED / _pathing.walk_cost(next)
		var pos: Vector2 = k["pos"]
		var dist := pos.distance_to(Vector2(next))
		if dist <= speed * budget:
			k["pos"] = Vector2(next)
			budget -= dist / speed
			k["path"].remove_at(0)
		else:
			k["pos"] = pos.move_toward(Vector2(next), speed * budget)
			budget = 0.0
	return k["path"].is_empty()


# --- Trips -------------------------------------------------------------------


## Seconds to walk from `from` to `to` and back (roads shorten it), or -1.0 when water cuts the way off.
func round_trip(from: Vector2i, to: Vector2i) -> float:
	if from == to:
		return 0.0
	var path := _pathing.path(from, to)
	if path.is_empty():
		return -1.0
	var secs := 0.0
	for i in range(1, path.size()):
		secs += Vector2(path[i - 1]).distance_to(Vector2(path[i])) * _pathing.walk_cost(path[i]) / Data.KITH_SPEED
	return secs * 2.0


## The Camp or Storehouse closest to p.
func nearest_depot(p: Vector2i) -> Vector2i:
	var best := _world.camp_pos
	var best_d := Vector2(p).distance_to(Vector2(_world.camp_pos))
	for b in _town.buildings:
		if Data.BUILDINGS[b["type"]]["kind"] == "depot":
			var d := Vector2(p).distance_to(Vector2(b["pos"]))
			if d < best_d:
				best = b["pos"]
				best_d = d
	return best


## The walk from p to the nearest stockpile: {"ok": false} when water cuts it off, otherwise
## {"ok": true, "tiles": one-way steps, "seconds": there and back, "depot": Vector2i}.
func trip_info(p: Vector2i) -> Dictionary:
	var depot := nearest_depot(p)
	if depot == p:
		return {"ok": true, "tiles": 0, "seconds": 0.0, "depot": depot}
	var path := _pathing.path(p, depot)
	if path.is_empty():
		return {"ok": false, "tiles": 0, "seconds": 0.0, "depot": depot}
	var secs := 0.0
	for i in range(1, path.size()):
		secs += Vector2(path[i - 1]).distance_to(Vector2(path[i])) * _pathing.walk_cost(path[i]) / Data.KITH_SPEED
	return {"ok": true, "tiles": path.size() - 1, "seconds": secs * 2.0, "depot": depot}


# --- Save --------------------------------------------------------------------


## The people in order, who has learned what, the birth count and the two timers, as JSON-safe values.
func to_dict() -> Dictionary:
	var list: Array = []
	for k in kith:
		list.append(_person_to_dict(k))
	return {
		"kith": list,
		"learned_by": learned_by.duplicate(),
		"births": births,
		"grow_timer": grow_timer,
		"starve_timer": starve_timer,
	}


## Restore what to_dict wrote, in place. Nothing is emitted: `born` and `learned` already fired in the saved run.
func from_dict(d: Dictionary) -> void:
	kith.clear()
	for saved in d.get("kith", []):
		kith.append(_person_from_dict(saved))
	learned_by.clear()
	for item in d.get("learned_by", {}):
		learned_by[String(item)] = String(d["learned_by"][item])
	births = int(d.get("births", 0))
	grow_timer = float(d.get("grow_timer", 0.0))
	starve_timer = float(d.get("starve_timer", 0.0))


static func _person_to_dict(k: Dictionary) -> Dictionary:
	var out := k.duplicate(true)
	out["pos"] = Codec.vec2(k["pos"])
	out["path"] = Codec.vec_list(k["path"])
	out["seen"] = Codec.vec(k["seen"])
	out["task"] = Codec.with_points(k["task"], _TASK_POINTS)
	out["carry"] = Codec.int_dict(k["carry"])
	return out


static func _person_from_dict(d: Dictionary) -> Dictionary:
	var k := d.duplicate(true)
	k["pos"] = Codec.to_vec2(d["pos"])
	k["path"] = Codec.to_vec_list(d["path"])
	k["seen"] = Codec.to_vec(d["seen"])
	k["task"] = Codec.from_points(d["task"], _TASK_POINTS)
	k["carry"] = Codec.int_dict(d["carry"])
	for key in ["building", "tool"]:
		k[key] = int(d[key])
	k["tool_id"] = String(d.get("tool_id", "flint_tools" if int(d["tool"]) > 0 else ""))  # older saves: flint
	k["cart"] = bool(d.get("cart", false))
	k["timer"] = float(d["timer"])
	k["task"] = _int_task(k["task"])
	return k


## A task's counts are ints again after a JSON round trip (the positions are already Vector2i).
static func _int_task(t: Dictionary) -> Dictionary:
	for key in ["building", "amount"]:
		if t.has(key):
			t[key] = int(t[key])
	return t
