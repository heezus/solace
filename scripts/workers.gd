extends RefCounted
## Building workers (design-system/14-hands-to-haulers.md). A worker walks to their building. A hut's
## worker walks out to a resource tile the Kith know and brings back a bundle: to the stockpile, one
## trip per click, before Paths & Haulers; into the hut, over and over, after it. Clicking a building
## sends a trip, or rushes it. Static, and works on the GameState passed in.

const Data = preload("res://scripts/data.gd")


## One step of a worker's day at their building.
static func tick(s, k: Dictionary, delta: float) -> void:
	var b: Dictionary = s.buildings[k["building"]]
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	match k["phase"]:
		"to_site":
			if k["path"].is_empty() and s._tile_of(k) != b["pos"] and not s._walk_to(k, b["pos"]):
				b["unreachable"] = 1.0
				return
			if s._step(k, delta):
				k["phase"] = "home"
		"home":
			if def["kind"] != "gatherer" or s.buffered(b["out"]) >= Data.BUFFER_CAP:
				return
			if not s.has_haulers() and b["trips"] <= 0:
				return  # waits for a click
			var target := next_gather_tile(s, k, b)
			if target.x < 0:
				return  # nothing here it knows how to gather yet
			k["trip"] = not s.has_haulers()
			if k["trip"]:
				s.record_story("first_trip")
			if target == b["pos"]:
				k["phase"] = "harvest"  # nothing reachable: cut grass by the hut
			else:
				k["task"] = {"tile": target}
				k["phase"] = "to_tile"
		"to_tile":
			if s._step(k, delta):
				k["phase"] = "harvest"
		"harvest":
			var tile: Vector2i = k["task"].get("tile", b["pos"])
			k["timer"] += delta
			if k["timer"] >= s._harvest_time(b, tile):
				_finish_harvest(s, k, b, tile)
		"to_home":
			if s._step(k, delta):
				_deliver(s, k, b)
				k["phase"] = "home"
		"to_depot":
			if s._step(k, delta):
				_deliver(s, k, b)
				s._walk_to(k, b["pos"])
				k["phase"] = "to_site"


## The worker has gathered a bundle at `tile`: carry it to the stockpile on a trip, or home to the hut.
static func _finish_harvest(s, k: Dictionary, b: Dictionary, tile: Vector2i) -> void:
	k["timer"] = 0.0
	var item := tile_item(s, b, tile)
	k["carry"] = {item: s._harvest_amount(b, tile, item)}
	s._wear(b)
	k["task"] = {}
	if k["trip"] and s._walk_to(k, s._nearest_depot(b["pos"])):
		k["phase"] = "to_depot"
	else:
		k["trip"] = false  # no way to the stockpile: leave it in the hut for a click to collect
		s._walk_to(k, b["pos"])
		k["phase"] = "to_home"


## What a hut gathers at `tile` (the hut's own tile means cutting grass for Fiber).
static func tile_item(s, b: Dictionary, tile: Vector2i) -> String:
	return Data.TILES[s.tile_at(tile)]["yields"] if tile != b["pos"] else "fiber"


## Put down what a hut worker carries: into the stockpile at the end of a trip, else into the hut.
static func _deliver(s, k: Dictionary, b: Dictionary) -> void:
	for id in k["carry"]:
		if k["trip"]:
			s.add(id, k["carry"][id])
		else:
			b["out"][id] = b["out"].get(id, 0) + k["carry"][id]
		s.flows.add(id, k["carry"][id], b["type"])
	k["carry"] = {}
	if k["trip"]:
		b["trips"] = maxi(b["trips"] - 1, 0)
	k["trip"] = false


## The next tile in the hut's rotation that the Kith know how to gather and can reach. Falls back to
## the hut itself (cutting grass) once Fiber is known, and Vector2i(-1, -1) when there's nothing.
static func next_gather_tile(s, k: Dictionary, b: Dictionary) -> Vector2i:
	var tiles: Array = s.gather_tiles(b["pos"]).filter(func(t): return s.knows(Data.TILES[s.tile_at(t)]["yields"]))
	for _attempt in tiles.size():
		var t: Vector2i = tiles[b["gather_index"] % tiles.size()]
		b["gather_index"] += 1
		if s._walk_to(k, t):
			return t
	return b["pos"] if s.knows("fiber") else Vector2i(-1, -1)


## True if a hut at p would find something the Kith know how to gather.
static func knows_any(s, p: Vector2i) -> bool:
	if s.knows("fiber"):
		return true
	for t in s.gather_tiles(p):
		if s.knows(Data.TILES[s.tile_at(t)]["yields"]):
			return true
	return false


# --- Clicking buildings ------------------------------------------------------


## A click on building i. Before Paths & Haulers a hut sends out a trip and a workshop is loaded and
## emptied by hand; a working building is also rushed. Returns a short note for the map, or "".
static func click(s, i: int) -> String:
	var b: Dictionary = s.buildings[i]
	var kind: String = Data.BUILDINGS[b["type"]]["kind"]
	if not s.needs_worker(b):
		return ""
	if not s.has_haulers():
		var held: int = s.buffered(b["out"])
		s.haul(i)
		if kind == "gatherer":
			var note := dispatch(s, i)
			return note if held == 0 else "+%d · %s" % [held, note]
	if rush(s, i):
		return "Rushed!"
	if b["rush_cd"] > 0.0:
		return "Rush in %d s" % ceili(b["rush_cd"])
	return ""


## Queue one trip at hut i (up to Data.TRIP_QUEUE). Returns what happened, for the map.
static func dispatch(s, i: int) -> String:
	var b: Dictionary = s.buildings[i]
	if not knows_any(s, b["pos"]):
		return "Nothing learned yet: gather by hand %dx" % Data.LEARN_CLICKS
	if b["trips"] >= Data.TRIP_QUEUE:
		return "Trips full (%d)" % Data.TRIP_QUEUE
	b["trips"] += 1
	return "Trip %d/%d" % [b["trips"], Data.TRIP_QUEUE]


## True while building b is partway through a cycle that a rush can finish.
static func can_rush(s, b: Dictionary) -> bool:
	if b["rush_cd"] > 0.0 or b["paused"] or b["worker"] < 0:
		return false
	match Data.BUILDINGS[b["type"]]["kind"]:
		"gatherer":
			return s.kith[b["worker"]]["phase"] in ["to_tile", "harvest", "to_home", "to_depot"]
		"processor":
			return b["status"] == "Working"
	return false


## Finish building i's current cycle now: a workshop makes its goods, a hut worker is back home with
## the bundle put away. Then it can't be rushed for Data.RUSH_COOLDOWN seconds.
static func rush(s, i: int) -> bool:
	var b: Dictionary = s.buildings[i]
	if not can_rush(s, b):
		return false
	b["rush_cd"] = Data.RUSH_COOLDOWN
	if Data.BUILDINGS[b["type"]]["kind"] == "processor":
		s._finish_cycle(b)
		return true
	var k: Dictionary = s.kith[b["worker"]]
	if k["phase"] in ["to_tile", "harvest"]:
		var tile: Vector2i = k["task"].get("tile", b["pos"])
		var item := tile_item(s, b, tile)
		k["carry"] = {item: s._harvest_amount(b, tile, item)}
		s._wear(b)
	_deliver(s, k, b)
	k["task"] = {}
	k["path"] = []
	k["timer"] = 0.0
	k["pos"] = Vector2(b["pos"])
	k["phase"] = "home"
	return true
