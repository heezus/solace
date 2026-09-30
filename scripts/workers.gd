extends RefCounted
## Building workers (design-system/14-hands-to-haulers.md). A worker walks to their building. A hut's
## worker walks out to a resource tile the Kith know and brings back a bundle: to the stockpile, one
## trip per click, before Paths & Haulers; into the hut, over and over, after it. Clicking a building
## sends a trip, or rushes it. Static, and works on the GameState passed in.

const Data = preload("res://scripts/data.gd")
const Roads = preload("res://scripts/roads.gd")


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
			if not Roads.automated(s, b) and b["trips"] <= 0:
				return  # waits for a click
			var target := next_gather_tile(s, k, b)
			if target.x < 0:
				return  # nothing here it knows how to gather yet
			k["trip"] = not Roads.automated(s, b)
			if k["trip"]:
				s.record_story("first_trip")
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
	if item == "":  # the tile changed while they worked (a road cut through it): nothing to bring
		k["task"] = {}
		s._walk_to(k, b["pos"])
		k["phase"] = "to_home"
		return
	k["carry"] = {item: s._harvest_amount(b, tile, item)}
	s._wear(b)
	k["task"] = {}
	if k["trip"] and s._walk_to(k, s._nearest_depot(b["pos"])):
		k["phase"] = "to_depot"
	else:
		k["trip"] = false  # no way to the stockpile: leave it in the hut for a click to collect
		s._walk_to(k, b["pos"])
		k["phase"] = "to_home"


## What a hut gathers at `tile`.
static func tile_item(s, _b: Dictionary, tile: Vector2i) -> String:
	return Data.TILES[s.tile_at(tile)]["yields"]


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


## The next tile in the hut's rotation that the Kith know how to gather and can reach, or
## Vector2i(-1, -1) when there's nothing (bare grass gives nothing: Fiber comes from flax).
static func next_gather_tile(s, k: Dictionary, b: Dictionary) -> Vector2i:
	var tiles: Array = s.gather_tiles(b["pos"]).filter(func(t): return s.knows(Data.TILES[s.tile_at(t)]["yields"]))
	for _attempt in tiles.size():
		var t: Vector2i = tiles[b["gather_index"] % tiles.size()]
		b["gather_index"] += 1
		if s._walk_to(k, t):
			return t
	return Vector2i(-1, -1)


## True if a hut at p would find something the Kith know how to gather.
static func knows_any(s, p: Vector2i) -> bool:
	for t in s.gather_tiles(p):
		if s.knows(Data.TILES[s.tile_at(t)]["yields"]):
			return true
	return false


# --- Job titles ----------------------------------------------------------------


## The job title of whoever works building b: the building's `job`, or for a hut the title of what it
## gathers most (among what the Kith know, once they know any of it).
static func building_job(s, b: Dictionary) -> String:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if def.has("job"):
		return def["job"]
	if def["kind"] != "gatherer":
		return ""
	var counts := {}
	for item in b["gather_items"]:
		counts[item] = counts.get(item, 0) + (100 if s.knows(item) else 1)
	var best := "fiber"
	for item in counts:
		if counts[item] > counts.get(best, 0):
			best = item
	return Data.HUT_JOBS[best]["title"]


## A Kith's job title: from their building, Hauler, or Idle.
static func job_of(s, k: Dictionary) -> String:
	match k["job"]:
		"work":
			return building_job(s, s.buildings[k["building"]])
		"haul":
			return Data.JOB_HAULER
	return Data.JOB_IDLE


## "Aro the Woodcutter".
static func title_of(s, k: Dictionary) -> String:
	return "%s the %s" % [k["name"], job_of(s, k)]


## "3 Woodcutters, 1 Potter, 2 Haulers": how many Kith have each job, most first.
static func job_counts(s) -> String:
	var counts := {}
	for k in s.kith:
		var job := job_of(s, k)
		counts[job] = counts.get(job, 0) + 1
	var jobs: Array = counts.keys()
	jobs.sort_custom(func(a, b): return counts[a] > counts[b] or (counts[a] == counts[b] and a < b))
	var parts: Array = []
	for job in jobs:
		var many: String = job if counts[job] == 1 or job == Data.JOB_IDLE else job + "s"
		parts.append("%d %s" % [counts[job], many])
	return ", ".join(parts)


# --- Clicking buildings ------------------------------------------------------


## A click on building i. Before Paths & Haulers a hut sends out a trip and a workshop is loaded and
## emptied by hand; a working building is also rushed. Returns a short note for the map, or "".
static func click(s, i: int) -> String:
	var b: Dictionary = s.buildings[i]
	var kind: String = Data.BUILDINGS[b["type"]]["kind"]
	if not s.needs_worker(b):
		return ""
	if not Roads.automated(s, b):
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
	s.rushes += 1
	if Data.BUILDINGS[b["type"]]["kind"] == "processor":
		s._finish_cycle(b)
		return true
	var k: Dictionary = s.kith[b["worker"]]
	if k["phase"] in ["to_tile", "harvest"]:
		var tile: Vector2i = k["task"].get("tile", b["pos"])
		var item := tile_item(s, b, tile)
		if item != "":  # "" when a road felled or cut the tile away under them: nothing to bring
			k["carry"] = {item: s._harvest_amount(b, tile, item)}
			s._wear(b)
	_deliver(s, k, b)
	k["task"] = {}
	k["path"] = []
	k["timer"] = 0.0
	k["pos"] = Vector2(b["pos"])
	k["phase"] = "home"
	return true


# --- Status ----------------------------------------------------------------------


## Why a staffed building is standing still: full, or short of an input.
static func idle_reason(s, b: Dictionary, def: Dictionary) -> void:
	var auto := Roads.automated(s, b)
	if s.buffered(b["out"]) >= Data.BUFFER_CAP:
		if auto:
			s.town.set_status(b, "Full: waiting for a hauler", "Full: waiting for a hauler")
		else:
			s.town.set_status(b, "Full: click to collect" + road_note(s, b), "Full: click to collect")
		return
	var missing: Array = []
	for id in def.get("in", {}):
		if b["inbuf"].get(id, 0) < def["in"][id]:
			missing.append(Data.ITEMS[id]["name"])
	if missing.is_empty():
		b["status"] = "Idle"
		return
	var how := "waiting for a hauler" if auto else "click to load" + road_note(s, b)
	if auto:
		for id in def["in"]:
			if b["inbuf"].get(id, 0) + b["incoming"].get(id, 0) < def["in"][id] and s.inv.get(id, 0) == 0:
				how = "stockpile is out"
	s.town.set_status(b, "Needs %s (%s)" % [", ".join(missing), how], "Needs " + ", ".join(missing))


## After Paths & Haulers, what a building with no road link needs: "" once it's linked (or before).
static func road_note(s, b: Dictionary) -> String:
	if not s.has_haulers() or Roads.linked(s, b):
		return ""
	return ". Needs road: " + road_hint(s, b["pos"])


## "lay Road from here to the Hearth (4 tiles), then haulers carry for it".
static func road_hint(s, p: Vector2i) -> String:
	var g := Roads.gap(s, p)
	if g["to"].x < 0:
		return "linked by road"
	var what := "the road to the Hearth" if s.roads.has(g["to"]) else "the Hearth"
	if s.building_at.has(g["to"]) and g["to"] != s.camp_pos:
		what = "the Storehouse"
	return "lay Road from here to %s (about %d tiles) so haulers carry for it" % [what, g["tiles"]]
