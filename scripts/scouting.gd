extends RefCounted
## Scouting (design-system/17-needs-and-upgrades.md): clicking fog sends the nearest idle Kith out to look. No road is
## needed. The scout walks to the tile (or, if it is water, the nearest dry tile), lifts the fog in a radius there
## (Data.SCOUT_SIGHT, and Scouting research adds to it), then walks home to the Hearth and is idle again. A scout's state
## is in the Kith's own fields: job "scout", phase "scout_out" or "scout_home", and `task` = {tile} (no "kind": that is for
## haulers, see Kith.drop_task), so it is saved with them. Static, and works on the Sim passed in. Lookouts that reveal
## without a trip come later.

const Data = preload("res://scripts/data.gd")
const Kith = preload("res://scripts/kith.gd")

const NEAR := 3  # how far from a clicked water tile a dry tile may be found
const SAME_PLACE := 3.0  # a second click this near a scout's target adds no second scout


## True for a Kith who may go: with no job, or a hauler with nothing in hand (not a cart, which keeps to the roads).
static func available(k: Dictionary) -> bool:
	match k["job"]:
		"":
			return true
		"haul":
			return k["task"].is_empty() and k["carry"].is_empty() and not k["cart"]
	return false


## True for a Kith out scouting.
static func is_scout(k: Dictionary) -> bool:
	return k["job"] == "scout"


## How many Kith are out scouting.
static func count(s) -> int:
	var n := 0
	for k in s.people.kith:
		n += 1 if is_scout(k) else 0
	return n


## The tile a scout can walk to for fog tile `p`: `p` itself, or the nearest tile within NEAR that is not blocked (a click
## on the river). (-1, -1) when there is none.
static func goal(s, p: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-NEAR, NEAR + 1):
		for dx in range(-NEAR, NEAR + 1):
			var q := p + Vector2i(dx, dy)
			if not s.world.in_bounds(q) or s.pathing.astar.is_point_solid(q):
				continue
			var d := Vector2(dx, dy).length()
			if d < best_d:
				best = q
				best_d = d
	return best


## How far a scout sees from where they stand: Data.SCOUT_SIGHT, and Scouting research adds to it as it does to every sight.
static func sight(s) -> int:
	return Data.SCOUT_SIGHT + (Data.SCOUTING_SIGHT if s.tech_tree.researched.has("scouting") else 0)


## Send the nearest idle Kith to look at fog tile `p`. Returns what to tell the player: who went, or why nobody did ("" for a
## click that is not on fog).
static func send(s, p: Vector2i) -> String:
	if not s.world.in_bounds(p) or s.fog.is_revealed(p):
		return ""
	var to := goal(s, p)
	if to.x < 0:
		return Data.SCOUT_NO_WAY
	for k in s.people.kith:
		if is_scout(k) and Vector2(k["task"]["tile"]).distance_to(Vector2(to)) <= SAME_PLACE:
			return Data.SCOUT_BUSY
	var best := -1
	var best_d := INF
	for i in s.people.kith.size():
		var candidate: Dictionary = s.people.kith[i]
		if not available(candidate):
			continue
		var d := Vector2(Kith.tile_of(candidate)).distance_to(Vector2(to))
		if d < best_d:
			best = i
			best_d = d
	if best < 0:
		return Data.SCOUT_NOBODY % Data.PEOPLE["many"]
	var k: Dictionary = s.people.kith[best]
	s.people.drop_task(k)
	if not s.people.walk_to(k, to):
		return Data.SCOUT_NO_WAY
	k["job"] = "scout"
	k["phase"] = "scout_out"
	k["task"] = {"tile": to}
	k["timer"] = 0.0
	k["cart"] = false
	return Data.SCOUT_SENT % k["name"]


## One step for scout `k`: walk out, look around, walk home. Idle again at the Hearth.
static func tick(s, k: Dictionary, delta: float) -> void:
	if not s.people.step(k, delta):
		return
	if k["phase"] == "scout_out":
		s.fog.reveal(Kith.tile_of(k), sight(s))
		k["phase"] = "scout_home"
		if s.people.walk_to(k, s.world.camp_pos):
			return
	_end(k)


static func _end(k: Dictionary) -> void:
	k["job"] = ""
	k["phase"] = ""
	k["task"] = {}
	k["path"] = []
