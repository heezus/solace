extends RefCounted
## The Tide block (design-system/23-livewire.md, stage 2): the Bloom's creep out of the three south patches. It wakes with the first
## lit Generator (the hum carries south) and spreads like a flood fill that takes time: a tile joins the Bloom `cost` seconds after
## a neighbour does (open ground `step_seconds`, which follows the power the town draws; slower over roads, rock, rivers, paved
## ground, a Firebreak or a burning Shard Lamp's light), never by chance, so a seed always floods the same way.
## It never enters burnt ground, an Arc Lamp's light or the ring round the Hearth.
## Ground it takes becomes Bloom ground (`bloom_tide`, plain ground and trees and fields under it; ore, water and the tiles under a
## building or a road keep their own and only wear the Bloom's colour). A building it reaches is overgrown at once and lost after
## Data.OVERGROWN_LOST_SECONDS unless the ground is burnt clear or the building is held by light or fire. A Scorcher (fed, on a net)
## burns the Bloom ground nearest it clear, a tile at a time; burnt ground is never taken again. Arrival times for Tide Watch are
## worked out from the front as it stands. Sim owns one, reached as `sim.tide`. Everything is derived from game time, so none of
## it touches the earlier eras: with no Livewire begun, every function here does nothing.
## Signal: said(message) is a line for the event log.

signal said(message: String)

const Data = preload("res://scripts/data.gd")
const Codec = preload("res://scripts/save_codec.gd")

const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const PATCH_TILES := ["bloom_ground", "bloom_spore", "bloom_root", "bloom_sap"]

var begun := false
var time := 0.0  # game seconds since the tide began
var grown: Dictionary = {}  # tile -> true: Bloom ground the tide made
var burnt: Dictionary = {}  # tile -> true: ground burnt clear, which the tide never takes again
var front: Dictionary = {}  # tile -> the tide time it joins the Bloom
var hit: Dictionary = {}  # the tile of an overgrown building -> seconds it has been overgrown
var lost := 0  # buildings the Bloom has taken
var woke_at := -1.0  # the game clock (Seasons.time) when the tide woke, -1 before
var drawn := 0  # power units the machines draw now, read every Data.TIDE_ETA_SECONDS
var pace_hold := 0.0  # above 0: seconds per open tile whatever the town draws (a test or a measurement pins the pace)
var rev := 0  # changes whenever the Bloom's ground does
var eta: Dictionary = {}  # the tile of a building the tide has not reached -> the tide time it will (Tide Watch)
var _pace_clock := 0.0
var _told: Dictionary = {}  # building tile -> true once Tide Watch has warned of it
var _eta_clock := 0.0
var _eta_rev := -1
var _lamps: Array = []  # the lit Arc Lamps' tiles and light, this tick
var _burning: Array = []  # the burning Shard Lamps' tiles and light, this tick
var _fires: Array = []  # the burning Scorchers' tiles, this tick

# --- Each tick -----------------------------------------------------------------------------------------------------


## One tick: wake the tide at the first lit Generator, read the power drawn, let tiles join, count overgrown buildings down, keep
## Tide Watch's times.
func tick(s, delta: float) -> void:
	if not begun:
		if not s.story.has_event(Data.LIVEWIRE_BEGUN) or not _hum(s):
			return
		begin(s)
	_pace_clock += delta
	if _pace_clock >= Data.TIDE_ETA_SECONDS:
		_pace_clock = 0.0
		drawn = units_drawn(s)
	time += delta * s.seasons.tide_pace()
	refresh_lights(s)
	var due: Array = []
	for p in front:
		if front[p] <= time:
			due.append(p)
	due.sort_custom(
		func(a, b): return front[a] < front[b] or (front[a] == front[b] and a.x + a.y * 4096 < b.x + b.y * 4096)
	)
	for p in due:
		front.erase(p)
		match _state(s, p):
			0:
				_grow(s, p)
			1:
				front[p] = time + Data.TIDE_RETRY_SECONDS
	_overgrown(s, delta)
	if s.tech_tree.researched.has("tide_watch"):
		_watch(s, delta)


## Start the tide: every patch tile is Bloom already, and its neighbours join in their turn.
func begin(s) -> void:
	begun = true
	time = 0.0
	woke_at = s.seasons.time
	drawn = units_drawn(s)
	_pace_clock = 0.0
	var w: int = s.world.width
	for i in range(s.world.base_height * w, s.world.tiles.size()):
		if s.world.tiles[i] in PATCH_TILES:
			_spread_from(s, Vector2i(i % w, floori(float(i) / w)))
	rev += 1
	said.emit(Data.TIDE_BEGAN_LINE)


## True when a Generator or Shard Dynamo is burning, standing and not overgrown: the hum that wakes the tide.
func _hum(s) -> bool:
	for b in s.town.buildings:
		if b["type"] in Data.TIDE_WAKERS and b["burn"] > 0.0 and not hit.has(b["pos"]):
			return true
	return false


## The power units the machines draw now, summed over every net: what a net gives when it gives less than it is asked.
func units_drawn(s) -> int:
	var sum := 0
	for n in s.livewire.nets:
		sum += mini(n["asks"], n["given"])
	return sum


## Seconds the front takes to cross an open tile with `units` of power drawn.
static func step_for(units: int) -> float:
	return clampf(
		Data.TIDE_IDLE_SECONDS / (1.0 + float(units) / Data.TIDE_POWER_SCALE),
		Data.TIDE_MIN_SECONDS,
		Data.TIDE_IDLE_SECONDS
	)


## Seconds per open tile now.
func step_seconds() -> float:
	return pace_hold if pace_hold > 0.0 else step_for(drawn)


## What Tide Watch says of the pace: the units drawn and the seconds a tile takes.
func pace_line() -> String:
	if drawn <= 0:
		return Data.TIDE_PACE_IDLE % roundi(step_seconds())
	return Data.TIDE_PACE_NOTE % [drawn, roundi(step_seconds())]


## True when tile p is Bloom: ground the tide made, or one of the patches it came from.
func is_bloom(s, p: Vector2i) -> bool:
	return grown.has(p) or s.world.tile_at(p) in PATCH_TILES


## True when tile p is Bloom ground the tide made (Buildings.placement_error asks).
func bloom_at(p: Vector2i) -> bool:
	return grown.has(p)


## True when the building at p is overgrown (it stops, and is lost in time).
func is_overgrown_at(p: Vector2i) -> bool:
	return hit.has(p)


func is_overgrown(b: Dictionary) -> bool:
	return hit.has(b["pos"])


## True when tile p is burnt ground.
func is_burnt(p: Vector2i) -> bool:
	return burnt.has(p)


## 0 when the tide may take tile p now, 1 when it must wait (an Arc Lamp's light), 2 when it never will (taken, burnt, the Hearth's ring).
func _state(s, p: Vector2i) -> int:
	if grown.has(p) or burnt.has(p) or s.world.tile_at(p) in PATCH_TILES or _in_ring(s, p):
		return 2
	return 1 if _lit_by_arc(p) else 0


func _in_ring(s, p: Vector2i) -> bool:
	return Vector2(p).distance_to(Vector2(s.world.camp_pos)) <= Data.TIDE_HEARTH_RING


func _lit_by_arc(p: Vector2i) -> bool:
	for l in _lamps:
		if Vector2(l["pos"]).distance_to(Vector2(p)) <= l["light"]:
			return true
	return false


## Work out which lamps and Scorchers are lit, once a tick (the spread and Tide Watch ask about them for many tiles).
func refresh_lights(s) -> void:
	_lamps = _lit_lamps(s)
	_burning = []
	_fires = []
	for b in s.town.buildings:
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		if def["kind"] == "lamp" and b["burn"] > 0.0:
			_burning.append({"pos": b["pos"], "light": float(def["light"])})
		elif def["kind"] == "scorcher" and b["burn"] > 0.0 and s.town.is_powered(b["pos"]):
			_fires.append(b["pos"])


## The Arc Lamps that give light now: standing, not overgrown, on ground a net that gives power reaches.
func _lit_lamps(s) -> Array:
	var out: Array = []
	for b in s.town.buildings:
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		if def["kind"] == "arc_lamp" and not hit.has(b["pos"]) and s.town.is_powered(b["pos"]):
			out.append({"pos": b["pos"], "light": float(def["light"])})
	return out


## Seconds the tide takes to cross tile p.
func cost(s, p: Vector2i) -> float:
	var slow := 1.0
	var tile: String = s.world.tile_at(p)
	if s.world.roads.has(p):
		slow = Data.TIDE_SLOW_RAIL if s.world.road_tiers.get(p, 0) >= 2 else Data.TIDE_SLOW_ROAD
	elif tile == "rock" or tile == "river":
		slow = Data.TIDE_SLOW_ROAD
	if s.town.built_type(p) == "firebreak":
		slow = maxf(slow, Data.TIDE_SLOW_FIREBREAK)
	if _burning_lamp_lights(s, p):
		slow *= Data.TIDE_SLOW_LAMP
	return step_seconds() * slow


func _burning_lamp_lights(_s, p: Vector2i) -> bool:
	for l in _burning:
		if Vector2(l["pos"]).distance_to(Vector2(p)) <= l["light"]:
			return true
	return false


## Tile p joins the Bloom: it changes under foot, a building on it is overgrown, and its neighbours are queued.
func _grow(s, p: Vector2i) -> void:
	grown[p] = true
	rev += 1
	_convert(s, p)
	if s.town.building_at.has(p) and s.town.built_type(p) not in ["camp", "firebreak"]:
		hit[p] = 0.0
		s.town.road_rev += 1  # the nets are counted again without it
	_spread_from(s, p)


func _spread_from(s, p: Vector2i) -> void:
	for d in SIDES:
		var n: Vector2i = p + d
		if s.world.in_bounds(n) and not front.has(n) and _state(s, n) != 2:
			front[n] = time + cost(s, n)


## What the ground under the Bloom becomes: Bloom ground, unless it keeps its own (ore, water) or something stands on it.
func _convert(s, p: Vector2i) -> void:
	if s.world.tile_at(p) in Data.TIDE_KEEPS or s.world.roads.has(p) or s.town.building_at.has(p):
		return
	s.world.fields.erase(p)
	s.world.flax_fields.erase(p)
	s.world.set_tile(p, Data.TILE_BLOOM_TIDE)
	s.pathing.update_cell(p)


## Count overgrown buildings: burnt clear they work again, held ones wait, the rest are lost after Data.OVERGROWN_LOST_SECONDS.
func _overgrown(s, delta: float) -> void:
	for p in hit.keys():
		if not s.town.building_at.has(p):
			hit.erase(p)
			if grown.has(p):
				_convert(s, p)  # demolished by hand: the ground under it is Bloom now
		elif not grown.has(p):
			hit.erase(p)
			s.town.road_rev += 1
		elif not is_held_at(s, p) and not s.seasons.keeps_buildings():
			hit[p] += delta
			if hit[p] >= Data.OVERGROWN_LOST_SECONDS:
				_lose(s, p)


## True when an Arc Lamp's light or a burning Scorcher's reach covers tile p, so an overgrown building there is not lost.
func is_held_at(_s, p: Vector2i) -> bool:
	if _lit_by_arc(p):
		return true
	for f in _fires:
		if Vector2(f).distance_to(Vector2(p)) <= Data.SCORCH_REACH:
			return true
	return false


func _lose(s, p: Vector2i) -> void:
	var name: String = Data.BUILDINGS[s.town.built_type(p)]["name"]
	s.lose_building(s.town.building_at[p])
	hit.erase(p)
	lost += 1
	rev += 1
	_convert(s, p)
	said.emit(Data.OVERGROWN_LOST_LINE % name)


# --- The Scorcher --------------------------------------------------------------------------------------------------


## The Bloom ground a Scorcher at b would burn next: the nearest tile in reach, else (-1, -1).
func scorch_target(b: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	var reach := int(Data.SCORCH_REACH)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var p: Vector2i = b["pos"] + Vector2i(dx, dy)
			if not grown.has(p):
				continue
			var d := Vector2(p).distance_to(Vector2(b["pos"]))
			if d <= Data.SCORCH_REACH and (d < best_d or (d == best_d and p.x + p.y * 4096 < best.x + best.y * 4096)):
				best = p
				best_d = d
	return best


## What a Scorcher does this tick: with power, Coal and Bloom ground in reach it burns, and each Data.SCORCH_SECONDS clears a tile.
## `b["burn"]` is seconds left on the Coal it was given, `b["progress"]` seconds spent on the tile in hand.
func tick_scorcher(s, b: Dictionary, def: Dictionary, delta: float) -> void:
	var fuel: int = b["inbuf"].get("coal", 0)
	if not s.town.is_powered(b["pos"]):
		b["status"] = Data.SCORCHER_NO_POWER
		b["alert"] = "No power"
		return
	if scorch_target(b).x < 0:
		b["status"] = Data.SCORCHER_NOTHING
		b["progress"] = 0.0
		return
	var speed: float = s.livewire.speed_of(b)
	if b["burn"] <= 0.0:
		if fuel < 1:
			b["status"] = Data.SCORCHER_COLD
			b["alert"] = "Needs Coal"
			return
		b["inbuf"]["coal"] = fuel - 1
		s.economy.note("coal", -1, b["type"])
		b["burn"] = float(def["burn"])
	b["burn"] = maxf(b["burn"] - delta * speed, 0.0)
	b["progress"] += delta * speed
	b["status"] = Data.SCORCHER_BURNING % [lost_tiles(b), b["inbuf"].get("coal", 0)]
	if b["progress"] >= Data.SCORCH_SECONDS:
		b["progress"] = 0.0
		var p := scorch_target(b)
		if p.x >= 0:
			clear(s, p)
			b["trips"] = b["trips"] + 1  # the tiles it has cleared: shown on its card


func lost_tiles(b: Dictionary) -> int:
	return b["trips"]


## Burn tile p clear: it is burnt ground now, never to be taken again, and a building on it works again.
func clear(s, p: Vector2i) -> void:
	grown.erase(p)
	burnt[p] = true
	front.erase(p)
	rev += 1
	if s.world.tile_at(p) == Data.TILE_BLOOM_TIDE:
		s.world.set_tile(p, "grass")
		s.pathing.update_cell(p)
	if hit.has(p):
		hit.erase(p)
		s.town.road_rev += 1


# --- Tide Watch ----------------------------------------------------------------------------------------------------


## Work out when the front reaches each building it has not reached (as the ground and the lights stand now), and warn once of each
## that is close. It runs at most every Data.TIDE_ETA_SECONDS, and only when something changed or a while has passed.
func _watch(s, delta: float) -> void:
	_eta_clock += delta
	if _eta_clock < Data.TIDE_ETA_SECONDS or (_eta_rev == rev + s.town.road_rev and _eta_clock < 15.0):
		return
	_eta_clock = 0.0
	_eta_rev = rev + s.town.road_rev
	project(s)
	for p in eta:
		if eta[p] - time <= Data.TIDE_WARN_SECONDS and not _told.has(p) and s.town.building_at.has(p):
			_told[p] = true
			var name: String = Data.BUILDINGS[s.town.built_type(p)]["name"]
			said.emit(Data.TIDE_REACHES_LINE % [name, duration(eta[p] - time)])


## Fill `eta` with the tide time each unreached building's tile joins the Bloom, running the spread forward from the front.
func project(s) -> void:
	eta = {}
	var targets := {}
	for b in s.town.buildings:
		if not hit.has(b["pos"]) and not grown.has(b["pos"]) and b["type"] not in ["camp", "firebreak"]:
			targets[b["pos"]] = true
	var heap: Array = []  # [tide time, tile], the soonest on top
	var due: Dictionary = {}
	for p in front:
		_push(heap, [front[p], p])
		due[p] = front[p]
	var done := {}
	while not heap.is_empty() and not targets.is_empty():
		var top: Array = _pop(heap)
		var best: Vector2i = top[1]
		var best_t: float = top[0]
		if best_t - time > Data.TIDE_ETA_HORIZON:
			break
		if done.has(best) or grown.has(best) or burnt.has(best) or _in_ring(s, best):
			continue
		done[best] = true
		var at := maxf(best_t, time)
		if targets.has(best):
			eta[best] = at
			targets.erase(best)
		for d in SIDES:
			var n: Vector2i = best + d
			if (
				s.world.in_bounds(n)
				and not done.has(n)
				and not is_bloom(s, n)
				and not burnt.has(n)
				and not _lit_by_arc(n)
			):
				var t := at + cost(s, n)
				if not due.has(n) or t < due[n]:
					due[n] = t
					_push(heap, [t, n])


static func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var parent := floori((i - 1) / 2.0)
		if heap[parent][0] <= heap[i][0]:
			break
		var tmp = heap[parent]
		heap[parent] = heap[i]
		heap[i] = tmp
		i = parent


static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		while true:
			var l := 2 * i + 1
			var r := l + 1
			var m := i
			if l < heap.size() and heap[l][0] < heap[m][0]:
				m = l
			if r < heap.size() and heap[r][0] < heap[m][0]:
				m = r
			if m == i:
				break
			var tmp = heap[m]
			heap[m] = heap[i]
			heap[i] = tmp
			i = m
	return top


## "4 min", "50 s": a duration in words.
static func duration(seconds: float) -> String:
	var n := maxi(roundi(seconds), 1)
	return "%d min" % ceili(float(n) / 60.0) if n >= 90 else "%d s" % n


## What a building's card says about the tide: overgrown, or (with Tide Watch) when the Bloom reaches it. "" when it has nothing to say.
func note(s, b: Dictionary) -> String:
	if hit.has(b["pos"]):
		if is_held_at(s, b["pos"]):
			return Data.OVERGROWN_HELD
		return Data.OVERGROWN_STATUS % duration(Data.OVERGROWN_LOST_SECONDS - hit[b["pos"]])
	if s.tech_tree.researched.has("tide_watch") and eta.has(b["pos"]):
		return Data.TIDE_REACHES_NOTE % duration(eta[b["pos"]] - time)
	return ""


## The line Tide Watch adds to an engine's, a Scorcher's or an Arc Lamp's card: how fast the front moves now.
func pace_note(s, b: Dictionary) -> String:
	var kind: String = Data.BUILDINGS[b["type"]]["kind"]
	if begun and s.tech_tree.researched.has("tide_watch") and kind in ["power", "scorcher", "arc_lamp"]:
		return pace_line()
	return ""


## The nearest Bloom ground to the Hearth, in tiles, or -1 when there is none yet.
func front_distance(s) -> int:
	var best := -1
	for p in grown:
		var d := ceili(Vector2(p).distance_to(Vector2(s.world.camp_pos)))
		if best < 0 or d < best:
			best = d
	return best


# --- Machines ------------------------------------------------------------------------------------------------------


## True when machine b (an Arc Lamp, a Scorcher) draws power now: a lamp always, a Scorcher while it could burn.
func draws(b: Dictionary) -> bool:
	var kind: String = Data.BUILDINGS[b["type"]]["kind"]
	if hit.has(b["pos"]):
		return false
	if kind == "scorcher":
		return scorch_target(b).x >= 0 and (b["burn"] > 0.0 or b["inbuf"].get("coal", 0) > 0)
	return true


## The extra share a Field at `tile` pays on burnt ground, once Living Ground is learned.
func ash_share(s, tile: Vector2i) -> float:
	if burnt.has(tile) and s.tech_tree.researched.has("living_ground"):
		return Data.ASH_FIELD_BONUS
	return 0.0


# --- Save ----------------------------------------------------------------------------------------------------------


func to_dict() -> Dictionary:
	var f: Array = []
	for p in front:
		f.append([p.x, p.y, front[p]])
	var h: Array = []
	for p in hit:
		h.append([p.x, p.y, hit[p]])
	return {
		"begun": begun,
		"time": time,
		"grown": Codec.vec_keys(grown),
		"burnt": Codec.vec_keys(burnt),
		"front": f,
		"hit": h,
		"lost": lost,
		"woke_at": woke_at,
		"drawn": drawn,
		"told": Codec.vec_keys(_told),
	}


func from_dict(d: Dictionary) -> void:
	begun = bool(d.get("begun", false))
	time = float(d.get("time", 0.0))
	grown = Codec.to_vec_set(d.get("grown", []))
	burnt = Codec.to_vec_set(d.get("burnt", []))
	front = {}
	for e in d.get("front", []):
		front[Vector2i(int(e[0]), int(e[1]))] = float(e[2])
	hit = {}
	for e in d.get("hit", []):
		hit[Vector2i(int(e[0]), int(e[1]))] = float(e[2])
	lost = int(d.get("lost", 0))
	woke_at = float(d.get("woke_at", -1.0))
	drawn = int(d.get("drawn", 0))
	_pace_clock = 0.0
	_told = Codec.to_vec_set(d.get("told", []))
	eta = {}
	_eta_rev = -1
	_eta_clock = Data.TIDE_ETA_SECONDS
	rev += 1
