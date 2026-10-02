extends RefCounted
## A headless player for pacing. It plays the stone age through Sim the way a person would:
## it clicks resources by hand early on, crafts Flint Tools, sets Bronze Dawn as the research goal
## (the queue researches each tech on the way as soon as it's affordable), places huts next to what
## the next techs need, workshops by the Hearth, dwellings when the Kith run out of room, fields once
## Farming is in, and roads to far buildings once Paths & Haulers is in.
## play() returns {"won", "seconds", "log"}; run_tests.gd checks the time and prints it.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Rules = preload("res://scripts/rules.gd")
const Hands = preload("res://scripts/hands.gd")
const Workers = preload("res://scripts/workers.gd")
const Ranks = preload("res://scripts/ranks.gd")
const Roads = preload("res://scripts/roads.gd")
const World = preload("res://scripts/world.gd")
const Buildings = preload("res://scripts/buildings.gd")

const DT := 0.1
const THINK := 1.0  # seconds between decisions
## Building clicks a second (dispatching trips, loading workshops, rushing), taken between harvests.
const CLICKS_EARLY := 2.0
const CLICKS_LATE := 1.0
## Share of the time the bot holds on a tile once haulers carry for it (always, before that).
const HOLD_LATE := 0.4
const RAW_TILE := {
	"wood": "tree",
	"stone": "rock",
	"flint": "gravel",
	"fiber": "flax",
	"clay": "clay",
	"berries": "berry",
	"grain": "grain",
	"copper_ore": "copper_hills",
	"tin": "tin_stream",
}
## A hut is paused while everything it gathers is past this and not needed.
const HUT_SURPLUS := 150
## Road tiles laid toward an unlinked building per decision.
const LANE_ARM := 10  # how far the kept-open arms run out from the Hearth
const HAULER_PER := 3.0  # buildings per hauler the bot keeps free
const ROADS_PER_DECISION := 4
## One more workshop of a kind for every WORKSHOP_PER of its good still wanted, up to WORKSHOPS_MAX.
const WORKSHOP_PER := 40.0
const WORKSHOPS_MAX := 4
## Which workshop makes each made good.
const MAKER := {
	"rope": "twine_post",
	"charcoal": "charcoal_pit",
	"brick": "kiln",
	"flour": "grindstone",
	"copper": "smelter",
	"bronze": "crucible",
}
## Made goods from the last step of a chain to the first, so what a good needs is added before the goods it is made from.
const MADE_ORDER := ["bronze", "copper", "flour", "brick", "charcoal", "rope"]

var s: Sim
var clock := 0.0
var clicks := 0.0
var think := 0.0
var lines: Array = []
var known := {}  # techs already logged
var trace := false  # log what the next tech is waiting on, every minute
var clicked := {}  # what the harvests and clicks went to since the last trace
var hold_tile := Vector2i(-1, -1)  # the tile the bot is holding on, (-1, -1) for none
var goal_tech := "bronze_dawn"  # the tech the bot is working toward
var reach := {}  # tiles the Kith can walk to from the Hearth, refreshed each decision


func play(map_seed: int, max_seconds: float) -> Dictionary:
	var game := Sim.new()
	game.generate(map_seed)
	attach(game)
	while clock < max_seconds and not s.won:
		step(true)
	return {"won": s.won, "seconds": clock, "log": lines}


## Play `game` from here on: step() then advances it (tests/tools/play_pass.gd runs it under the live UI).
func attach(game: Sim) -> void:
	s = game
	s.tech_tree.set_goal(goal_tech)


## One DT of play: tick the simulation (unless something else ticks it), then click and decide.
func step(tick: bool) -> void:
	if tick:
		s.tick(DT)
		s.events.clear()
	clock += DT
	_log_research()
	clicks += DT * (CLICKS_LATE if s.tech_tree.researched.has("haulers") else CLICKS_EARLY)
	if trace and fmod(clock + DT * 0.5, 60.0) < DT:
		_trace()
	clicks = minf(clicks, 4.0)
	think -= DT
	if think <= 0.0:
		think = THINK
		_decide()
	# The hand is free between harvests: that's when it clicks buildings (which lets go of the hold).
	if _harvest() or hold_tile.x < 0:
		while clicks >= 1.0 and _click():
			clicks -= 1.0
			s.release_harvest()
			hold_tile = Vector2i(-1, -1)


## Hold on the tile for what's shortest; true when a harvest just completed.
func _harvest() -> bool:
	if s.tech_tree.researched.has("haulers") and fmod(clock, 10.0) >= HOLD_LATE * 10.0:
		s.release_harvest()
		hold_tile = Vector2i(-1, -1)
		return false
	if hold_tile.x < 0 or Hands.item_at(s, hold_tile) == "":  # a building may have gone up on it
		hold_tile = _pick_tile()
		if hold_tile.x < 0:
			return false
	var item: String = Data.TILES[s.world.tile_at(hold_tile)]["yields"]
	if s.hold_harvest(hold_tile, DT) == "":
		return false
	clicked[item] = clicked.get(item, 0) + 1
	hold_tile = Vector2i(-1, -1)
	return true


func _log_research() -> void:
	for tech in s.tech_tree.researched:
		if not known.has(tech):
			known[tech] = true
			lines.append("%5.0f s  %s  (Kith %d)" % [clock, Data.TECHS[tech]["name"], s.people.kith.size()])


func _trace() -> void:
	var next: String = s.tech_tree.queue[0] if not s.tech_tree.queue.is_empty() else ""
	var missing := {}
	if next != "":
		var cost: Dictionary = Data.TECHS[next]["cost"]
		for id in cost:
			if s.economy.inv.get(id, 0) < cost[id]:
				missing[id] = "%d/%d" % [s.economy.inv.get(id, 0), cost[id]]
	lines.append(
		(
			"%5.0f s  .. next %s missing %s  Kith %d, workers %d, clicks %s short %s"
			% [clock, next, missing, s.people.kith.size(), _workers(), clicked, _short()]
		)
	)
	clicked = {}


# --- What we're short of -----------------------------------------------------


## Items the next few queued techs (and the next hut) still need, with made goods broken down into
## what they're made of.
func _short() -> Dictionary:
	if s.tech_tree.goal == "" and not s.won:
		s.tech_tree.set_goal(goal_tech)
	var want := {}
	for tech in s.tech_tree.queue.slice(0, 3):
		_want(want, Data.TECHS[tech]["cost"], 1)
	if s.town.unlocked("gatherers_hut") and (_workers() < s.people.kith.size() or _no_food_hut()):
		_want(want, Data.BUILDINGS["gatherers_hut"]["cost"], 1)
	if _house_wanted():
		_want(want, Data.BUILDINGS["dwelling"]["cost"], 1)
	for type in _workshops_due():
		_want(want, Data.BUILDINGS[type]["cost"], 1)
	_goal_wants(want)
	var tools: int = _workers() + 1 - Hands.tools_held(s) - s.economy.inv.get("flint_tools", 0)
	if Hands.recipe_unlocked(s, "flint_tools") and tools > 0:
		_want(want, Data.RECIPES["flint_tools"]["in"], mini(tools, 2))
	for made in MADE_ORDER:
		var n: int = want.get(made, 0) - s.economy.inv.get(made, 0)
		if n > 0:
			_want(want, Data.BUILDINGS[MAKER[made]]["in"], _batches(made, n))
	var short := {}
	for id in want:
		var n: int = want[id] - s.economy.inv.get(id, 0)
		if n > 0:
			short[id] = n
	if s.economy.food_total() < s.people.kith.size() * 4.0:
		short["berries"] = short.get("berries", 0) + 10
	return short


## More goods the bot wants than the techs and buildings above say (a later era's bot adds its own).
func _goal_wants(_list: Dictionary) -> void:
	pass


## Made goods the whole route to Bronze Dawn still costs: they take a workshop and time, so the
## workshops go up as soon as they're unlocked.
func _route_need() -> Dictionary:
	var need := {}
	for tech in Rules.route_to(goal_tech, s.tech_tree.researched, Rules.visible_techs(s.shard_seen)):
		var cost: Dictionary = Data.TECHS[tech]["cost"]
		for id in cost:
			if MAKER.has(id):
				need[id] = need.get(id, 0) + cost[id]
	for made in MADE_ORDER:
		var left: int = need.get(made, 0) - s.economy.inv.get(made, 0)
		var inputs: Dictionary = Data.BUILDINGS[MAKER[made]]["in"]
		for id in inputs:
			if MAKER.has(id) and left > 0:
				need[id] = need.get(id, 0) + _batches(made, left) * inputs[id]
	return need


## How many workshop cycles make n of `made` (a Kiln fires two Brick a cycle).
func _batches(made: String, n: int) -> int:
	return ceili(n / float(Data.BUILDINGS[MAKER[made]]["out"][made]))


func _want(want: Dictionary, cost: Dictionary, times: int) -> void:
	for id in cost:
		want[id] = want.get(id, 0) + cost[id] * times


## What to gather by hand: the first queued tech that's missing something we can reach decides it
## (the most-missing raw good behind it), so the next tech comes as soon as it can.
func _next_click() -> String:
	var costs: Array = []
	if s.town.unlocked("gatherers_hut") and (_workers() + _haulers_wanted() < s.people.kith.size() or _no_food_hut()):
		costs.append(Data.BUILDINGS["gatherers_hut"]["cost"])
	if _house_wanted():
		costs.append(Data.BUILDINGS["dwelling"]["cost"])
	for tech in s.tech_tree.queue:
		if s.tech_tree.requirements_met(tech):
			costs.append(Data.TECHS[tech]["cost"])
	for cost in costs:
		var want := {}
		_want(want, cost, 1)
		for made in MADE_ORDER:
			var n: int = want.get(made, 0) - s.economy.inv.get(made, 0)
			if n > 0:
				_want(want, Data.BUILDINGS[MAKER[made]]["in"], _batches(made, n))
		var short := {}
		for id in want:
			if want[id] > s.economy.inv.get(id, 0):
				short[id] = want[id] - s.economy.inv.get(id, 0)
		var item := _most_short_raw(short)
		if item != "":
			return item
	return _most_short_raw(_short())


## The raw good we're shortest of that can be reached by hand right now.
func _most_short_raw(short: Dictionary) -> String:
	var best := ""
	for id in RAW_TILE:
		if _nearest_tile(RAW_TILE[id], s.world.camp_pos).x < 0:
			continue
		if short.has(id) and (best == "" or short[id] > short[best]):
			best = id
	return best


# --- Clicks ------------------------------------------------------------------


## One click on a building, if one is worth it: send hut trips and load or empty workshops that no
## road links yet (all of them before haulers); else rush the building making what's shortest.
## Crafting a tool counts too. Returns false when there's nothing to click.
func _click() -> bool:
	for i in s.town.buildings.size():
		var b: Dictionary = s.town.buildings[i]
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		if not Roads.automated(s, b):
			if def["kind"] == "gatherer" and b["worker"] >= 0 and b["trips"] < Data.TRIP_QUEUE:
				if s.people.knows_focus(b):
					Workers.click(s, i)
					clicked["trip"] = clicked.get("trip", 0) + 1
					return true
			var hungry := false
			if def["kind"] == "processor" and not b["paused"] and s.economy.can_afford(def["in"]):
				for id in def["in"]:
					hungry = hungry or b["inbuf"].get(id, 0) < def["in"][id]
			if Buildings.buffered(b["out"]) >= 5 or hungry:
				Workers.click(s, i)
				return true
	if (
		Hands.recipe_unlocked(s, "flint_tools")
		and Hands.tools_held(s) + s.economy.inv.get("flint_tools", 0) < _workers() + 1
	):
		if s.economy.inv.get("flint", 0) >= 2 and s.economy.inv.get("wood", 0) >= 2 and Hands.craft(s, "flint_tools"):
			return true
	return _rush()


## Rush a working building, workshops first (their goods take longest), then huts.
func _rush() -> bool:
	var best := -1
	for i in s.town.buildings.size():
		var b: Dictionary = s.town.buildings[i]
		if not Workers.can_rush(s, b):
			continue
		if Data.BUILDINGS[b["type"]]["kind"] == "processor":
			best = i
			break
		if best < 0:
			best = i
	if best < 0:
		return false
	Workers.rush(s, best)
	clicked["rush"] = clicked.get("rush", 0) + 1
	return true


## The tile to hold on next: the raw good that's shortest, or Berries when food runs low.
func _pick_tile() -> Vector2i:
	var item := _next_click()
	# Kith are born only with food to spare, so keep some while there's room for them.
	var room := s.people.kith.size() < s.town.housing()
	if s.economy.food_total() < s.people.kith.size() * 2.0 + (Data.BIRTH_FOOD + 3.0 if room else 2.0):
		item = "berries"
	if item == "":
		item = "stone" if s.economy.inv.get("stone", 0) < s.economy.inv.get("wood", 0) else "wood"
	return _nearest_tile(RAW_TILE[item], s.world.camp_pos)


func _nearest_tile(tile: String, from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			if s.world.tile_at(p) == tile and Hands.item_at(s, p) != "":
				var d := Vector2(p).distance_to(Vector2(from))
				if d < best_d:
					best = p
					best_d = d
	return best


# --- Building ----------------------------------------------------------------


## Workshops the route needs that aren't built yet (and can be), so their cost gets gathered.
func _workshops_due() -> Array:
	var out: Array = []
	var later := _route_need()
	for made in MAKER:
		var type: String = MAKER[made]
		if later.get(made, 0) > s.economy.inv.get(made, 0) and s.town.unlocked(type) and _count(type) == 0:
			out.append(type)
	return out


## Out of room, and short of hands for the buildings plus a couple spare.
func _house_wanted() -> bool:
	return s.people.kith.size() >= s.town.housing() and _workers() + _haulers_wanted() + 3 > s.people.kith.size()


## Once Paths & Haulers is in, keep a few Kith free to carry: one for every HAULER_PER buildings.
func _haulers_wanted() -> int:
	return 1 + int(_workers() / HAULER_PER) if s.tech_tree.researched.has("haulers") else 0


## A Storehouse by any workshop or hut far from a stockpile, so haulers fetch and drop off nearby.
func _place_storehouse() -> bool:
	for b in s.town.buildings:
		if not Buildings.needs_worker(b):
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


func _workers() -> int:
	var n := 0
	for b in s.town.buildings:
		if Buildings.needs_worker(b):
			n += Buildings.crew_size(b)
	return n


func _count(type: String) -> int:
	var n := 0
	for b in s.town.buildings:
		if b["type"] == type:
			n += 1
	return n


## No hut brings in food yet. Births need food the buildings make, so a start that spent its Kith on posts
## and workshops before any hut would never grow: the first Berries hut goes up whether or not a hand is free.
func _no_food_hut() -> bool:
	return _huts_for("berries") < 1.0


## Huts set to gather `item` (a hut works one resource).
func _huts_for(item: String) -> float:
	var n := 0.0
	for b in s.town.buildings:
		if b["type"] == "gatherers_hut" and b["focus"] == item:
			n += 1.0
	return n


## One placement a decision, most urgent first.
func _decide() -> void:
	_flood_reach()
	var short := _short()
	var later := _route_need()
	_pause_surplus(short, later)
	if _buy_rank(short):
		return
	if s.tech_tree.researched.has("haulers") and _link_roads():
		return
	if _house_wanted() and s.economy.food_total() >= s.people.kith.size() * 2.0 + Data.BIRTH_FOOD:
		if _place_near_hearth("dwelling"):
			return
		if s.research("shelter"):
			return  # no room left by the Hearth: Thatched Roofs make each Dwelling house more
	if s.town.unlocked("storehouse") and _place_storehouse():
		return
	if _explore(short):
		return
	if _water_wheel():
		return
	for type in _workshops_due() if s.tech_tree.researched.has("haulers") else []:  # the route needs these, hands or not
		if _place_workshop(type):
			return
	var fed := s.economy.food_total() >= s.people.kith.size() * 2.0 + Data.BIRTH_FOOD
	if s.town.unlocked("gatherers_hut") and _huts_for("berries") < 1 + int(s.people.kith.size() / 6.0):
		var room_for_hut := _workers() + _haulers_wanted() < s.people.kith.size() + 1
		if (not fed or room_for_hut or _no_food_hut()) and _place_hut("berries"):
			return  # food comes first: more Kith are born only while there's food to spare
	if _workers() + _haulers_wanted() >= s.people.kith.size() + 1:
		return
	if s.town.unlocked("gatherers_hut"):
		for item in ["wood", "stone", "fiber", "flint", "clay", "grain"]:
			var n: int = short.get(item, 0)
			var want := 0 if n <= 0 else 1 + mini(int(n / 30.0), 2)
			if item in ["wood", "stone"]:
				want = maxi(want, 1)
			var have := _huts_for(item)
			if have < want - 0.5 and (_place_hut(item, have) or (have < 0.5 and _explore_for(item))):
				return
	for made in MAKER:
		var n: int = short.get(made, 0)
		if s.tech_tree.researched.has("haulers"):  # before haulers every workshop costs clicks to feed, so only build what's due
			n = maxi(n, later.get(made, 0) - s.economy.inv.get(made, 0))
		var type: String = MAKER[made]
		if n > 0 and s.town.unlocked(type) and _count(type) < 1 + mini(int(n / WORKSHOP_PER), WORKSHOPS_MAX - 1):
			if _place_workshop(type):
				return
	if s.town.unlocked("field") and s.world.fields.size() < 8 and short.get("grain", 0) > 0 and _place_field():
		return


## Buy the next rank on a tech whose good we're short of, when that leaves enough for the next tech.
func _buy_rank(short: Dictionary) -> bool:
	var next: Dictionary = Data.TECHS[s.tech_tree.queue[0]]["cost"] if not s.tech_tree.queue.is_empty() else {}
	for tech in Data.TECH_ORDER:
		var r: Dictionary = Data.TECHS[tech].get("rank", {})
		var good: String = r.get("item", "")
		for made in MAKER:
			if MAKER[made] == r.get("building", ""):
				good = made
		var price := Ranks.next_cost(s, tech)
		if short.has(good) and not s.tech_tree.researched.has(tech) and s.tech_tree.can_research(tech):  # a side tech, as rank I
			price = Data.TECHS[tech]["cost"]
		if not short.has(good) or price.is_empty() or not s.economy.can_afford(price):
			continue
		var spare := true
		for id in price:
			spare = spare and s.economy.inv.get(id, 0) - price[id] >= next.get(id, 0)
		if spare and not s.tech_tree.researched.has(tech):
			s.research(tech)
			return true
		if spare and Ranks.buy(s, tech):
			lines.append(
				"%5.0f s    rank %s on %s" % [clock, Data.RANK_NAMES[Ranks.rank(s, tech)], Data.TECHS[tech]["name"]]
			)
			return true
	return false


## When something we need lies only out in the fog (Clay on the river banks), build a hut at the
## edge of what we can see, on the side where it lies, to see farther.
func _explore(short: Dictionary) -> bool:
	for id in short:
		if not RAW_TILE.has(id) or _nearest_tile(RAW_TILE[id], s.world.camp_pos).x >= 0:
			continue
		var target := _nearest_hidden(RAW_TILE[id])
		if target.x >= 0:
			return _explore_to(target)
	return false


## No good hut spot in sight for `item`: push the fog back toward the nearest unseen tile of it.
func _explore_for(item: String) -> bool:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			if s.fog.is_revealed(p) or s.world.tile_at(p) != RAW_TILE[item] or not reach.has(p):
				continue
			var d := Vector2(p).distance_to(Vector2(s.world.camp_pos))
			if d < best_d:
				best = p
				best_d = d
	return best.x >= 0 and _explore_to(best)


## Push the edge of what we can see toward `target`: a few road tiles once there are roads (each one
## lifts the fog around it), or a hut before that. A road goes only at the fog's edge.
func _explore_to(target: Vector2i) -> bool:
	var score := func(p): return -Vector2(p).distance_to(Vector2(target))
	if not s.town.unlocked("road"):
		return _place_best("gatherers_hut", score)
	score = func(p): return -Vector2(p).distance_to(Vector2(target)) if _at_fog_edge(p) else -INF
	var laid := false
	for i in 3:
		if _spare("wood") < 2 or not _place_best("road", score):
			break
		laid = true
	return laid


## Grass or Forest with unseen ground within a Kith's sight of it: a road there lifts some fog.
func _at_fog_edge(p: Vector2i) -> bool:
	if s.world.tile_at(p) not in ["grass", "tree"] or s.world.touches_river(p):  # the banks stay open for a Water Wheel
		return false
	for dy in range(-Data.SIGHT_KITH, Data.SIGHT_KITH + 1):
		for dx in range(-Data.SIGHT_KITH, Data.SIGHT_KITH + 1):
			var q: Vector2i = p + Vector2i(dx, dy)
			if s.world.in_bounds(q) and not s.fog.is_revealed(q):
				return true
	return false


## The unseen river-bank grass tile nearest the Hearth, to explore toward for the Water Wheel.
func _nearest_bank() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			if s.world.tile_at(p) == "grass" and s.world.touches_river(p) and not s.fog.is_revealed(p):
				var d := Vector2(p).distance_to(Vector2(s.world.camp_pos))
				if d < best_d:
					best = p
					best_d = d
	return best


func _nearest_hidden(tile: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			if s.world.tile_at(p) == tile and reach.has(p):
				var d := Vector2(p).distance_to(Vector2(s.world.camp_pos))
				if d < best_d:
					best = p
					best_d = d
	return best


## Pause workshops whose goods pile up unneeded (and so stop eating their inputs), or that eat what
## the next Dwelling needs; resume them after.
func _pause_surplus(short: Dictionary, later: Dictionary) -> void:
	var saving := {}
	# Raw goods the next tech pays in directly go to it, not into a workshop.
	var next: String = s.tech_tree.queue[0] if not s.tech_tree.queue.is_empty() else ""
	if next != "":
		var cost: Dictionary = Data.TECHS[next]["cost"]
		for id in cost:
			if RAW_TILE.has(id) and s.economy.inv.get(id, 0) < cost[id]:
				saving[id] = true
	if _house_wanted():
		var house: Dictionary = Data.BUILDINGS["dwelling"]["cost"]
		for id in house:
			if s.economy.inv.get(id, 0) < house[id]:
				saving[id] = true
	for i in s.town.buildings.size():
		var b: Dictionary = s.town.buildings[i]
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		if def["kind"] == "gatherer" and b["focus"] != "":
			# A hut whose goods pile up unneeded only keeps the haulers busy: its Kith can carry instead.
			var id: String = b["focus"]
			var idle: bool = s.economy.inv.get(id, 0) >= HUT_SURPLUS and not short.has(id)
			if idle != b["paused"]:
				s.set_paused(i, idle)
			continue
		if def["kind"] != "processor" or def["out"].is_empty():
			continue  # a Mine makes no stock of its own
		var made: String = def["out"].keys()[0]
		var surplus: bool = s.economy.inv.get(made, 0) >= later.get(made, 0) + 10 and not short.has(made)
		for id in def["in"]:
			surplus = surplus or saving.has(id)
		if surplus != b["paused"]:
			s.set_paused(i, surplus)


func _place_near_hearth(type: String) -> bool:
	return _place_best(type, func(p): return -Vector2(p).distance_to(Vector2(s.world.camp_pos)))


## A hut where `item` is thickest in its range, set to gather it (a hut works one resource).
func _place_hut(item: String, have := 0.0) -> bool:
	var tile: String = RAW_TILE[item]
	var score := func(p):
		var mine := 0
		for t in s.town.gather_tiles(p):
			if s.world.tile_at(t) == tile:
				mine += 1
		if mine == 0 or (have > 0.0 and mine < 3):
			return -INF
		return mine * 3.0 - Vector2(p).distance_to(Vector2(s.world.camp_pos))
	return _place_best("gatherers_hut", score, item)


## Once the Water Wheel is researched, put one on the bank nearest the Hearth, exploring toward it
## first if the bank is still fogged.
func _water_wheel() -> bool:
	if not s.town.unlocked("water_wheel") or _count("water_wheel") > 0:
		return false
	return _place_wheel()


## A Water Wheel on the bank with room for workshops around it, near the Hearth; explore toward
## the nearest bank if none is in sight.
func _place_wheel() -> bool:
	if not s.economy.can_afford(Data.BUILDINGS["water_wheel"]["cost"]):
		return false
	var radius: float = Data.BUILDINGS["water_wheel"]["radius"]
	var room_around := func(p):
		var n := 0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var q: Vector2i = p + Vector2i(dx, dy)
				var open: bool = (
					s.world.tile_at(q) == "grass"
					and s.fog.is_revealed(q)
					and not s.town.building_at.has(q)
					and not s.world.roads.has(q)
				)
				if open and q != p and Vector2(q).distance_to(Vector2(p)) <= radius:
					n += 1
		return -INF if n < 2 else n * 2.0 - Vector2(p).distance_to(Vector2(s.world.camp_pos))
	if _place_best("water_wheel", room_around):
		return true
	var bank := _nearest_bank()
	if bank.x >= 0 and _explore_to(bank):
		return true
	if _count("water_wheel") > 0:
		return false
	# No bank tile with room round it and nothing to explore: any free bank tile will do (a Grindstone then
	# tears down a road beside it), else tear down a bank road.
	return _place_near_hearth("water_wheel") or _tear_down_for("water_wheel", s.world.touches_river)


## The last resort, when the bank has no free site and nothing left to explore toward (the bot's own roads
## took it): tear down the road on the tile that `suits` `type` with the most open ground round it, and
## build there. Hearth lanes stay. True if it went up.
func _tear_down_for(type: String, suits: Callable) -> bool:
	var best := Vector2i(-1, -1)
	var best_open := -1
	for p in reach:
		if not s.world.roads.has(p) or _lane(p) or s.world.tile_at(p) != "grass" or not suits.call(p):
			continue
		var open := 0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var q: Vector2i = p + Vector2i(dx, dy)
				if s.world.tile_at(q) == "grass" and not s.town.building_at.has(q):
					open += 1
		if open > best_open:
			best = p
			best_open = open
	if best.x < 0:
		return false
	s.demolish(best)
	lines.append("%5.0f s    - Road at %s, for the %s" % [clock, best, Data.BUILDINGS[type]["name"]])
	return s.place(type, best)


func _place_workshop(type: String) -> bool:
	if Data.BUILDINGS[type].get("needs_power", false):
		if _count("water_wheel") == 0:
			return false
		if not s.economy.can_afford(Data.BUILDINGS[type]["cost"]):
			return false
		var placed := _place_best(
			type, func(p): return -Vector2(p).distance_to(Vector2(s.world.camp_pos)) if s.town.is_powered(p) else -INF
		)
		return placed or (_count("water_wheel") < 3 and _place_wheel()) or _tear_down_for(type, s.town.is_powered)
	return _place_near_hearth(type)


## A Field within reach of a hut, so it gets harvested.
func _place_field() -> bool:
	return _place_best(
		"field",
		func(p):
			for b in s.town.buildings:
				if b["type"] == "gatherers_hut" and "grain" in b["gather_items"]:
					var d: Vector2i = (p - b["pos"]).abs()
					if maxi(d.x, d.y) <= s.town.hut_radius():
						return -Vector2(p).distance_to(Vector2(b["pos"]))
			return -INF
	)


## Every tile the Kith can walk to from the Hearth (the river blocks until it's bridged).
func _flood_reach() -> void:
	reach = {s.world.camp_pos: true}
	var todo: Array = [s.world.camp_pos]
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		for n in World.NEIGHBORS:
			var q: Vector2i = p + n
			if s.world.in_bounds(q) and not reach.has(q) and not s.pathing.astar.is_point_solid(q):
				reach[q] = true
				todo.append(q)


## Place `type` on the revealed tile with the best score (skipping -INF), if it can be afforded.
## Buildings go only where the Kith can walk; roads may push out from there.
func _place_best(type: String, score: Callable, focus := "") -> bool:
	if not s.town.unlocked(type) or not s.economy.can_afford(Data.BUILDINGS[type]["cost"]):
		return false
	var best := Vector2i(-1, -1)
	var best_score := -INF
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			if not reach.has(p) or s.town.placement_error(type, p) != "":
				continue
			if type != "road" and _lane(p):
				continue  # kept open so roads can always reach the Hearth
			var v: float = score.call(p)
			if v > best_score:
				best = p
				best_score = v
	if best.x < 0 or not s.place(type, best):
		return false
	if focus != "":
		s.town.set_focus(s.town.building_at[best], focus)
	lines.append("%5.0f s    + %s at %s" % [clock, Data.BUILDINGS[type]["name"], best])
	return true


## What we hold of `item` beyond what the next tech and the workshops due still need: only that goes
## into roads.
func _spare(item: String) -> int:
	var keep := 10
	if not s.tech_tree.queue.is_empty():
		keep += int(Data.TECHS[s.tech_tree.queue[0]]["cost"].get(item, 0))
	for type in _workshops_due():
		keep += int(Data.BUILDINGS[type]["cost"].get(item, 0))
	return s.economy.inv.get(item, 0) - keep


## True if a road on `p` fits in what we can spare.
func _road_affordable(p: Vector2i) -> bool:
	var cost: Dictionary = Rules.cost_at("road", s.world.tile_at(p), s.tech_tree.researched.has("causeways"))
	for id in cost:
		if cost[id] > _spare(id):
			return false
	return s.economy.can_afford(cost)


## Haulers serve only road-linked buildings: lay Road from the first unlinked worker building to the
## nearest road network that reaches a depot (or to a depot), a few tiles a decision. True if any went down.
func _link_roads() -> bool:
	for b in s.town.buildings:
		if not Buildings.needs_worker(b) or b["paused"] or Roads.linked(s, b):
			continue
		var path := _road_path(b["pos"])
		var laid := 0
		for p in path:
			if laid >= ROADS_PER_DECISION or not _road_affordable(p):
				break
			if s.place("road", p):
				laid += 1
		if laid > 0:
			return true
	return false


## The tiles to pave, nearest first, joining building p to a depot's road network: a search from p's
## sides to a road on a network that reaches a depot, or to a tile beside a depot, over open grass
## (or road already there), then through Forest too, then cutting passes through Rocks (3 Stone a
## tile) only when there's no other way. [] when there's none.
func _road_path(p: Vector2i) -> Array:
	for ground in [["grass"], ["grass", "tree"], ["grass", "tree", "rock"]]:
		var path := _road_search(p, ground)
		if not path.is_empty():
			return path
	return []


func _road_search(p: Vector2i, ground: Array) -> Array:
	var depot_net := {}
	for depot in Roads.depots(s):
		for id in Roads.depot_nets(s, depot):
			depot_net[id] = true
	var from := {}
	var todo: Array = []
	for n in World.NEIGHBORS:
		var q: Vector2i = p + n
		if _paveable(q, ground):
			from[q] = p
			todo.append(q)
	while not todo.is_empty():
		var q: Vector2i = todo.pop_front()
		var done := false
		for n in World.NEIGHBORS:
			if (q + n) in Roads.depots(s):
				done = true
		if s.world.roads.has(q) and depot_net.has(s.town.road_net["net"].get(q, -1)):
			done = true
		if done:
			var path: Array = []
			while q != p:
				if not s.world.roads.has(q):
					path.push_front(q)
				q = from[q]
			return path
		for n in World.NEIGHBORS:
			var r: Vector2i = q + n
			if not from.has(r) and _paveable(r, ground):
				from[r] = q
				todo.append(r)
	return []


## A tile the bot never builds on, so roads can always reach the Hearth: the ring right around it
## (cleared grass on every map) and the four arms running straight out from it.
func _lane(p: Vector2i) -> bool:
	var d := (p - s.world.camp_pos).abs()
	return maxi(d.x, d.y) == 1 or (mini(d.x, d.y) == 0 and maxi(d.x, d.y) <= LANE_ARM)


func _paveable(p: Vector2i, ground: Array) -> bool:
	if s.world.roads.has(p):
		return true
	if not s.world.in_bounds(p) or not s.fog.is_revealed(p) or s.town.building_at.has(p) or not reach.has(p):
		return false
	return s.world.tile_at(p) in ground
