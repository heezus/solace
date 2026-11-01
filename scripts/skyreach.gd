extends RefCounted
## The Skyreach block (design-system/32-skyreach.md): era 6, from the second telling on. Survey the sky: a Signal Tower surveys the
## sky sector it stands in (the map is cut into 6 sectors round the Hearth), and a surveyed sector shows its landfalls
## Data.SKYREACH["warn"] seconds before they fall. A landfall is a seed-fall that starts a small Bloom patch the tide then spreads.
## They come in waves, the same on a map every time (seeded from the map), with no warning on a sector nobody surveys.
## The Skyreach itself is a Skyreach Tower built on the site the first Signal Tower finds: three stages, each one delivery of goods
## (haulers bring it, as they bring a home its goods) and then a building time, shorter with the Lumen's help. The third stage ends
## the era: the endings card opens (scripts/game_menu.gd). Sim owns one, reached as `sim.skyreach`; before the era begins every
## function here does nothing, so a first telling never feels it. Static helpers take the building dictionary.
## Signal: said(message) is a line for the event log.

signal said(message: String)

const Data = preload("res://scripts/data.gd")
const Roads = preload("res://scripts/roads.gd")

const TOWER := "skyreach_tower"
const SIGNAL := "signal_tower"

var site := Vector2i(-1, -1)  # where the Skyreach goes, once a Signal Tower has found it
var begun_at := -1.0  # the game clock (Seasons.time) when the era began, -1 before
var falls: Array = []  # every landfall planned: {"pos": Vector2i, "at": seconds since begun_at, "sector": n, "fell": bool, "wave": n}
var waves_planned := 0
var surveyed: Dictionary = {}  # sector -> true, from the Signal Towers standing now (read, never saved)
var _hold_rev := -1  # the road revision the held ground below was worked out at
var _hold: Dictionary = {}  # tile -> true: the Skyreach's ground and the road that links it to a depot, which the Bloom never takes
var _told_sectors: Dictionary = {}  # sector -> true once the log said it was surveyed
var _told_warn: Dictionary = {}  # index into falls -> true once the log warned of it
var _clock := 0.0

# --- The sky -----------------------------------------------------------------------------------------------------------


## The sector of the sky tile `p` lies in, round `hearth`: 0 east, then clockwise on the map (screen) in steps of 60 degrees, each
## sector centred on the direction it is named for.
static func sector_of(hearth: Vector2i, p: Vector2i) -> int:
	var n: int = Data.SKYREACH["sectors"]
	var angle := fposmod(rad_to_deg(atan2(float(p.y - hearth.y), float(p.x - hearth.x))) + 180.0 / n, 360.0)
	return clampi(floori(angle / (360.0 / n)), 0, n - 1)


## The name of a sector, "north-east".
static func sector_name(sector: int) -> String:
	return Data.SKYREACH["names"][sector]


## True once the era has begun in this run.
func is_on(s) -> bool:
	return s.story.has_event(Data.SKYREACH["begun"])


## True once the Skyreach stands.
func is_done(s) -> bool:
	return s.story.has_event(Data.SKYREACH["done"])


## The seconds since the era began.
func now(s) -> float:
	return s.seasons.time - begun_at if begun_at >= 0.0 else 0.0


## Where the Skyreach goes ((-1, -1) before a Signal Tower has found it). Buildings.placement_error asks.
func site_pos() -> Vector2i:
	return site


## True when the Lumen are helping: the lean is one that trades or stands with the Kith.
func helped(s) -> bool:
	return s.starfall.lean in Data.SKYREACH["help_leans"]


## The Signal Towers standing now (not lost to the Bloom).
func towers(s) -> Array:
	return s.town.buildings.filter(func(b): return b["type"] == SIGNAL and not s.tide.is_overgrown(b))


## The sectors surveyed now, by the Signal Towers.
func survey(s) -> Dictionary:
	var out := {}
	for b in towers(s):
		out[sector_of(s.world.camp_pos, b["pos"])] = true
	return out


# --- Each tick ---------------------------------------------------------------------------------------------------------


func tick(s, delta: float) -> void:
	if not is_on(s):
		return
	if begun_at < 0.0:
		begun_at = s.seasons.time
		_share(s)
	_clock += delta
	if _clock >= 1.0:
		_clock = 0.0
		_look(s)
	if is_done(s):
		return
	_wave(s)
	for b in s.town.buildings:
		if b["type"] == TOWER:
			_build(s, b, delta)


## When the sky opens the stores are topped up to `Data.SKYREACH["floor"]` wherever they are lower: with Wire and Steel at nothing,
## the first cut to the power net could never be mended and no Scorcher bought. The Lumen share what they salvaged, or scavengers
## bring what they found when the Lumen are enemies.
func _share(s) -> void:
	var gave := false
	for id in Data.SKYREACH["floor"]:
		var lack: int = Data.SKYREACH["floor"][id] - s.economy.inv.get(id, 0)
		if lack > 0:
			s.economy.add(id, lack)
			s.economy.note(id, lack, Data.FLOW_HAND_SOURCE)
			gave = true
	if gave:
		said.emit(Data.SKYREACH["scavenged"] if s.starfall.lean == "enemies" else Data.SKYREACH["shared"])


## Read the Signal Towers once a second: say which sectors are newly surveyed, find the site, warn of landfalls.
func _look(s) -> void:
	surveyed = survey(s)
	for sector in surveyed:
		if not _told_sectors.has(sector):
			_told_sectors[sector] = true
			said.emit(Data.SKYREACH["surveyed"] % [sector_name(sector), int(Data.SKYREACH["warn"])])
	if site.x < 0 and not surveyed.is_empty():
		var first: Dictionary = towers(s)[0]
		_find_site(s, sector_of(s.world.camp_pos, first["pos"]))
	for i in falls.size():
		var f: Dictionary = falls[i]
		if not f["fell"] and surveyed.has(f["sector"]) and not _told_warn.has(i):
			_told_warn[i] = true
			said.emit(Data.SKYREACH["warned"] % [sector_name(f["sector"]), maxi(roundi(f["at"] - now(s)), 0)])


## Choose the site: of the open tiles 8 to 20 tiles out in `sector`, the one furthest from the Bloom (up to `site_clear` tiles),
## nearer the Hearth on a tie, so a road can always reach it. With none open in the sector, the same over every sector.
func _find_site(s, sector: int) -> void:
	var camp: Vector2i = s.world.camp_pos
	var best := Vector2i(-1, -1)
	var walk := _walkable(s)
	for only in [true, false]:
		var best_score := -INF
		for r in range(Data.SKYREACH["site_min"], Data.SKYREACH["site_max"] + 1):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var p := camp + Vector2i(dx, dy)
					if (
						maxi(absi(dx), absi(dy)) != r
						or (only and sector_of(camp, p) != sector)
						or not walk.has(p)
						or not _open(s, p)
						or not _approach(s, p, walk)
					):
						continue
					var score := clear_of_bloom(s, p) * 10.0 - r
					if score > best_score:
						best = p
						best_score = score
		if best.x >= 0:
			break
	if best.x < 0:
		return
	site = best
	s.fog.reveal(site, Data.SKYREACH["site_sight"])
	said.emit(Data.SKYREACH["site_found"] % sector_name(sector_of(camp, site)))


## True on the Skyreach's own ground and on the one road that links it to a depot: the Bloom never takes it ("the tower's ground holds"),
## so no player is ever locked out of the era by the tide. Worked out again when the roads or buildings change.
func holds(s, p: Vector2i) -> bool:
	if site.x < 0:
		return false
	if _hold_rev != s.town.road_rev:
		_hold_rev = s.town.road_rev
		_hold = _held_ground(s)
	return _hold.has(p)


## The tower's tile and the shortest run of road tiles from its sides to a tile beside a depot (or just the road tiles touching the
## tower while no road links it yet).
func _held_ground(s) -> Dictionary:
	var out := {}
	if not s.town.building_at.has(site) or s.town.built_type(site) != TOWER:
		return out
	out[site] = true
	var depots: Array = Roads.depots(s)
	var from := {}
	var todo: Array = []
	for n in s.world.NEIGHBORS:
		var q: Vector2i = site + n
		if s.world.roads.has(q):
			out[q] = true
			from[q] = site
			todo.append(q)
	while not todo.is_empty():
		var q: Vector2i = todo.pop_front()
		var done := false
		for d in depots:
			if absi(d.x - q.x) + absi(d.y - q.y) <= 1:
				done = true
		if done:
			while q != site:
				out[q] = true
				q = from[q]
			return out
		for n in s.world.NEIGHBORS:
			var r: Vector2i = q + n
			if s.world.roads.has(r) and not from.has(r):
				from[r] = q
				todo.append(r)
	return out


## The tiles a road could reach from the town's depots without a long detour (Data.SKYREACH["site_walk"] steps at most): from the roads
## that reach a depot and the ground beside one, over roads and open ground a road goes on. A site beyond a river or the Bloom, round
## a long way, or boxed in by fields and buildings would be one no road could reach.
func _walkable(s) -> Dictionary:
	var reach := {}
	var todo: Array = []
	var linked := {}
	for depot in Roads.depots(s):
		for id in Roads.depot_nets(s, depot):
			linked[id] = true
		for n in [Vector2i.ZERO] + s.world.NEIGHBORS:
			if not reach.has(depot + n):
				reach[depot + n] = 0
				todo.append(depot + n)
	for q in s.town.road_net["net"]:
		if linked.has(s.town.road_net["net"][q]) and not reach.has(q):
			reach[q] = 0
			todo.append(q)
	var cap: int = Data.SKYREACH["site_walk"]
	while not todo.is_empty():
		var p: Vector2i = todo.pop_front()
		if reach[p] >= cap:
			continue
		for n in s.world.NEIGHBORS:
			var q: Vector2i = p + n
			if s.world.in_bounds(q) and not reach.has(q) and not s.pathing.astar.is_point_solid(q) and _roadable(s, q):
				reach[q] = reach[p] + 1
				todo.append(q)
	return reach


## True where a road runs or could be laid: grass, Forest, Rocks and ruins that nothing stands on, not a field.
func _roadable(s, p: Vector2i) -> bool:
	return (
		s.world.roads.has(p)
		or (not s.town.building_at.has(p) and s.world.tile_at(p) in ["grass", "tree", "rock", "ruins"])
	)


## True when a road could start beside `p`: one side lies on the tiles a road reaches.
func _approach(s, p: Vector2i, walk: Dictionary) -> bool:
	for n in s.world.NEIGHBORS:
		var q: Vector2i = p + n
		if s.world.in_bounds(q) and walk.has(q) and not s.tide.is_bloom(s, q):
			return true
	return false


## How many tiles from `p` the nearest Bloom lies, up to Data.SKYREACH["site_clear"].
func clear_of_bloom(s, p: Vector2i) -> int:
	var far: int = Data.SKYREACH["site_clear"]
	for r in range(1, far):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if (
					maxi(absi(dx), absi(dy)) == r
					and s.world.in_bounds(p + Vector2i(dx, dy))
					and s.tide.is_bloom(s, p + Vector2i(dx, dy))
				):
					return r
	return far


## True when `p` is open ground nothing stands on and the Bloom has not taken.
func _open(s, p: Vector2i) -> bool:
	return (
		s.world.in_bounds(p)
		and s.world.tile_at(p) == "grass"
		and not s.world.roads.has(p)
		and not s.town.building_at.has(p)
		and not s.tide.is_bloom(s, p)
	)


# --- Landfalls ---------------------------------------------------------------------------------------------------------


## When wave `k` falls, in seconds since the era began.
static func wave_time(k: int) -> float:
	return float(Data.SKYREACH["first_wave"]) + k * float(Data.SKYREACH["wave_every"])


## How many falls wave `k` carries: 2 at first, one more for every few waves, at most 4.
static func wave_size(k: int) -> int:
	var more: int = floori(float(k) / Data.SKYREACH["wave_more_every"])
	return clampi(Data.SKYREACH["wave_min"] + more, Data.SKYREACH["wave_min"], Data.SKYREACH["wave_max"])


## Plan each wave once it is within the warning's reach, and let every fall that is due fall.
func _wave(s) -> void:
	var t := now(s)
	while wave_time(waves_planned) - Data.SKYREACH["warn"] <= t:
		_plan(s, waves_planned)
		waves_planned += 1
	for f in falls:
		if not f["fell"] and f["at"] <= t:
			f["fell"] = true
			s.tide.land(s, f["pos"], Data.SKYREACH["patch_radius"])
			if surveyed.has(f["sector"]):
				said.emit(Data.SKYREACH["fell"] % sector_name(f["sector"]))
			else:
				said.emit(Data.SKYREACH["fell_dark"])


## Plan wave `k`: its falls land on grass, tree or gravel ground far from the Hearth and from each other, picked by a generator
## seeded from the map and the wave, so a map always falls the same way.
func _plan(s, k: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([s.world.map_seed, k, 6])
	var camp: Vector2i = s.world.camp_pos
	var chosen: Array = []
	var want := wave_size(k)
	var tries := 0
	while chosen.size() < want and tries < 200:
		tries += 1
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(Data.SKYREACH["far_min"], Data.SKYREACH["far_max"])
		var p := camp + Vector2i(roundi(cos(angle) * dist), roundi(sin(angle) * dist))
		if not s.world.in_bounds(p) or s.world.tile_at(p) not in ["grass", "tree", "gravel", "berry", "grain", "flax"]:
			continue
		if (
			s.tide.is_bloom(s, p)
			or chosen.any(func(q): return Vector2(q).distance_to(Vector2(p)) < Data.SKYREACH["apart"])
		):
			continue
		chosen.append(p)
	for p in chosen:
		falls.append({"pos": p, "at": wave_time(k), "sector": sector_of(camp, p), "fell": false, "wave": k})


## The landfalls a surveyed sector shows now: those not yet fallen whose sector a Signal Tower stands in.
func marked(s) -> Array:
	var out: Array = []
	for f in falls:
		if not f["fell"] and surveyed.has(f["sector"]):
			out.append({"pos": f["pos"], "eta": maxf(f["at"] - now(s), 0.0), "sector": f["sector"]})
	return out


# --- The Skyreach ------------------------------------------------------------------------------------------------------


## The stage `b` (a Skyreach Tower) is on: 0 to 3 stages stand.
static func stage_of(b: Dictionary) -> int:
	return clampi(int(b.get("stage", 0)), 0, 3)


## What the tower's next stage costs, {} once all three stand.
static func next_cost(b: Dictionary) -> Dictionary:
	var stage := stage_of(b)
	return {} if stage >= 3 else Data.SKYREACH["stage_cost"][stage]


## What haulers bring the tower: the next stage's goods, while it is waiting for them.
static func wanted(b: Dictionary) -> Dictionary:
	return {} if float(b.get("clock", -1.0)) >= 0.0 else next_cost(b)


## Seconds a stage takes to build now.
func stage_seconds(s) -> float:
	return float(Data.SKYREACH["stage_seconds"]) * (Data.SKYREACH["help_speed"] if helped(s) else 1.0)


## One tick of a Skyreach Tower: take a delivery that covers the stage, then count the stage down.
func _build(s, b: Dictionary, delta: float) -> void:
	var stage := stage_of(b)
	if stage >= 3:
		return
	var clock: float = float(b.get("clock", -1.0))
	if clock < 0.0:
		var cost := next_cost(b)
		for id in cost:
			if b["inbuf"].get(id, 0) < cost[id]:
				return
		for id in cost:
			b["inbuf"][id] -= cost[id]
		b["clock"] = 0.0
		said.emit(Data.SKYREACH["stage_started"] % (stage + 1))
		return
	b["clock"] = clock + delta
	if b["clock"] >= stage_seconds(s):
		b["stage"] = stage + 1
		b["clock"] = -1.0
		said.emit(Data.SKYREACH["stage_done"] % (stage + 1))
		if stage + 1 >= 3:
			said.emit(Data.SKYREACH["ready"])
			s.story.record(Data.SKYREACH["done"])


## The line the tower's card shows: what stage it is on and what it waits for.
static func note(b: Dictionary) -> String:
	var stage := stage_of(b)
	if stage >= 3:
		return Data.SKYREACH["ready"]
	var clock: float = float(b.get("clock", -1.0))
	if clock >= 0.0:
		return Data.SKYREACH["building"] % [stage + 1, maxi(ceili(float(Data.SKYREACH["stage_seconds"]) - clock), 0)]
	var short := []
	var cost := next_cost(b)
	for id in cost:
		var missing: int = cost[id] - int(b["inbuf"].get(id, 0))
		if missing > 0:
			short.append("%d %s" % [missing, Data.ITEMS[id]["name"]])
	return Data.SKYREACH["needs"] % [stage + 1, ", ".join(short) if not short.is_empty() else "nothing more"]


## What a building's card says of the sky: the Skyreach's stage and what it waits for, or the sector a Signal Tower surveys.
func card_note(s, b: Dictionary) -> String:
	if b["type"] == TOWER:
		return note(b)
	if b["type"] == SIGNAL:
		var sector := sector_name(sector_of(s.world.camp_pos, b["pos"]))
		return ("Surveying the %s" if not s.tide.is_overgrown(b) else "Lost to the Bloom (the %s is dark)") % sector
	return ""


## True for a goal of the era that is met now (Story asks).
func goal(s, id: String) -> bool:
	var stage := 0
	for b in s.town.buildings:
		if b["type"] == TOWER:
			stage = maxi(stage, stage_of(b))
	match id:
		"survey_three":
			return survey(s).size() >= 3
		"stage_1":
			return stage >= 1
		"stage_2":
			return stage >= 2
		"stage_3":
			return stage >= 3
	return false


# --- Save --------------------------------------------------------------------------------------------------------------


func to_dict() -> Dictionary:
	var f: Array = []
	for fall in falls:
		f.append([fall["pos"].x, fall["pos"].y, fall["at"], fall["fell"], fall["wave"], fall["sector"]])
	return {
		"site": [site.x, site.y],
		"begun_at": begun_at,
		"waves": waves_planned,
		"falls": f,
		"told": _told_sectors.keys(),
	}


func from_dict(d: Dictionary) -> void:
	var at: Array = d.get("site", [-1, -1])
	site = Vector2i(int(at[0]), int(at[1]))
	begun_at = float(d.get("begun_at", -1.0))
	waves_planned = int(d.get("waves", 0))
	falls = []
	_told_warn = {}
	for row in d.get("falls", []):
		falls.append(
			{
				"pos": Vector2i(int(row[0]), int(row[1])),
				"at": float(row[2]),
				"fell": bool(row[3]),
				"wave": int(row[4]),
				"sector": int(row[5])
			}
		)
	_told_sectors = {}
	for sector in d.get("told", []):
		_told_sectors[int(sector)] = true
	surveyed = {}
