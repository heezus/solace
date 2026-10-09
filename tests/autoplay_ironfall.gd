extends "res://tests/autoplay_bronze.gd"
## The headless player for Ironfall (design-system/19-ironfall.md): coal and iron, Teardown and steam, from the start of the era
## (the Starfall over) to the Livewire gate. Like the bots before it, it sets the research goal (the gate) and builds what the
## techs and the next building cost: roads south through the fog to the Coal Seams and the Iron Hills, Coal and Iron Mines,
## Bloomeries, a Boiler with Forges round it, Storehouses at the mines (the generic bot), a Steam Shed and Rail, and it sends
## the Expedition Post to the Wreck for parts and to the Bloom patches for samples. It uses only the public Sim calls a player
## has (place, research, the hold on a tile, the Post's orders) and logs the clock when each Ironfall goal is met.
## play_from(game, max_seconds) returns {"won" (the gate was reached), "seconds" (the clock at the gate, -1 for never), "marks"
## (milestone -> clock), "log"}; tests/tools/pace.gd prints it.

const Expedition = preload("res://scripts/expedition.gd")
const Finds = preload("res://scripts/teardown_finds.gd")

const GATE := "livewire"
## What the hold digs by hand in the new land, on top of the stone age's goods (the generic bot's RAW_TILE).
const RAW_NEW := {"coal": "coal_seam", "iron_ore": "iron_hills"}
const COAL_MINES := 3  # the most Coal Mines (a seam holds about 500, so three seams are three mines at most)
const IRON_MINES := 5
const BLOOMERIES := 4
const FORGES := 4
const ORE_PER_MINE := 300.0  # one more Iron Mine for every this much Iron Ore still short
const IRON_PER_BLOOMERY := 80.0
const STEEL_PER_FORGE := 25.0
const RAIL_PER_DECISION := 6
const BOILERS := 3  # the most Boilers: more only when the Forges find no ground beside the first
const STEAM_SHEDS := 1  # the start already has a Shed; more only cost the iron the gate wants
const COAL_SPARE := 150  # coal the stockpile keeps beyond the gate's needs before the Coal Mines rest
const WAIT_FOR_ROOM := 90.0  # seconds a building may stay affordable and unplaced before the plan goes on without it
const WORKSHOPS_BIG := 8  # the most of one kind of workshop the bot builds in the era (the stone age's cap is 4)
const POSTS := 2  # Expedition Posts: a second sends the second party for the Bloom samples
## The buildings the minute's trace reports on.
const TRACED := [
	"forge", "bloomery", "boiler", "coal_mine", "mine", "kiln", "charcoal_pit", "smelter", "crucible", "twine_post"
]

var marks := {}  # milestone -> clock
var gate_at := -1.0
var _room_since := {}  # building type -> the clock when it was first affordable and unplaced
var _goals_seen := {}
var _steam_cart_at := -1.0
var _tile_memo := {}
var _tile_size := -1


## Play `game` (an Ironfall start) from here to the Livewire gate, or until `max_seconds` pass.
func play_from(game: Sim, max_seconds: float) -> Dictionary:
	goal_tech = GATE
	attach(game)
	for tech in s.tech_tree.researched:
		known[tech] = true
	_note_goals()
	_drop_stranded_posts()
	while clock < max_seconds and gate_at < 0.0:
		step(true)
	return {"won": gate_at >= 0.0, "seconds": gate_at, "marks": marks, "log": lines}


## A Storehouse on a road of its own, cut off from the Hearth's, holds a share of the haulers (they are dealt out over the
## depots that have buildings to serve) that can never reach the metal works. A player who sees a dozen carts idling out
## there tears the post down, and so does the bot: its buildings fall back on the Hearth.
func _drop_stranded_posts() -> void:
	var home: Array = Roads.depot_nets(s, s.world.camp_pos)
	var gone: Array = []
	for b in s.town.buildings:
		if b["type"] != "storehouse":
			continue
		var shared := false
		for id in Roads.depot_nets(s, b["pos"]):
			if id in home:
				shared = true
		if not shared:
			gone.append(b["pos"])
	for at in gone:
		s.demolish(at)
		lines.append("%5d s    - stranded Storehouse at %s torn down" % [int(clock), at])


## The research goal, in the order a player would take it: Bloom Sampling first (three trips to the far south and three
## Lessons are the long pole and cost little), then the rest of the metal works before any other tech (the Bloomeries and
## Forges take the brick and iron that the techs would), then the gate.
func _aim() -> void:
	var done: Dictionary = s.tech_tree.researched
	var want := GATE
	if not done.has("bloom_sampling"):
		want = "bloom_sampling"
	elif _works_due():
		want = ""
	if want == "":
		if s.tech_tree.goal != "":
			s.tech_tree.clear()
	elif s.tech_tree.goal != want and not done.has(want):
		s.tech_tree.set_goal(want)


## True while a metal works the plan wants is still to build (and its tech is in): research waits for it.
func _works_due() -> bool:
	return not _next_price().is_empty()


## True when `type` could be paid for but has found no place for WAIT_FOR_ROOM seconds: the plan goes on without it.
func _no_room(type: String) -> bool:
	if not s.economy.can_afford(s.town.price(type)):
		return false
	var key := "%s%d" % [type, _count(type)]  # a new building starts the wait afresh
	if not _room_since.has(key):
		_room_since[key] = clock
	return clock - _room_since[key] > WAIT_FOR_ROOM


## False for a building that cannot go up yet for want of a place (no seam in sight, no hills named): not worth waiting for.
func _site_open(type: String) -> bool:
	match type:
		"coal_mine":
			return not _free_seam_tiles(true).is_empty()
		"mine":
			return s.tech_tree.researched.has("ironstone") and _seen("iron_hills")
		"forge":
			return _count("boiler") > 0
	return true


func _log_research() -> void:
	super._log_research()
	_note_goals()


## Log the clock when each Ironfall goal is met, and the first Steam Cart, and keep the milestones.
func _note_goals() -> void:
	for g in Data.GOALS_ERA4:
		if s.story.goals_done.has(g["id"]) and not _goals_seen.has(g["id"]):
			_goals_seen[g["id"]] = true
			marks[g["id"]] = clock
			lines.append("%5.0f s  == goal: %s ==" % [clock, g["id"]])
	for id in Data.LESSON_ORDER:
		if s.teardown.knows(id) and not marks.has("lesson_" + id):
			marks["lesson_" + id] = clock
	for n in range(1, 4):
		if s.teardown.sampled.size() >= n and not marks.has("sample_%d" % n):
			marks["sample_%d" % n] = clock
	for n in [50, 100]:
		if _inv("steel") >= n and not marks.has("steel_%d" % n):
			marks["steel_%d" % n] = clock
	if _steam_cart_at < 0.0:
		for k in s.people.kith:
			if k.get("cart_kind", "") == "steam":
				_steam_cart_at = clock
				marks["steam_cart"] = clock
				lines.append("%5.0f s  == a Steam Cart rolls ==" % clock)
				break
	if gate_at < 0.0 and s.tech_tree.researched.has(GATE):
		gate_at = clock
		marks["gate"] = clock


## The minute's line, and what the metal works are doing: how many of each building stand and what they say they wait for.
func _trace() -> void:
	super._trace()
	var seen := {}
	for b in s.town.buildings:
		if b["type"] not in TRACED:
			continue
		var say: String = String(b["status"]).substr(0, 22)
		var key: String = "%s:%s" % [b["type"], say]
		seen[key] = seen.get(key, 0) + 1
	var haul := 0
	var busy := 0
	for k in s.people.kith:
		if k["job"] == "haul":
			haul += 1
			busy += 0 if k["task"].is_empty() else 1
	var rates := {}
	for id in ["iron_ore", "coal", "iron", "steel", "brick"]:
		var by: Dictionary = s.economy.flows.parts(id)
		var per := {}
		for src in by:
			per[src] = snappedf(by[src] * 60.0, 0.1)
		rates[id] = per
	lines.append("        per minute %s" % [rates])
	lines.append(
		(
			"        works %s | haulers %d/%d busy | stock iron %d ore %d coal %d steel %d brick %d rope %d"
			% [
				seen,
				busy,
				haul,
				_inv("iron"),
				_inv("iron_ore"),
				_inv("coal"),
				_inv("steel"),
				_inv("brick"),
				_inv("rope")
			]
		)
	)


func _inv(id: String) -> int:
	return s.economy.inv.get(id, 0)


# --- What we're short of -----------------------------------------------------


## The gate and the buildings the bot wants: the metal for the gate, and the price of the next of each building.
func _goal_wants(want: Dictionary) -> void:
	var steel_left := _steel_left()
	if steel_left > 0:
		want["steel"] = want.get("steel", 0) + _steel_cost()
		want["iron"] = want.get("iron", 0) + steel_left * 2
		want["coal"] = want.get("coal", 0) + steel_left
	for type in _building_wants():
		_want(want, s.town.price(type), 1)


## Steel the gate still lacks.
func _steel_left() -> int:
	if s.tech_tree.researched.has(GATE):
		return 0
	return maxi(_steel_cost() - _inv("steel"), 0)


## What the gate costs in Steel now (the Tally Sticks discount applies).
func _steel_cost() -> int:
	return s.tech_tree.cost_of(GATE).get("steel", 0)


## The buildings to pay for next (one of each type that is below its target).
func _building_wants() -> Array:
	var out: Array = []
	for type in ["coal_mine", "mine", "bloomery", "boiler", "forge", "steam_shed", "teardown_bench"]:
		if s.town.unlocked(type) and _count(type) < _target(type):
			out.append(type)
	return out


## What the gate still asks for, by good: the cost of every tech on the way to it that is not researched yet, and the Steel's
## iron and coal (the Boiler's coal and the Bloomery's are left out: the spare covers them).
func _gate_need(id: String) -> int:
	var need := 0
	for tech in Rules.route_to(GATE, s.tech_tree.researched, Rules.visible_techs(s.shard_seen)):
		need += s.tech_tree.cost_of(tech).get(id, 0)
	var steel := _steel_left()
	if id == "iron":
		need += steel * 2
	elif id == "coal":
		need += steel
	elif id == "iron_ore":
		need = _gate_need("iron") * (1 if s.tech_tree.researched.has("blast_furnace") else 2)
	return need


## What of that the stockpile lacks. Never below 0.
func _gate_short(id: String) -> int:
	return maxi(_gate_need(id) - _inv(id), 0)


## How many of `type` the bot wants now.
func _target(type: String) -> int:
	match type:
		"coal_mine":
			if _free_seams().is_empty() and _count("coal_mine") == 0:
				return 0
			return mini(1 + int(_gate_short("coal") / 250.0), COAL_MINES)
		"mine":
			return mini(2 + int(_gate_short("iron_ore") / ORE_PER_MINE), IRON_MINES)
		"bloomery":
			return mini(2 + int(_gate_short("iron") / IRON_PER_BLOOMERY), BLOOMERIES)
		"boiler":
			return 1  # a second one goes up only when the Forges find no room (_place_forge)
		"forge":
			return mini(2 + int(_steel_left() / STEEL_PER_FORGE), FORGES) if _steel_left() > 0 else _count("forge")
		"steam_shed":
			return STEAM_SHEDS if s.world.road_tiers.values().has(Data.RAIL_TIER) else 1
		"teardown_bench":
			return 1
	return 0


## The seams (ids) that still hold coal and have no Coal Mine yet: the pile is shared by a seam's tiles, so one mine to a seam.
func _free_seams() -> Array:
	var mined := {}
	for b in s.town.buildings:
		if b["type"] == "coal_mine" and s.world.seam_of.has(b["pos"]):
			mined[s.world.seam_of[b["pos"]]] = true
	var out: Array = []
	for id in s.world.seam_left:
		if s.world.seam_left[id] > 0 and not mined.has(id):
			out.append(id)
	return out


## The tiles of the seams that are free (see _free_seams), seen or not.
func _free_seam_tiles(seen_only: bool) -> Array:
	var free := _free_seams()
	var out: Array = []
	for p in s.world.seam_of:
		if s.world.seam_of[p] in free and s.world.tile_at(p) == "coal_seam" and (s.fog.is_revealed(p) or not seen_only):
			out.append(p)
	return out


## Coal Mines on a seam that still holds coal (a spent one is torn down by _manage_works).
func _count(type: String) -> int:
	if type != "coal_mine":
		return super._count(type)
	var n := 0
	for b in s.town.buildings:
		if b["type"] == "coal_mine" and not s.world.seam_spent(b["pos"]):
			n += 1
	return n


## A Storehouse by any workshop or hut far from a stockpile, as the stone age's bot does, but not in the south land: haulers are
## dealt to the depots by the order they were born in, and a Storehouse out there can end with none, leaving the mine behind it
## full and unserved. The mines there are joined by road to the Hearth's own network, which has haulers.
func _place_storehouse() -> bool:
	for b in s.town.buildings:
		if not Buildings.needs_worker(b) or b["pos"].y >= s.world.base_height:
			continue
		var depot: Vector2i = s.people.nearest_depot(b["pos"])
		if Vector2(depot).distance_to(Vector2(b["pos"])) > 6.0:
			var at: Vector2i = b["pos"]
			var near := func(p):
				var d := Vector2(p).distance_to(Vector2(at))
				return -d if d <= 4.0 else -INF
			if _place_best("storehouse", near):
				return true
	return false


# --- Clicks and the hold -----------------------------------------------------


## The raw good we're shortest of that can be reached by hand right now (coal and iron ore too).
func _most_short_raw(short: Dictionary) -> String:
	var best := super._most_short_raw(short)
	var ore: int = short.get("iron_ore", 0) + short.get("iron", 0) * 1
	var coal: int = short.get("coal", 0)
	for id in RAW_NEW:
		var n: int = ore if id == "iron_ore" else coal
		if n > 0 and _nearest_tile(RAW_NEW[id], s.world.camp_pos).x >= 0:
			if best == "" or n > short.get(best, 0):
				best = id
	return best


## The tile to hold on next: like the stone age's, with coal and iron ore on the list.
func _pick_tile() -> Vector2i:
	var item := _next_click()
	var room := s.people.kith.size() < s.town.housing()
	if s.economy.food_total() < s.people.kith.size() * 2.0 + (Data.BIRTH_FOOD + 3.0 if room else 2.0):
		item = "berries"
	if item == "":
		item = "stone" if s.economy.inv.get("stone", 0) < s.economy.inv.get("wood", 0) else "wood"
	var tile: String = RAW_NEW[item] if RAW_NEW.has(item) else RAW_TILE[item]
	return _nearest_tile(tile, s.world.camp_pos)


# --- Decisions ---------------------------------------------------------------


func _decide() -> void:
	_aim()
	_flood_reach()
	_post_orders()
	_manage_works()
	if _build_ironfall():
		return
	super._decide()


## Pause what a player would pause: Forges while the next tech still waits for iron (they would eat it all), Coal Mines while
## the stockpile holds the coal the gate needs and more (a seam is finite: a mine left to dig drains it), and Kilns while the
## metal works still to build wait for clay that the Kilns would fire into brick the works already have enough of.
func _manage_works() -> void:
	var reserve := 0
	for tech in s.tech_tree.queue:
		reserve = maxi(reserve, s.tech_tree.cost_of(tech).get("iron", 0))
	var coal_enough: bool = _inv("coal") >= _gate_need("coal") + COAL_SPARE
	var due := _next_price()
	var save_clay: bool = _inv("clay") < due.get("clay", 0) and _inv("brick") >= due.get("brick", 0)
	var spent: Array = []
	for i in s.town.buildings.size():
		var b: Dictionary = s.town.buildings[i]
		var pause: bool = b["paused"]
		match b["type"]:
			"forge":
				pause = reserve > 0 and _inv("iron") < reserve + 10
			"coal_mine":
				pause = coal_enough
				if s.world.seam_spent(b["pos"]):
					spent.append(b["pos"])
			"kiln":
				pause = save_clay or (pause and not due.is_empty() and _inv("clay") < due.get("clay", 0) + 40)
			_:
				continue
		if pause != b["paused"]:
			s.set_paused(i, pause)
	for p in spent:  # a spent seam: tear the mine down and put its Kith to work elsewhere
		s.demolish(p)
		lines.append("%5.0f s    - Coal Mine at %s (the seam is spent)" % [clock, p])


## What the next metal works that is due costs (the first building below its target, the Bloomeries first).
func _next_price() -> Dictionary:
	for type in ["bloomery", "boiler", "forge", "coal_mine", "mine"]:
		if s.town.unlocked(type) and _count(type) < _target(type) and _site_open(type) and not _no_room(type):
			return s.town.price(type)
	return {}


## The generic bot pauses and resumes the workshops by what the techs want; the era's own pauses come last.
func _pause_surplus(short: Dictionary, later: Dictionary) -> void:
	super._pause_surplus(short, later)
	_manage_works()


## The Expedition Post: parts from the Wreck while it has any, then the Bloom samples once the Kith may take them.
func _post_orders() -> void:
	var o: Dictionary = s.starfall.orders
	var target := "wreck"
	if s.tech_tree.researched.has("bloom_sampling") and Finds.nearest_patch(s).x >= 0:
		target = "bloom"
	elif not Finds.wreck_has_parts(s):
		o["keep"] = false
		return
	o["target"] = target
	o["pack"] = "light"
	o["keep"] = Expedition.has_post(s)


## One placement for the era: the way south, the mines, the metal works, the Bench, the Steam Shed, and Rail.
func _build_ironfall() -> bool:
	if _explore_south():
		return true
	if _place_posts():
		return true
	if _place_bench():
		return true
	if _place_coal_mine() or _place_iron_mine():
		return true
	for type in ["boiler", "bloomery"]:
		if s.town.unlocked(type) and _count(type) < _target(type) and _place_near_hearth(type):
			return true
	if _place_forge():
		return true
	if _more_workshops():
		return true
	if _works_due() or not s.tech_tree.researched.has("bloom_sampling"):
		return false
	return _place_steam_shed() or _lay_rail()


## More Kilns, Charcoal Pits, Twine Posts, Smelters and Crucibles than the stone age's four, when the metal works eat bricks,
## rope and bronze faster than they come.
func _more_workshops() -> bool:
	var short := _short()
	for made in MADE_ORDER:
		var type: String = MAKER[made]
		var n: int = short.get(made, 0)
		if n > 0 and s.town.unlocked(type) and _count(type) < mini(WORKSHOPS_BIG, 1 + int(n / WORKSHOP_PER)):
			if _place_workshop(type):
				return true
	return false


## Roads south through the fog toward the Coal Seams, then the Iron Hills, the way the Bronze bot goes to the copper.
func _explore_south() -> bool:
	if not s.world.is_grown_south():
		return false
	if s.tech_tree.researched.has("coal_seams") and _count("coal_mine") < _target("coal_mine"):
		if _free_seam_tiles(true).is_empty() and _go_toward("coal_seam", _hidden_seam()):
			return true
	if s.tech_tree.researched.has("ironstone") and not _seen("iron_hills"):
		return _go_toward("iron_hills", _hidden("iron_hills"))
	return false


## One step of the road toward `target` (an unseen tile of `kind`); false when there is no target or no way.
func _go_toward(kind: String, target: Vector2i) -> bool:
	if target.x < 0:
		return false
	if _stuck(kind, target):
		return _explore_planned(kind)
	return _explore_to(target) if reach.has(target) else false


## The nearest tile of a free seam under fog, by distance to the Hearth.
func _hidden_seam() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for p in _free_seam_tiles(false):
		if s.fog.is_revealed(p):
			continue
		var d := Vector2(p).distance_to(Vector2(s.world.camp_pos))
		if d < best_d:
			best = p
			best_d = d
	return best


func _seen(tile: String) -> bool:
	return _tiles_of(tile).any(func(p): return s.fog.is_revealed(p))


## The nearest tile of `tile` under fog, by distance to the Hearth.
func _hidden(tile: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for p in _tiles_of(tile):
		if s.fog.is_revealed(p):
			continue
		var d := Vector2(p).distance_to(Vector2(s.world.camp_pos))
		if d < best_d:
			best = p
			best_d = d
	return best


## Every tile of the kind `tile` in the map (the land grows only once, so the list is kept).
func _tiles_of(tile: String) -> Array:
	if _tile_size != s.world.height:
		_tile_memo = {}
		_tile_size = s.world.height
	if not _tile_memo.has(tile):
		var out: Array = []
		for y in s.world.height:
			for x in s.world.width:
				if s.world.tiles[y * s.world.width + x] == tile:
					out.append(Vector2i(x, y))
		_tile_memo[tile] = out
	return _tile_memo[tile]


## A Coal Mine on the free seam nearest the Hearth, as many as the coal asks for.
func _place_coal_mine() -> bool:
	if not s.town.unlocked("coal_mine") or _count("coal_mine") >= _target("coal_mine"):
		return false
	var free := _free_seam_tiles(true)
	var near := func(p):
		if p not in free:
			return -INF
		return -Vector2(p).distance_to(Vector2(s.world.camp_pos))
	return _place_best("coal_mine", near)


## A Mine on the Iron Hills nearest the Hearth.
func _place_iron_mine() -> bool:
	if not s.town.unlocked("mine") or not s.tech_tree.researched.has("ironstone"):
		return false
	if _mines_on("iron_hills") >= _target("mine"):
		return false
	var near := func(p):
		if s.world.tile_at(p) != "iron_hills":
			return -INF
		return -Vector2(p).distance_to(Vector2(s.world.camp_pos))
	return _place_best("mine", near)


## Forges within the reach of a Boiler, nearest the Hearth. A crowded town has no free ground there: a road tile is torn down
## for it, the way the stone age's bot makes room for a Water Wheel, and failing that a second Boiler goes up in the open.
func _place_forge() -> bool:
	if not s.town.unlocked("forge") or _count("forge") >= _target("forge") or _count("boiler") == 0:
		return false
	var boilers: Array = []
	for b in s.town.buildings:
		if b["type"] == "boiler":
			boilers.append(b["pos"])
	var radius: float = Data.BUILDINGS["boiler"]["radius"]
	var reached := func(p):
		var d := INF
		for q in boilers:
			d = minf(d, Vector2(p).distance_to(Vector2(q)))
		return d <= radius
	var spot := func(p): return -Vector2(p).distance_to(Vector2(s.world.camp_pos)) if reached.call(p) else -INF
	if _place_best("forge", spot):
		return true
	if not s.economy.can_afford(s.town.price("forge")):
		return false
	if _tear_down_for("forge", reached):
		return true
	return _count("boiler") < BOILERS and _place_near_hearth("boiler")


func _place_bench() -> bool:
	if not s.town.unlocked("teardown_bench") or _count("teardown_bench") >= 1:
		return false
	return _place_best("teardown_bench", func(p): return -Vector2(p).distance_to(Vector2(s.world.camp_pos)))


## A second Expedition Post, so two parties can walk to the Bloom at once.
func _place_posts() -> bool:
	if not Expedition.has_post(s) or not s.tech_tree.researched.has("bloom_sampling"):
		return false
	if _count("expedition_post") >= POSTS or Finds.nearest_patch(s).x < 0:
		return false
	return _place_near_hearth("expedition_post")


## Steam Sheds once the first Rail is laid (a shed with no Rail makes no cart); one before it, so the Rail has a use.
func _place_steam_shed() -> bool:
	if not s.town.unlocked("steam_shed") or _count("steam_shed") >= _target("steam_shed"):
		return false
	return _place_near_hearth("steam_shed")


## Rail on the road from the Hearth to the mines and the metal works, tile by tile, once Rails is learned.
func _lay_rail() -> bool:
	if not s.town.unlocked("rail") or _count("steam_shed") == 0:
		return false
	var laid := 0
	for p in _rail_route():
		if laid >= RAIL_PER_DECISION:
			break
		if s.world.tile_at(p) == "river" or not s.economy.can_afford(s.town.cost_here("rail", p)):
			break
		if not s.place("rail", p):
			break
		laid += 1
	if laid > 0 and not marks.has("rail_started"):
		marks["rail_started"] = clock
	return laid > 0


## The road tiles not yet Rail between the Hearth and the farthest building the bot works (a mine), nearest the Hearth first.
func _rail_route() -> Array:
	var out: Array = []
	var from := s.world.camp_pos
	for b in s.town.buildings:
		if b["type"] not in ["coal_mine", "mine"] or not Buildings.served(b):
			continue
		var path: Array = Roads._route(s, from, b["pos"], "walk")
		for p in path:
			if s.world.roads.has(p) and s.world.road_tiers.get(p, 0) < Data.RAIL_TIER and p not in out:
				out.append(p)
		if not out.is_empty():
			return out
	return out


func _mines_on(tile: String) -> int:
	var n := 0
	for b in s.town.buildings:
		if b["type"] in ["mine", "coal_mine"] and s.world.tile_at(b["pos"]) == tile:
			n += 1
	return n
