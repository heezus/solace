extends RefCounted
## Working by hand (design-system/14-hands-to-haulers.md): what a hold-to-harvest gives and how long it
## takes, teach by doing (a Kith who watches you harvest a resource Data.LEARN_CLICKS times, 6 for the first, learns to
## gather it), and crafting. Static, and works on the Sim passed in.

const Data = preload("res://scripts/data.gd")
const Bonuses = preload("res://scripts/bonuses.gd")
const Ranks = preload("res://scripts/ranks.gd")


## One harvest by hand: base x tool x rank. The base is 1 plus one per rank bought beyond I on the
## item's gathering tech; the best yield tool that applies multiplies it (Stone Axe x3 on Wood); then the
## item's Yield bonuses that aren't tied to a kind of building (Foraging on Berries).
static func harvest_yield(s, item: String) -> int:
	var parts: Array = []
	for bonus in Bonuses.active(s, {"type": "camp", "pos": s.world.camp_pos, "worker": -1}, item):
		if bonus["group"] == "yield" and not Data.BONUSES[bonus["id"]].has("kinds"):
			parts.append(bonus)
	var mult := 1
	for t in _tools(s, item):
		mult = maxi(mult, t.get("mult", 1))
	return roundi((1 + Ranks.item_bonus(s, item)) * mult * Bonuses.total(parts, "yield"))


## Seconds of holding for one harvest of `item`: Data.HOLD_TIME, or the shortest hold a tool gives (ore takes
## Data.HAND_HOLD, and a tool cuts it by the same share).
static func hold_time(s, item: String) -> float:
	var t_min := Data.HOLD_TIME
	for t in _tools(s, item):
		t_min = minf(t_min, t.get("hold", Data.HOLD_TIME))
	if Data.HAND_HOLD.has(item):  # slow work (ore): the tools shorten it by the same share
		return Data.HAND_HOLD[item] * t_min / Data.HOLD_TIME
	return t_min


## Hold on `p` for `delta` more seconds: the ring fills and, when full, the tile is harvested (its text, else "").
## A shaky hand costs nothing. Sliding to a neighbouring tile of the same kind keeps the ring's progress; any other
## move (a tile of another kind, bare ground, off the map) puts the progress aside for Data.HOLD_KEEP seconds, and
## it comes back if the pointer returns to that tile in time (a press after an early release does the same).
static func hold(s, p: Vector2i, delta: float) -> String:
	if p != s.harvest_tile:
		_move_ring(s, p)
	var item := item_at(s, p)
	if item == "":
		s.harvest_frac = 0.0
		return ""
	var need := hold_time(s, item)
	s.harvest_ring["held"] += delta
	if s.harvest_ring["held"] < need:
		s.harvest_frac = s.harvest_ring["held"] / need
		return ""
	s.harvest_ring["held"] -= need
	s.harvest_frac = s.harvest_ring["held"] / need
	return s.gather_by_hand(p)


## Let go of the ring: it empties, or with `keep` its progress waits Data.HOLD_KEEP seconds (see hold).
static func release(s, keep: bool) -> void:
	if not keep:
		s.harvest_ring["aside"] = {}
	elif s.harvest_ring["held"] > 0.0:
		_set_aside(s)
	s.harvest_tile = Vector2i(-1, -1)
	s.harvest_ring["held"] = 0.0
	s.harvest_frac = 0.0


## Waiting progress runs down in game time, and is gone when its time is out.
static func age_stash(s, delta: float) -> void:
	if s.harvest_ring["aside"].is_empty():
		return
	s.harvest_ring["aside"]["left"] -= delta
	if s.harvest_ring["aside"]["left"] <= 0.0:
		s.harvest_ring["aside"] = {}


## The pointer is on a new tile `p`: the ring goes with it (same kind, next door), or its progress is put aside and
## p's own waiting progress, if there is any, comes back.
static func _move_ring(s, p: Vector2i) -> void:
	var back: Dictionary = s.harvest_ring["aside"]
	if s.harvest_ring["held"] > 0.0:
		var from: Vector2i = s.harvest_tile
		var item := item_at(s, from)
		if item != "" and item == item_at(s, p) and maxi(absi(p.x - from.x), absi(p.y - from.y)) <= 1:
			s.harvest_tile = p
			return
		_set_aside(s)
	s.harvest_tile = p
	s.harvest_ring["held"] = 0.0
	if back.get("tile", Vector2i(-1, -1)) == p:
		s.harvest_ring["held"] = back["held"]
		if s.harvest_ring["aside"] == back:
			s.harvest_ring["aside"] = {}


static func _set_aside(s) -> void:
	s.harvest_ring["aside"] = {"tile": s.harvest_tile, "held": s.harvest_ring["held"], "left": Data.HOLD_KEEP}


## The hand tools that apply to `item` now.
static func _tools(s, item: String) -> Array:
	var out: Array = []
	for id in Data.HAND_TOOLS:
		var t: Dictionary = Data.HAND_TOOLS[id]
		if t.has("item") and t["item"] != item:
			continue
		if t.get("crafted", false) and not s.hand_tools:
			continue
		if t.has("tech") and not s.tech_tree.researched.has(t["tech"]):
			continue
		out.append(t)
	return out


## What holding on `p` would harvest: its item, or "" (fog, a building or road on it, nothing to gather).
static func item_at(s, p: Vector2i) -> String:
	if not s.fog.is_revealed(p) or s.town.building_at.has(p) or s.world.roads.has(p) or s.world.tile_at(p) == "":
		return ""
	var tile: Dictionary = Data.TILES[s.world.tile_at(p)]
	if tile.has("tech") and not s.tech_tree.researched.has(tile["tech"]):
		return ""  # ore can't be dug before Prospecting
	return tile["yields"]


## How many Kith hold a Flint Tool.
static func tools_held(s) -> int:
	var n := 0
	for k in s.people.kith:
		if k["tool"] > 0:
			n += 1
	return n


## Harvests by hand before a Kith learns the next resource: Data.LEARN_CLICKS, but only Data.LEARN_FIRST for the very first
## resource anyone learns, so the first lesson comes quickly.
static func learn_needed(s) -> int:
	return Data.LEARN_FIRST if s.people.learned_by.is_empty() else Data.LEARN_CLICKS


## Count a harvest toward teaching `item`; at learn_needed the next Kith in Data.PEOPLE_NAMES learns it.
static func teach(s, item: String) -> void:
	if Data.HAND_HOLD.has(item):
		return  # ore isn't taught: a Mine digs it
	s.hand_counts[item] = s.hand_counts.get(item, 0) + 1
	if s.people.knows(item) or s.hand_counts[item] < learn_needed(s):
		return
	var who: String = (
		s.people.kith[s.people.learned_by.size() % s.people.kith.size()]["name"]
		if not s.people.kith.is_empty()
		else Data.NAMELESS % Data.PEOPLE["one"]
	)
	s.people.learn(item, who)
	var job: Dictionary = Data.HUT_JOBS.get(item, Data.JOB_ANY)
	s.events.append(Data.LEARNED_LINE % [who, job["craft"], job["title"]])


# --- Crafting by hand ----------------------------------------------------------


static func recipe_unlocked(s, recipe: String) -> bool:
	return s.tech_tree.researched.has(Data.RECIPES[recipe]["tech"])


static func craft(s, recipe: String) -> bool:
	var r: Dictionary = Data.RECIPES[recipe]
	if not recipe_unlocked(s, recipe) or not s.economy.can_afford(r["in"]):
		return false
	s.economy.pay(r["in"])
	for id in r["in"]:
		s.economy.flows.add(id, -r["in"][id], "craft")
	for id in r["out"]:
		s.economy.add(id, r["out"][id])
		s.economy.flows.add(id, r["out"][id], "craft")
	if r["out"].has("flint_tools"):
		s.hand_tools = true
	return true
