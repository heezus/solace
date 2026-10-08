extends RefCounted
## Haulers: idle Kith who empty buildings into a stockpile and bring workshops their inputs. They
## serve only buildings a road links to a depot (scripts/roads.gd), and walk those roads only: a hauler
## waits at a depot (the Hearth or a Storehouse), takes a job on a road network that depot touches, and
## comes back along it. Static, and works on the Sim passed in.

const Data = preload("res://scripts/data.gd")
const Kith = preload("res://scripts/kith.gd")
const Roads = preload("res://scripts/roads.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Work = preload("res://scripts/work.gd")
const Homes = preload("res://scripts/homes.gd")
const Teardown = preload("res://scripts/teardown.gd")


## Items a hauler carries per trip: Carrying Poles double it, and a cart (`k`, if given) carries Data.CART_LOAD times.
static func carry_cap(s, k := {}) -> int:
	var n: int = Data.CARRY * (2 if s.tech_tree.researched.has("carrying_poles") else 1)
	return n * (Data.CART_LOAD if k.get("cart", false) else 1)


static func tick(s, k: Dictionary, delta: float) -> void:
	if k["task"].is_empty():
		if k["path"].is_empty():
			var here: Vector2i = Kith.tile_of(k)
			var home := _home_depot(s, k, here)
			if here == home and _find_task(s, k):
				return
			if here != home:
				if k["cart"]:
					Roads.walk(s, k, home)  # a cart goes back by road, or waits where it stands
				else:
					s.people.walk_to(k, home)  # off duty: back to a depot on the roads, across country
		s.people.step(k, delta)
		return
	if not s.people.step(k, delta):
		return
	var t: Dictionary = k["task"]
	var b: Dictionary = s.town.buildings[t["building"]]
	match k["phase"]:
		"to_pickup":
			var left: int = carry_cap(s, k)
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
				s.economy.add(id, k["carry"][id])
			k["carry"] = {}
			k["task"] = {}
		"to_stock":
			var n: int = mini(t["amount"], s.economy.inv.get(t["item"], 0))
			b["incoming"][t["item"]] -= t["amount"] - n
			t["amount"] = n
			if n == 0:
				k["task"] = {}
				return
			s.economy.inv[t["item"]] -= n
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
		"to_part":
			if not Roads.walk(s, k, b["pos"]):
				b["unreachable"] = 2.0
				s.people.drop_task(k)  # the part never left the pack
				return
			k["phase"] = "part_drop"
		"part_drop":
			s.teardown.deliver(t["part"])
			k["task"] = {}
			Roads.walk(s, k, t["depot"])


## Where an idle hauler waits. Haulers are born at the Hearth, so left to stand where they are none would ever
## serve a Storehouse's workshops: they spread over the depots that have road-linked buildings to serve, in turn by
## the order they were born in (read off their name, so it never changes on them and never depends on chance: a hash
## of the name once left a post with one hauler of forty-five, and the workshops behind it stood idle). With none,
## the nearest depot a road touches, or the Hearth when none does.
static func _home_depot(s, k: Dictionary, here: Vector2i) -> Vector2i:
	var posts := Roads.posts(s)
	if not posts.is_empty():
		return posts[birth_order(k["name"]) % posts.size()]
	var best: Vector2i = s.world.camp_pos
	var best_d := INF
	for depot in Roads.depots(s):
		if Roads.depot_nets(s, depot).is_empty():
			continue
		var d := Vector2(here).distance_to(Vector2(depot))
		if d < best_d:
			best = depot
			best_d = d
	return best


## The order a Kith was born in, from their name: Data.PEOPLE_NAMES in turn, then round again as "Name II", "Name III".
static func birth_order(kith_name: String) -> int:
	var parts := kith_name.split(" ")
	var at: int = Data.PEOPLE_NAMES.find(parts[0])
	if at < 0:
		return absi(hash(kith_name))
	var round_no: int = maxi(Data.RANK_NAMES.find(parts[1]), 1) if parts.size() > 1 else 1
	return at + (round_no - 1) * Data.PEOPLE_NAMES.size()


## What building `cand` wants stocked, item -> the amount its stock should reach (haulers bring the difference): a workshop
## two rounds of its recipe, unless it is paused or has made enough; a home its goods and upgrade materials.
static func _stock_wanted(s, cand: Dictionary) -> Dictionary:
	if Homes.is_home(cand):
		return Homes.wanted(cand)
	if cand["paused"] or Work.enough(s, cand):
		return {}
	var recipe := Buildings.recipe_in(cand)
	var out := {}
	for id in recipe:
		out[id] = recipe[id] * 2
	if s.teardown.knows("hull_gear") and Data.BUILDINGS[cand["type"]]["kind"] == "processor" and not recipe.is_empty():
		out[Data.GEARS_ITEM] = 1  # one Iron Gear fitted to a workshop speeds it up for good
	return out


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
	for i in s.town.buildings.size():
		var cand: Dictionary = s.town.buildings[i]
		if not Buildings.served(cand) or cand["unreachable"] > 0.0 or not Roads.net_of(s, cand) in nets:
			continue
		var d := Vector2(here).distance_to(Vector2(cand["pos"]))
		var fitted: int = cand["inbuf"].get(Data.GEARS_ITEM, 0)  # a gear fitted to the workshop is not an input it works on
		var starved: bool = not Buildings.recipe_in(cand).is_empty() and Buildings.buffered(cand["inbuf"]) - fitted == 0
		if starved or Buildings.buffered(cand["out"]) >= Data.BUFFER_CAP:
			d /= 3.0
		if d >= best_d or (k["cart"] and not Roads.cart_can_reach(s, here, cand["pos"])):
			continue
		if Buildings.buffered(cand["out"]) > 0 and not cand["claimed"]:
			best = {"kind": "pickup", "building": i}
			best_d = d
			continue
		var part: String = (
			s.teardown.next_to_carry(Teardown.flying(s.people.kith)) if cand["type"] == "teardown_bench" else ""
		)
		if part != "":
			best = {"kind": "part", "building": i, "part": part}
			best_d = d
			continue
		var inputs := _stock_wanted(s, cand)
		for id in inputs:
			var want: int = inputs[id] - cand["inbuf"].get(id, 0) - cand["incoming"].get(id, 0)
			var n := mini(mini(want, s.economy.inv.get(id, 0)), carry_cap(s, k))
			if n > 0:
				best = {"kind": "deliver", "building": i, "item": id, "amount": n}
				best_d = d
				break
	if best.is_empty():
		return false
	var b: Dictionary = s.town.buildings[best["building"]]
	best["depot"] = here
	if best["kind"] == "pickup" and not Roads.walk(s, k, b["pos"]):
		b["unreachable"] = 2.0
		return false
	k["path"] = [] if best["kind"] != "pickup" else k["path"]  # a delivery starts from this depot's stock
	k["task"] = best
	if best["kind"] == "pickup":
		b["claimed"] = true
		k["phase"] = "to_pickup"
	elif best["kind"] == "part":
		k["phase"] = "to_part"
	else:
		b["incoming"][best["item"]] = b["incoming"].get(best["item"], 0) + best["amount"]
		k["phase"] = "to_stock"
	return true
