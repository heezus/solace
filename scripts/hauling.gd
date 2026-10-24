extends RefCounted
## Hauler places (design-system/14-hands-to-haulers.md, Step 2). The Hearth and every Storehouse hold hauler places. A Kith in a place
## hauls for that depot only. Each depot's wanted count is worked out from its load: for every road-linked building it serves, the
## trips a minute the building needs (its output and its inputs over a hauler's carry) times the round trip from the depot, summed
## and rounded up, at least 1 for a depot with work. It is read again every REFRESH game seconds. The player may set a depot above
## or below that number (`offset`). Workshops are staffed only while the haulers the load needs at the least are still there
## (Kith._staff asks `total_needed`; the places fill to the roomier wanted count from the Kith left over), and a Kith with no place
## goes to the depot furthest below its count (`assign`).
## Sim owns one, reached as `sim.hauling`. Static helpers work on the Sim passed in; this block keeps no reference to a block.

const Data = preload("res://scripts/data.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Homes = preload("res://scripts/homes.gd")
const Kith = preload("res://scripts/kith.gd")
const Roads = preload("res://scripts/roads.gd")
const Work = preload("res://scripts/work.gd")

const LOG_WINDOW := 60.0  # game seconds a delivery stays in `trip_log`
const REFRESH := 30.0  # game seconds between readings of each depot's load
const NONE := Vector2i(-1, -1)  # a hauler with no depot yet
const USE := 0.5  # the share of a hauler's time the load may fill: under 1.0 leaves room for the walk back and for waiting on each other
const HANDLING := 2.0  # seconds a trip spends loading and unloading
const GATHER_WALK := 6.0  # seconds a hut's worker walks out and back around one harvest
const STUCK_FOR := 30.0  # game seconds before a hauler no depot can be walked to looks again
const FAR_TRIP := 14.0  # tiles: a depot whose average one-way trip is longer wants a Storehouse nearer its workshops
const HOME_TRIPS := 0.25  # trips a minute a home or a Teardown Bench takes
const FED_TRIPS := 0.5  # trips a minute a Boiler, a Lamp or a Pen takes

## Per depot: the haulers its load needs, from the last reading. A depot is a key while roads reach buildings it serves.
var auto: Dictionary = {}
## Per depot: how many above (or, below zero, under) the auto count the player has set.
var offset: Dictionary = {}
## Per depot: the haulers its load needs at the very least (every hauler's time filled), from the last reading. Workshops are only
## held back for these; `auto` is the roomier count the places are filled to.
var need: Dictionary = {}
var trip_tiles: Dictionary = {}  # depot -> the average one-way trip to the buildings it serves, in tiles, by their load (not saved)
var names: Dictionary = {}  # depot -> "Storehouse by the Smelter", read with the load
var stopped_since: Dictionary = {}  # building tile -> the game clock when it stopped for a hauler (_watch_stopped)
var trip_log: Array = []  # {at, from, to, item, amount}: what haulers delivered in the last LOG_WINDOW seconds, for Sight (not saved)
var _have: Dictionary = {}  # depot -> haulers in its places, from the last `assign`
var _clock := REFRESH
var _now := 0.0  # game seconds this block has run (not saved)
var _census: Dictionary = {}  # depot -> {free, walking, busy, trips: what the busy ones do -> how many}, read once a second (not saved)
var _census_at := -1.0
var _stuck: Dictionary = {}  # hauler name -> `_now` until which a hauler with no reachable place is left alone (not saved)


## One tick: read the loads when it is time, then give every hauler a place.
func tick(s, delta: float) -> void:
	_now += delta
	_watch_stopped(s)
	_clock = snappedf(_clock + delta, 0.000001)  # kept to millionths, so a saved game reads back the very same number
	if _clock >= REFRESH:
		_clock = 0.0
		refresh(s)
	assign(s)


## Note one delivery of `amount` of `item` from one tile to another (a depot to a building, or a building to a depot).
func log_trip(s, from: Vector2i, to: Vector2i, item: String, amount: int) -> void:
	var now: float = s.seasons.time
	trip_log.append({"at": now, "from": from, "to": to, "item": item, "amount": amount})
	while not trip_log.is_empty() and trip_log[0]["at"] < now - LOG_WINDOW:
		trip_log.pop_front()


## Note when each building a hauler serves stopped for one (short of an input for its next cycle, or full up), by the game
## clock, and forget the ones running again. Haulers go to the ones that have waited longest first (Haulers.URGENT).
func _watch_stopped(s) -> void:
	var now := {}
	for b in s.town.buildings:
		if Buildings.served(b) and Haulers.stopped(b):
			now[b["pos"]] = true
			if not stopped_since.has(b["pos"]):
				stopped_since[b["pos"]] = s.seasons.time
	for pos in stopped_since.keys():
		if not now.has(pos):
			stopped_since.erase(pos)


## Game seconds the building at `pos` has stood stopped for a hauler (0 when it runs).
func stopped_for(s, pos: Vector2i) -> float:
	return s.seasons.time - stopped_since[pos] if stopped_since.has(pos) else 0.0


# --- What is wanted ------------------------------------------------------------------------------------------------


## Haulers `depot` wants: its auto count and the player's offset, never below 0 (0 for a depot nothing is linked to).
func wanted(depot: Vector2i) -> int:
	if not auto.has(depot):
		return 0
	return maxi(auto[depot] + offset.get(depot, 0), 0)


## Haulers the depots need at the very least, with the player's settings, together: what a new workshop leaves free (Kith._staff).
func total_needed() -> int:
	var n := 0
	for depot in need:
		n += maxi(need[depot] + offset.get(depot, 0), 0)
	return n


## Haulers wanted by every depot together.
func total_wanted() -> int:
	var n := 0
	for depot in auto:
		n += wanted(depot)
	return n


## Haulers in `depot`'s places now.
func have(depot: Vector2i) -> int:
	return _have.get(depot, 0)


## Haulers in a place anywhere.
func total_have() -> int:
	var n := 0
	for depot in _have:
		n += _have[depot]
	return n


## How many haulers `depot` has beyond what it wants (below 0: it is short).
func surplus(depot: Vector2i) -> int:
	return have(depot) - wanted(depot)


## True when some depot has under three quarters of the haulers it wants.
func is_short() -> bool:
	for depot in auto:
		var want := wanted(depot)
		if want > 0 and float(have(depot)) < 0.75 * want:
			return true
	return false


## "Haulers 18 of 24" for the top bar, "" while no depot has work.
func bar_text() -> String:
	var want := total_wanted()
	return Data.HAULERS_BAR % [total_have(), want] if want > 0 else ""


## "Waiting for a hauler: Storehouse by the Smelter, 2 of 6" for a building whose depot has places, "" when it has none.
func waiting_note(s, b: Dictionary) -> String:
	var depot: Vector2i = Roads.depot_of(s, b)
	if not auto.has(depot):
		return ""
	return Data.HAULER_WAIT % [names.get(depot, "the depot"), have(depot), wanted(depot)]


## The one line a short depot's card adds: the cheapest lever, "" while the depot has 75% of its haulers or more.
func lever_note(depot: Vector2i) -> String:
	var want := wanted(depot)
	if want <= 0 or float(have(depot)) >= 0.75 * want:
		return ""
	return Data.HAULER_LEVER_FAR if trip_tiles.get(depot, 0.0) > FAR_TRIP else Data.HAULER_LEVER_KITH


## The player sets `depot`'s wanted count one above (dir 1) or one below (dir -1) what it is now.
func nudge(depot: Vector2i, dir: int) -> void:
	if not auto.has(depot):
		return
	if dir < 0 and wanted(depot) <= 0:
		return
	offset[depot] = offset.get(depot, 0) + dir
	if offset[depot] == 0:
		offset.erase(depot)


## Back to the auto count.
func reset(depot: Vector2i) -> void:
	offset.erase(depot)


# --- Reading the loads ---------------------------------------------------------------------------------------------


## Work out every depot's auto count from the buildings roads link to it, and move idle haulers from depots with more than they
## want to the ones that are short.
func refresh(s) -> void:
	var load_of := {}
	var tiles_of := {}  # depot -> trips a minute times the tiles of each building, to average
	var rate_of := {}  # depot -> trips a minute in all
	for b in s.town.buildings:
		if not Roads.automated(s, b):
			continue
		var rate := trips_per_minute(s, b)
		if rate <= 0.0:
			continue
		var depot := Roads.depot_of(s, b)
		load_of[depot] = load_of.get(depot, 0.0) + rate * round_trip(b, depot) / 60.0
		rate_of[depot] = rate_of.get(depot, 0.0) + rate
		tiles_of[depot] = tiles_of.get(depot, 0.0) + rate * (absi(depot.x - b["pos"].x) + absi(depot.y - b["pos"].y))
	auto = {}
	need = {}
	names = {}
	trip_tiles = {}
	for depot in Roads.posts(s):
		trip_tiles[depot] = tiles_of.get(depot, 0.0) / rate_of[depot] if rate_of.get(depot, 0.0) > 0.0 else 0.0
		auto[depot] = maxi(ceili(load_of.get(depot, 0.0) / USE - 0.0001), 1)
		need[depot] = maxi(ceili(load_of.get(depot, 0.0) - 0.0001), 1)
		names[depot] = _name_of(s, depot)
	for depot in offset.keys():
		if not auto.has(depot):
			offset.erase(depot)  # the depot is gone, or no longer serves anything
	_rebalance(s)


## Trips a minute building `b` asks of the haulers: 0 while it is paused, held, overgrown, resting, or has no worker.
static func trips_per_minute(s, b: Dictionary) -> float:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if s.tide.is_overgrown(b):
		return 0.0
	if Homes.is_home(b) or def["kind"] == "bench":
		return HOME_TRIPS
	if def.get("fed", false):
		return FED_TRIPS
	if (
		not Buildings.needs_worker(b)
		or b["paused"]
		or s.livewire.is_held(b)
		or b["worker"] < 0
		or b.get("resting", false)
	):
		return 0.0
	var carry := float(Haulers.carry_cap(s))
	if def["kind"] == "gatherer":
		var item: String = b["focus"]
		if item == "" or not s.people.knows(item):
			return 0.0
		return 60.0 / (Work.time(s, b) + GATHER_WALK) * Work.bundle_size(s, b, item) / carry
	var cycle := Work.time(s, b)
	if cycle <= 0.0:
		return 0.0
	var items := 0
	for amount in Buildings.recipe_in(b).values():
		items += amount
	for amount in Buildings.recipe_out(b).values():
		items += amount
	return 60.0 / cycle * items / carry


## Seconds for a hauler to go from `depot` to `b` and back on the roads, with the time to load and unload.
static func round_trip(b: Dictionary, depot: Vector2i) -> float:
	var tiles := absi(depot.x - b["pos"].x) + absi(depot.y - b["pos"].y)
	var per_tile: float = Data.WALK_COST["road"] / Data.ROAD_SPEEDS[0] / Data.KITH_SPEED
	return 2.0 * tiles * per_tile + HANDLING


## "Storehouse by the Smelter": the depot and the nearest building with a crew, or "Hearth".
func _name_of(s, depot: Vector2i) -> String:
	if depot == s.world.camp_pos:
		return Data.HEARTH_NAME
	var best := ""
	var best_d := 1 << 30
	for b in s.town.buildings:
		if not Buildings.needs_worker(b):
			continue
		var d := absi(depot.x - b["pos"].x) + absi(depot.y - b["pos"].y)
		if d < best_d:
			best_d = d
			best = Data.BUILDINGS[b["type"]]["name"]
	var base: String = Data.BUILDINGS["storehouse"]["name"]
	return Data.DEPOT_BY % [base, best] if best != "" else base


# --- Giving haulers a place ----------------------------------------------------------------------------------------


## Every hauler with no place (new, or its depot has gone) goes to the depot furthest below its count.
func assign(s) -> void:
	_have = {}
	var loose: Array = []
	for k in s.people.kith:
		if k["job"] != "haul":
			continue
		var depot: Vector2i = k.get("depot", NONE)
		if auto.has(depot):
			_have[depot] = _have.get(depot, 0) + 1
		else:
			loose.append(k)
	for k in loose:
		if _stuck.get(k["name"], 0.0) > _now:
			continue
		var pick := _neediest(s, k)
		k["depot"] = pick
		if pick != NONE:
			_have[pick] = _have.get(pick, 0) + 1
		else:
			_stuck[k["name"]] = _now + STUCK_FOR


## The depot with the smallest share of its places filled (the most places open breaks a tie) that Kith `k` can get to, NONE when
## no depot has work or none can be reached (a mine across the water keeps its own hauler). By share, so a short town fills every
## depot a little before the Hearth fills up: a Storehouse with none of its haulers leaves its buildings waiting for good.
func _neediest(s, k: Dictionary) -> Vector2i:
	var left: Array = auto.keys()
	left.sort_custom(
		func(a, b):
			return _share(a) < _share(b) or (_share(a) == _share(b) and wanted(a) - have(a) > wanted(b) - have(b))
	)
	for depot in left:
		if _can_go(s, k, depot):
			return depot
	return NONE


## True when Kith `k` can get to `depot`: a hauler with a cart only by road (it waits where it stands when the roads do not join),
## one on foot across country.
func _can_go(s, k: Dictionary, depot: Vector2i) -> bool:
	var here := Kith.tile_of(k)
	if k["cart"]:
		return Roads.can_reach(s, k, here, depot)
	return s.people.can_walk(here, depot)


## Share of `depot`'s places filled (1 or more when full; a depot that wants none counts as full).
func _share(depot: Vector2i) -> float:
	return float(have(depot)) / wanted(depot) if wanted(depot) > 0 else INF


## The haulers in each depot's places now, read at most once a game second: how many stand free at it, how many are walking
## back to it, how many are on a trip, and what the trips are (for the status line, WaitWhy.of).
func census(s) -> Dictionary:
	if _census_at >= 0.0 and _now - _census_at < 1.0:
		return _census
	_census_at = _now
	_census = {}
	for k in s.people.kith:
		if k["job"] != "haul":
			continue
		var depot: Vector2i = k.get("depot", NONE)
		if not _census.has(depot):
			_census[depot] = {"free": 0, "walking": 0, "busy": 0, "trips": {}}
		var row: Dictionary = _census[depot]
		if not k["task"].is_empty():
			row["busy"] += 1
			var what := _trip_text(s, k["task"])
			row["trips"][what] = row["trips"].get(what, 0) + 1
		elif Kith.tile_of(k) == depot:
			row["free"] += 1
		else:
			row["walking"] += 1
	return _census


## What a hauler's task is, in a few words: "bringing Clay to a Kiln", "emptying a Smelter", "carrying goods home".
func _trip_text(s, task: Dictionary) -> String:
	var b: Dictionary = s.town.buildings[task["building"]]
	var name: String = Data.BUILDINGS[b["type"]]["name"]
	match task["kind"]:
		"deliver":
			return "bringing %s to a %s" % [Data.ITEMS[task["item"]]["name"], name]
		"pickup":
			return "emptying a %s" % name
		"part":
			return "bringing a part to the %s" % name
	return "carrying goods home"


## Idle haulers walk over to the depot with the smallest share of its places filled, when they leave a depot better off than that
## one would be: from one with more than it wants, or from a well-filled one to one far short (all the town's depots short alike).
func _rebalance(s) -> void:
	assign(s)
	for k in s.people.kith:
		if k["job"] != "haul" or not k["task"].is_empty():
			continue
		var from: Vector2i = k.get("depot", NONE)
		if not auto.has(from):
			continue
		var to := _neediest(s, k)
		if to == NONE or to == from or surplus(to) >= 0:
			continue
		if surplus(from) <= 0 and float(have(to) + 1) / wanted(to) > float(have(from) - 1) / maxi(wanted(from), 1):
			continue
		_have[from] -= 1
		_have[to] = have(to) + 1
		k["depot"] = to


# --- Save ----------------------------------------------------------------------------------------------------------


## The player's settings, the readings, the clock and when each building stopped, as JSON-safe values.
func to_dict() -> Dictionary:
	var settings: Array = []
	for depot in offset:
		settings.append([depot.x, depot.y, offset[depot]])
	var read: Array = []
	for depot in auto:
		read.append([depot.x, depot.y, auto[depot], names.get(depot, ""), need.get(depot, auto[depot])])
	var stopped: Array = []
	for pos in stopped_since:
		stopped.append([pos.x, pos.y, stopped_since[pos]])
	return {"offset": settings, "auto": read, "clock": _clock, "stopped": stopped}


func from_dict(d: Dictionary) -> void:
	offset = {}
	for e in d.get("offset", []):
		offset[Vector2i(int(e[0]), int(e[1]))] = int(e[2])
	auto = {}
	need = {}
	names = {}
	for e in d.get("auto", []):
		var depot := Vector2i(int(e[0]), int(e[1]))
		auto[depot] = int(e[2])
		names[depot] = String(e[3])
		need[depot] = int(e[4]) if e.size() > 4 else auto[depot]
	_clock = float(d.get("clock", REFRESH))
	stopped_since = {}
	for e in d.get("stopped", []):
		stopped_since[Vector2i(int(e[0]), int(e[1]))] = float(e[2])
	_have = {}
