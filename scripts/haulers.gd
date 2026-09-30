extends RefCounted
## Haulers: idle Kith who empty buildings into a stockpile and bring workshops their inputs. They
## serve only buildings a road links to a depot (scripts/roads.gd), and walk those roads only: a hauler
## waits at a depot (the Hearth or a Storehouse), takes a job on a road network that depot touches, and
## comes back along it. Static, and works on the GameState passed in.

const Data = preload("res://scripts/data.gd")
const Kith = preload("res://scripts/kith.gd")
const Roads = preload("res://scripts/roads.gd")


## Items a hauler carries per trip: Carrying Poles double it.
static func carry_cap(s) -> int:
	return Data.CARRY * (2 if s.researched.has("carrying_poles") else 1)


static func tick(s, k: Dictionary, delta: float) -> void:
	if k["task"].is_empty():
		if k["path"].is_empty():
			var here: Vector2i = Kith.tile_of(k)
			var home := _home_depot(s, here)
			if here == home and _find_task(s, k):
				return
			if here != home:
				s.people.walk_to(k, home)  # off duty: back to a depot on the roads, across country
		s.people.step(k, delta)
		return
	if not s.people.step(k, delta):
		return
	var t: Dictionary = k["task"]
	var b: Dictionary = s.buildings[t["building"]]
	match k["phase"]:
		"to_pickup":
			var left: int = carry_cap(s)
			for id in b["out"].keys():
				var n: int = mini(b["out"][id], left)
				if n > 0:
					k["carry"][id] = k["carry"].get(id, 0) + n
					b["out"][id] -= n
					left -= n
				if b["out"][id] == 0:
					b["out"].erase(id)
			b["claimed"] = false
			k["task"] = {"kind": "dropoff", "building": t["building"]}
			if not Roads.walk(s, k, t["depot"]):
				s.people.drop_task(k)  # the road was torn up: the goods go straight to the stockpile
				return
			k["phase"] = "to_depot"
		"to_depot":
			for id in k["carry"]:
				s.add(id, k["carry"][id])
			k["carry"] = {}
			k["task"] = {}
		"to_stock":
			var n: int = mini(t["amount"], s.inv.get(t["item"], 0))
			b["incoming"][t["item"]] -= t["amount"] - n
			t["amount"] = n
			if n == 0:
				k["task"] = {}
				return
			s.inv[t["item"]] -= n
			k["carry"] = {t["item"]: n}
			if not Roads.walk(s, k, b["pos"]):
				b["unreachable"] = 2.0
				s.people.drop_task(k)
				return
			k["phase"] = "to_drop"
		"to_drop":
			b["inbuf"][t["item"]] = b["inbuf"].get(t["item"], 0) + t["amount"]
			b["incoming"][t["item"]] -= t["amount"]
			k["carry"] = {}
			k["task"] = {}
			Roads.walk(s, k, t["depot"])  # back along the road to wait at the depot


## Where an idle hauler waits: the nearest depot a road network touches, or the Hearth when none does.
static func _home_depot(s, here: Vector2i) -> Vector2i:
	var best: Vector2i = s.camp_pos
	var best_d := INF
	for depot in Roads.depots(s):
		if Roads.depot_nets(s, depot).is_empty():
			continue
		var d := Vector2(here).distance_to(Vector2(depot))
		if d < best_d:
			best = depot
			best_d = d
	return best


## From the depot the hauler waits at, pick the closest useful trip on a road network that depot
## touches: empty a building's output, or bring a processor its inputs. A building that has stopped
## (a workshop with nothing to work, or one full up) counts as a third as far, so busy huts near the
## stockpile don't starve the far ones.
static func _find_task(s, k: Dictionary) -> bool:
	var here: Vector2i = Kith.tile_of(k)
	var nets := Roads.depot_nets(s, here)
	if nets.is_empty():
		return false
	var best := {}
	var best_d := INF
	for i in s.buildings.size():
		var cand: Dictionary = s.buildings[i]
		if not s.needs_worker(cand) or cand["unreachable"] > 0.0 or not Roads.net_of(s, cand) in nets:
			continue
		var d := Vector2(here).distance_to(Vector2(cand["pos"]))
		var starved: bool = not Data.BUILDINGS[cand["type"]].get("in", {}).is_empty() and s.buffered(cand["inbuf"]) == 0
		if starved or s.buffered(cand["out"]) >= Data.BUFFER_CAP:
			d /= 3.0
		if d >= best_d:
			continue
		if s.buffered(cand["out"]) > 0 and not cand["claimed"]:
			best = {"kind": "pickup", "building": i}
			best_d = d
			continue
		var def: Dictionary = Data.BUILDINGS[cand["type"]]
		var inputs: Dictionary = {} if cand["paused"] else def.get("in", {})
		for id in inputs:
			var want: int = def["in"][id] * 2 - cand["inbuf"].get(id, 0) - cand["incoming"].get(id, 0)
			var n := mini(mini(want, s.inv.get(id, 0)), carry_cap(s))
			if n > 0:
				best = {"kind": "deliver", "building": i, "item": id, "amount": n}
				best_d = d
				break
	if best.is_empty():
		return false
	var b: Dictionary = s.buildings[best["building"]]
	best["depot"] = here
	if best["kind"] == "pickup" and not Roads.walk(s, k, b["pos"]):
		b["unreachable"] = 2.0
		return false
	k["path"] = [] if best["kind"] == "deliver" else k["path"]  # a delivery starts from this depot's stock
	k["task"] = best
	if best["kind"] == "pickup":
		b["claimed"] = true
		k["phase"] = "to_pickup"
	else:
		b["incoming"][best["item"]] = b["incoming"].get(best["item"], 0) + best["amount"]
		k["phase"] = "to_stock"
	return true
