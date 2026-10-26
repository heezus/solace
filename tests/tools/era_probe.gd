extends RefCounted
## A reading of one run, era by era, for the baseline (tests/tools/pace.gd `baseline`): what the town looked like when each era
## began and how its logistics did while it ran. It only looks: nothing here touches a Sim or changes a bot's play.
## begin(name, s) opens an era and takes the start snapshot; observe(s) is called every step (the bots' `probe` hook) and samples
## once a game second; finish(s) closes the era and returns its row. Livewire opens by itself when the card that begins it is put
## away (observe sees Data.LIVEWIRE_BEGUN) and closes the Ironfall row before it.

const Buildings = preload("res://scripts/buildings.gd")
const Data = preload("res://scripts/data.gd")
const Fuel = preload("res://scripts/fuel.gd")
const Haulers = preload("res://scripts/haulers.gd")
const Kith = preload("res://scripts/kith.gd")
const Ledger = preload("res://tests/tools/ledger.gd")
const Roads = preload("res://scripts/roads.gd")
const Ui = preload("res://scripts/ui.gd")

const WATCHED := ["power", "arc_lamp", "scorcher", "pole"]  # the buildings whose loss to the tide is traced one by one
const SAMPLE := 1.0  # game seconds between readings
const STEP := 0.1  # game seconds of one bot step (Autoplay.DT)
const LOST_BY := 15.0 * 60.0  # Livewire: buildings lost by this many seconds into the era
const DEPOTS_EVERY := 300.0  # game seconds between readings of the haulers at each depot
const PACE_EVERY := 60.0  # Livewire: game seconds between readings of the power drawn and the tide's pace
const WAKE_WINDOW := 20.0 * 60.0  # Livewire: buildings lost within this many seconds of the tide waking

## The era names in order, and the goal list each one is counted from (the checklist the player sees in it).
const ERAS := ["stone_age", "bronze_dawn", "starfall", "ironfall", "livewire"]

var rows: Array = []
var era := ""
var ledger := Ledger.new()  # the supply and use ledger of the era under way (ledger.gd), in each row as "ledger"
var _row := {}
var _at := 0.0  # game clock at the era's start
var _acc := 0.0
var _streak := {}  # building tile -> seconds in a row it has waited for a hauler
var _fuel := {}  # metal works tile -> seconds in a row it has stood without fuel, the rest of its recipe in hand
var _made_seen := {}  # Economy.made_on at the last reading
var _burn_seen := {}  # Economy.burnt_by at the last reading
var _zero_run := 0.0  # seconds in a row the power has stood at zero with Wood in the stores
var _starve := {}  # workshop tile -> seconds in a row it has stood starved with its input in stock
var _spill_of_seen := {}  # Economy.spilled_of at the last reading, by good
var _spill_seen := 0  # Economy.spilled at the last reading (it is not saved, so a resumed run starts it again from 0)
var _depots_at := 0.0  # era seconds of the last depot reading
var _town_at := 0.0  # era seconds of the last reading of the jobs
var _zero_at := -1000.0  # era seconds of the last note on why the power stood at zero


## Open era `name` on `s`: the start snapshot (people, places, stock, coal in the ground).
func begin(name: String, s) -> void:
	era = name
	_at = s.seasons.time
	_acc = 0.0
	_streak.clear()
	_starve.clear()
	_fuel.clear()
	_made_seen = s.economy.made_on.duplicate(true)
	_burn_seen = s.economy.burnt_by.duplicate(true)
	_zero_run = 0.0
	_spill_seen = s.economy.spilled
	_spill_of_seen = s.economy.spilled_of.duplicate()
	_depots_at = 0.0
	_town_at = 0.0
	_zero_at = -1000.0
	ledger.begin(name, s)
	var idle := 0
	var haulers := 0
	for k in s.people.kith:
		if k["job"] == "":
			idle += 1
		elif k["job"] == "haul":
			haulers += 1
	var places := 0
	var staffed := 0
	var paused := 0
	for b in s.town.buildings:
		if Buildings.needs_worker(b):
			places += Buildings.crew_size(b)
			for slot in Buildings.crew_slots(b):
				if b[slot] >= 0:
					staffed += 1
			if b["paused"]:
				paused += 1
	_row = {
		"era": name,
		"start":
		{
			"minute": snappedf(_at / 60.0, 0.1),
			"kith": s.people.kith.size(),
			"idle_kith": idle,
			"haulers": haulers,
			"places": places,
			"staffed_places": staffed,
			"paused_buildings": paused,
			"stock": _stock(s),
			"coal_in_ground": _coal_in_ground(s),
			"depots": _depots(s),
			"hauler_ratio": _ratio(s),
			"charcoal_pits": _count(s, "charcoal_pit"),
		},
		"hauler_wait_total_s": 0.0,
		"hauler_wait_longest_s": 0.0,
		"starved_with_stock_s": 0.0,
		"starved_longest_s": 0.0,
		"spilled": 0,
		"spilled_by_good": {},
		"hauler_waits": 0,
		"resting_s": 0.0,
		"made_on_coal": {},
		"made_on_charcoal": {},
		"fuel_starved_s": 0.0,
		"fuel_starved_longest_s": 0.0,
		"wood_short_s": 0.0,
		"research_wait_head_s": 0.0,  # seconds the head of the research queue had its requirements and not its materials
		"research_wait_all_s": 0.0,  # seconds the queue was not empty and nothing in it could be paid for yet
		"research_wait_by": {},  # the same head seconds, by tech
		"depots_every_5_min": [],
		"town_every_5_min": [],
	}
	if name == "ironfall" or name == "livewire":
		_row["queue_empty_s"] = 0.0  # seconds the research queue stood empty with the era's gate still to learn
		_row["forge_paused_steel_wanted_s"] = 0.0  # seconds a Forge stood paused while a queued tech lacked Steel
	if name == "livewire":
		_row["first_overgrown_min"] = -1.0
		_row["first_lost_min"] = -1.0
		_row["lost_by_15"] = -1
		_row["first_scorcher_burn_min"] = -1.0
		_row["tide_woke_min"] = -1.0
		_row["lost_before_first_scorcher"] = -1
		_row["lost_within_20_of_wake"] = -1
		_row["lost_at_min"] = []  # the minute of each building the Bloom took
		_row["power_given_min_after_scorcher"] = -1  # fewest units the nets gave, from the first Scorcher on (-1: none built)
		_row["power_share_min_after_scorcher"] = -1.0  # lowest share of what the nets asked that they gave, the same time
		_row["engines_peak"] = 0  # most engines (Boilers, Generators, Wheels) standing at once
		_row["engines_min_after_peak"] = 0  # fewest standing after that peak
		_row["engine_lost_and_back"] = false  # the engines fell below their peak and later stood at it again
		_row["engines_dipped"] = false
		_row["engine_losses"] = []  # one entry per engine the Bloom took: what held or failed to hold it (see _watch_engines)
		_row["engine_watch"] = {}  # engine tile "x,y" -> what the last reading while it was overgrown saw
		_row["firebreak_tiles"] = 0
		_row["pace_every_min"] = []
		_row["power_zero_with_wood_s"] = 0.0  # seconds a net asked for power and none was given, with Wood in the stores
		_row["power_zero_with_wood_longest_s"] = 0.0
		_row["fuel_burned"] = {}  # building type -> {fuel: units}
		_row["power_zero_notes"] = []  # why the power stood at zero with Wood in the stores: a note a minute while it did


## One step of a bot: sample the logistics once a game second, and open Livewire when it begins.
func observe(s) -> void:
	if era == "":
		return
	if era == "ironfall" and s.story.events.has(Data.LIVEWIRE_BEGUN):
		finish(s)
		begin("livewire", s)
	_acc += STEP
	if _acc < SAMPLE:
		return
	_acc -= SAMPLE
	_sample(s)
	ledger.sample(s)
	if era == "livewire":
		_tide(s)


## Close the era: its length and goals done, and the row.
func finish(s) -> Dictionary:
	var row := _row.duplicate(true)
	row["ledger"] = ledger.finish(s)
	row["length_min"] = snappedf((s.seasons.time - _at) / 60.0, 0.1)
	var list := _goals(era)
	var done := 0
	for g in list:
		if s.story.goals_done.has(g["id"]):
			done += 1
	row["goals_done"] = done
	row["goals_total"] = list.size()
	row["ended"] = true  # the driver sets it false for an era whose bot ran out of time
	for key in [
		"hauler_wait_total_s",
		"hauler_wait_longest_s",
		"starved_with_stock_s",
		"starved_longest_s",
		"resting_s",
		"fuel_starved_s"
	]:
		row[key] = snappedf(row[key], 0.1)
	if era == "livewire":
		row["lost_total"] = s.tide.lost
		if row["lost_before_first_scorcher"] < 0:
			row["lost_before_first_scorcher"] = s.tide.lost  # no Scorcher ever burned: everything lost was lost before it
		row["lost_after_first_scorcher"] = s.tide.lost - row["lost_before_first_scorcher"]
	row["end"] = {
		"kith": s.people.kith.size(),
		"stock": _stock(s),
		"coal_in_ground": _coal_in_ground(s),
		"charcoal_pits": _count(s, "charcoal_pit"),
	}
	rows.append(row)
	era = ""
	return row


func _goals(name: String) -> Array:
	match name:
		"stone_age":
			return Data.GOALS
		"bronze_dawn":
			return Data.GOALS_ERA2
		"starfall":
			return Data.GOALS_ERA3
		"ironfall":
			return Data.GOALS_ERA4
	return Data.GOALS_ERA5


func _coal_in_ground(s) -> int:
	var total := 0
	for id in s.world.seam_left:
		total += int(s.world.seam_left[id])
	return total


func _stock(s) -> Dictionary:
	var stock := {}
	for id in Data.ITEM_ORDER:
		if s.economy.inv.get(id, 0) > 0:
			stock[id] = int(s.economy.inv[id])
	return stock


## Who waited on a hauler this second, which workshops stood starved with the input they lack sitting in the stores, who rested
## at a full store, what spilled over the caps, and (every five minutes) the haulers at each depot.
func _sample(s) -> void:
	var waiting := {}
	var starved := {}
	var fuelless := {}
	for b in s.town.buildings:
		var status: String = b["status"]
		if "waiting for a hauler" in status.to_lower():
			waiting[b["pos"]] = "%s: %s" % [b["type"], status]
			_row["hauler_wait_total_s"] += SAMPLE
		if status.begins_with("Store full"):
			_row["resting_s"] += SAMPLE
		if status.begins_with("Needs ") and Buildings.needs_worker(b) and _lacks_stocked(s, b):
			_row["starved_with_stock_s"] += SAMPLE
			starved[b["pos"]] = "%s: %s" % [b["type"], status]
		if _lacks_only_fuel(b) and s.economy.inv.get("wood", 0) > 0:
			_row["fuel_starved_s"] += SAMPLE
			fuelless[b["pos"]] = "%s: %s" % [b["type"], status]
	if s.economy.inv.get("wood", 0) < 10:
		_row["wood_short_s"] += SAMPLE
	_research_wait(s)
	if era == "ironfall" or era == "livewire":
		_queue_and_forges(s)
	_keep_streaks(_streak, waiting, "hauler_wait_longest_s", "hauler_waits")
	_keep_streaks(_starve, starved, "starved_longest_s")
	_keep_streaks(_fuel, fuelless, "fuel_starved_longest_s")
	_count_made_on(s)
	var spilled: int = s.economy.spilled
	_row["spilled"] += spilled - _spill_seen if spilled >= _spill_seen else spilled
	_spill_seen = spilled
	for id in s.economy.spilled_of:
		var more: int = s.economy.spilled_of[id] - _spill_of_seen.get(id, 0)
		if more > 0:
			_row["spilled_by_good"][id] = _row["spilled_by_good"].get(id, 0) + more
	_spill_of_seen = s.economy.spilled_of.duplicate()
	var t: float = s.seasons.time - _at
	if t - _depots_at >= DEPOTS_EVERY:
		_depots_at = t
		_row["depots_every_5_min"].append({"minute": snappedf(t / 60.0, 0.1), "depots": _depots(s)})
	if t - _town_at >= DEPOTS_EVERY:
		_town_at = t
		_row["town_every_5_min"].append(_town(s, t))


## Where the jobs stand: the Kith by what they do, the work places and the ones filled, the buildings that need a worker by type as
## [standing, paused, with a worker], and the buildings the Bloom has overgrown and taken.
func _town(s, t: float) -> Dictionary:
	var kith := {"work": 0, "haul": 0, "none": 0}
	for k in s.people.kith:
		var job: String = k["job"] if k["job"] != "" else "none"
		kith[job] = kith.get(job, 0) + 1
	var by := {}
	for b in s.town.buildings:
		if not Buildings.needs_worker(b):
			continue
		var row: Array = by.get(b["type"], [0, 0, 0])
		row[0] += 1
		row[1] += 1 if b["paused"] else 0
		for slot in Buildings.crew_slots(b):
			row[2] += 1 if b[slot] >= 0 else 0
		by[b["type"]] = row
	return {
		"minute": snappedf(t / 60.0, 0.1),
		"kith": kith,
		"places": Ui.job_slots(s),
		"filled": Ui.jobs_filled(s),
		"buildings": by,
		"overgrown": s.tide.hit.size() if era == "livewire" else 0,
		"lost": s.tide.lost,
	}


## Seconds a tech in the queue stood ready (its requirements met) with its materials not in the stores: what research costs in time.
func _research_wait(s) -> void:
	var tt = s.tech_tree
	if tt.queue.is_empty():
		return
	var head: String = tt.queue[0]
	var head_waits: bool = tt.requirements_met(head) and not s.economy.can_afford(tt.cost_of(head))
	if head_waits:
		_row["research_wait_head_s"] += SAMPLE
		_row["research_wait_by"][head] = _row["research_wait_by"].get(head, 0.0) + SAMPLE
	for tech in tt.queue:
		if tt.can_research(tech):
			return
	_row["research_wait_all_s"] += SAMPLE


## The research queue empty before the era's gate is learned, and a Forge paused while a queued tech lacks Steel: the two ways the
## metal's road has stood still for the bot's own doing.
func _queue_and_forges(s) -> void:
	var gate := "livewire" if era == "ironfall" else "skyward"
	if s.tech_tree.queue.is_empty() and not s.tech_tree.researched.has(gate):
		_row["queue_empty_s"] += SAMPLE
	var lacks := false
	for tech in s.tech_tree.queue:
		if s.tech_tree.cost_of(tech).get("steel", 0) > s.economy.inv.get("steel", 0):
			lacks = true
	if lacks:
		for b in s.town.buildings:
			if b["type"] == "forge" and b["paused"]:
				_row["forge_paused_steel_wanted_s"] += SAMPLE
				break


## Add a second to every building in `now`'s streak in `streaks`, drop the ones that stopped, and keep the longest in `_row[key]`
## (and in `_row[key + "_what"]`, the building's type and status when that streak set it).
## With `count`, each streak that ends adds one to `_row[count]` (waits that ended, for the mean wait per pickup).
func _keep_streaks(streaks: Dictionary, now: Dictionary, key: String, count := "") -> void:
	for p in now:
		streaks[p] = streaks.get(p, 0.0) + SAMPLE
		if streaks[p] > _row[key]:
			_row[key] = streaks[p]
			_row[key + "_what"] = now[p]
	for p in streaks.keys():
		if not now.has(p):
			streaks.erase(p)
			if count != "":
				_row[count] = _row.get(count, 0) + 1


## The haulers each depot has: [{"pos": "x,y", "haulers": n, "wanted": n}]. A town with hauler places (sim.hauling) reads its places
## and what each depot wants; before them the haulers are counted where `_home_depot` stands them, and wanted is -1.
func _depots(s) -> Array:
	var places = s.get("hauling")
	var count := {}
	for k in s.people.kith:
		if k["job"] != "haul":
			continue
		var home: Vector2i = (
			k.get("depot", Vector2i(-1, -1)) if places != null else Haulers._home_depot(s, k, Kith.tile_of(k))
		)
		count[home] = count.get(home, 0) + 1
	var out := []
	for depot in Roads.posts(s):
		var want: int = places.wanted(depot) if places != null else -1
		out.append({"pos": "%d,%d" % [depot.x, depot.y], "haulers": count.get(depot, 0), "wanted": want})
	return out


## Haulers wanted against Kith at work: {"wanted", "at_work", "ratio"}. Zeros before hauler places exist.
func _ratio(s) -> Dictionary:
	var places = s.get("hauling")
	var wanted: int = places.total_wanted() if places != null else 0
	var at_work := 0
	for k in s.people.kith:
		if k["job"] == "work":
			at_work += 1
	return {"wanted": wanted, "at_work": at_work, "ratio": snappedf(float(wanted) / maxf(at_work, 1.0), 0.01)}


## Add what the metal works made on each fuel since the last reading to `_row["made_on_<fuel>"]`.
func _count_made_on(s) -> void:
	for fuel in s.economy.made_on:
		var key: String = "made_on_" + str(fuel)
		for id in s.economy.made_on[fuel]:
			var more: int = s.economy.made_on[fuel][id] - _made_seen.get(fuel, {}).get(id, 0)
			if more > 0:
				_row[key][id] = _row[key].get(id, 0) + more
	_made_seen = s.economy.made_on.duplicate(true)


## True when a Bloomery or Forge (or a Floor copying one) holds the rest of its recipe but not the fuel it burns now.
func _lacks_only_fuel(b: Dictionary) -> bool:
	if not Fuel.burns(b) or b["paused"] or not Buildings.needs_worker(b):
		return false
	var recipe := Buildings.recipe_in(b)
	var fuel: String = b["fuel_now"]
	if b["inbuf"].get(fuel, 0) >= recipe.get(fuel, 1):
		return false
	for id in recipe:
		if id != fuel and b["inbuf"].get(id, 0) < recipe[id]:
			return false
	return true


func _count(s, type: String) -> int:
	var n := 0
	for b in s.town.buildings:
		if b["type"] == type:
			n += 1
	return n


## True when a workshop is short of an input (not in its buffer or on its way) that the stores hold.
func _lacks_stocked(s, b: Dictionary) -> bool:
	var recipe := Buildings.recipe_in(b)
	for id in recipe:
		if b["inbuf"].get(id, 0) + b["incoming"].get(id, 0) < recipe[id] and s.economy.inv.get(id, 0) > 0:
			return true
	return false


## Livewire only: when the tide first stands on a building and first takes one, the buildings lost by minute 15 (-1 when the
## era ended before it), and when a Scorcher first burns (-1 when none did). All minutes are into the era.
func _tide(s) -> void:
	var t: float = s.seasons.time - _at
	if _row["tide_woke_min"] < 0.0 and s.tide.begun:
		_row["tide_woke_min"] = snappedf((s.tide.woke_at - _at) / 60.0, 0.1)
	if _row["first_overgrown_min"] < 0.0 and not s.tide.hit.is_empty():
		_row["first_overgrown_min"] = snappedf(t / 60.0, 0.1)
	if _row["first_lost_min"] < 0.0 and s.tide.lost > 0:
		_row["first_lost_min"] = snappedf(t / 60.0, 0.1)
	while _row["lost_at_min"].size() < s.tide.lost:
		_row["lost_at_min"].append(snappedf(t / 60.0, 0.1))
	if _row["lost_by_15"] < 0 and t >= LOST_BY:
		_row["lost_by_15"] = s.tide.lost
	if _row["lost_within_20_of_wake"] < 0 and s.tide.begun and s.seasons.time - s.tide.woke_at >= WAKE_WINDOW:
		_row["lost_within_20_of_wake"] = s.tide.lost
	if _row["first_scorcher_burn_min"] < 0.0:
		for b in s.town.buildings:
			if b["type"] == "scorcher" and b["burn"] > 0.0:
				_row["first_scorcher_burn_min"] = snappedf(t / 60.0, 0.1)
				_row["lost_before_first_scorcher"] = s.tide.lost
				break
	_row["firebreak_tiles"] = maxi(_row["firebreak_tiles"], _count(s, "firebreak"))
	_power(s)
	if s.tide.begun and t >= _row["pace_every_min"].size() * PACE_EVERY:
		(
			_row["pace_every_min"]
			. append(
				{
					"minute": snappedf(t / 60.0, 0.1),
					"units": s.tide.drawn,
					"seconds_per_tile": snappedf(s.tide.step_seconds(), 0.1),
				}
			)
		)


## Why a net with machines has no power: its engines (type, tile, status, the fuel they burn and hold, paused, worker), the poles,
## and the stock of coal, charcoal and wood.
func _zero_note(s, now: float) -> Dictionary:
	var nets := []
	for n in s.livewire.nets:
		if n["asks"] <= 0 or n["given"] > 0:
			continue
		var engines := []
		for p in n["engines"]:
			if not s.town.building_at.has(p):
				continue
			var b: Dictionary = s.town.buildings[s.town.building_at[p]]
			(
				engines
				. append(
					{
						"type": b["type"],
						"at": "%d,%d" % [p.x, p.y],
						"status": String(b["status"]).substr(0, 70),
						"fuel": b.get("fuel", ""),
						"burning": b.get("fuel_now", ""),
						"held": b["inbuf"].duplicate(),
						"burn": snappedf(b.get("burn", 0.0), 0.1),
						"paused": b["paused"],
						"overgrown": s.tide.is_overgrown_at(p),
					}
				)
			)
		nets.append(
			{"poles": n["poles"].size(), "machines": n["machines"].size(), "asks": n["asks"], "engines": engines}
		)
	var stock := {}
	for id in ["coal", "charcoal", "wood"]:
		stock[id] = s.economy.inv.get(id, 0)
	return {"minute": snappedf(now / 60.0, 0.1), "nets": nets, "stock": stock}


## Livewire only, once the tide is awake: the seconds a net asks for power and no engine gives any while the stores hold Wood (the
## fuel can be made), the longest stretch of it, and the fuel the engines and Scorchers have burnt, by building and kind.
func _power(s) -> void:
	if not s.tide.begun:
		return
	_engines(s)
	_watch_engines(s)
	var zero := false
	for n in s.livewire.nets:
		if n["asks"] > 0 and n["given"] <= 0:
			zero = true
	if zero and s.economy.inv.get("wood", 0) > 0:
		var now: float = s.seasons.time - _at
		if now - _zero_at >= 60.0 and _row["power_zero_notes"].size() < 40:
			_zero_at = now
			_row["power_zero_notes"].append(_zero_note(s, now))
		_row["power_zero_with_wood_s"] += SAMPLE
		_zero_run += SAMPLE
		_row["power_zero_with_wood_longest_s"] = maxf(_row["power_zero_with_wood_longest_s"], _zero_run)
	else:
		_zero_run = 0.0
	for type in s.economy.burnt_by:
		for fuel in s.economy.burnt_by[type]:
			var more: int = s.economy.burnt_by[type][fuel] - _burn_seen.get(type, {}).get(fuel, 0)
			if more > 0:
				var by: Dictionary = _row["fuel_burned"].get(type, {})
				by[fuel] = by.get(fuel, 0) + more
				_row["fuel_burned"][type] = by
	_burn_seen = s.economy.burnt_by.duplicate(true)


## Livewire only: for each engine (Boiler, Generator, Wheel), Arc Lamp, Scorcher and Pole the tide stands on, what held it
## or did not, read every sample while it is overgrown: the nearest Arc Lamp (distance, its light, whether it is powered and
## overgrown itself), the nearest Scorcher (distance, burning, powered, overgrown), whether the game counts the tile held, and the
## first Tide Watch warning (seconds ahead of the front, with the minute it came). When the building goes, the last reading becomes
## an `engine_losses` entry.
func _watch_engines(s) -> void:
	var t: float = s.seasons.time - _at
	var watch: Dictionary = _row["engine_watch"]
	for b in s.town.buildings:
		if Data.BUILDINGS[b["type"]]["kind"] not in WATCHED:
			continue
		var key := "%d,%d" % [b["pos"].x, b["pos"].y]
		var seen: Dictionary = watch.get(key, {})
		if not seen.has("first_eta_s") and s.tide.eta.has(b["pos"]):
			seen["first_eta_s"] = snappedf(s.tide.eta[b["pos"]] - s.tide.time, 1.0)
			seen["first_eta_at_min"] = snappedf(t / 60.0, 0.1)
		if s.tide.hit.has(b["pos"]):
			if not seen.has("overgrown_at_min"):
				seen["overgrown_at_min"] = snappedf(t / 60.0, 0.1)
			seen["reading"] = _hold_reading(s, b["pos"])
			seen["type"] = b["type"]
			seen["at_min"] = snappedf(t / 60.0, 0.1)
		if not seen.is_empty():
			watch[key] = seen
	for key in watch.keys():
		var xy: PackedStringArray = key.split(",")
		var p := Vector2i(int(xy[0]), int(xy[1]))
		var standing: bool = s.town.building_at.has(p) and Data.BUILDINGS[s.town.built_type(p)]["kind"] in WATCHED
		if not standing:
			if watch[key].has("reading"):
				var entry: Dictionary = watch[key].duplicate(true)
				entry["pos"] = key
				entry["lost_at_min"] = snappedf(t / 60.0, 0.1)
				_row["engine_losses"].append(entry)
			watch.erase(key)


## What covered tile p this sample: the lamp and Scorcher nearest to it and whether the game held the tile.
func _hold_reading(s, p: Vector2i) -> Dictionary:
	var lamp := {}
	var fire := {}
	var lit := 0
	var burning := 0
	for b in s.town.buildings:
		var kind: String = Data.BUILDINGS[b["type"]]["kind"]
		var d := Vector2(b["pos"]).distance_to(Vector2(p))
		if kind == "arc_lamp":
			var light: float = Data.BUILDINGS[b["type"]]["light"]
			var here := {
				"d": snappedf(d, 0.1),
				"light": light,
				"powered": s.town.is_powered(b["pos"]),
				"overgrown": s.tide.hit.has(b["pos"])
			}
			if here["powered"] and not here["overgrown"]:
				lit += 1
			if lamp.is_empty() or d < lamp["d"]:
				lamp = here
		elif kind == "scorcher":
			var here := {
				"d": snappedf(d, 0.1),
				"burning": b["burn"] > 0.0,
				"powered": s.town.is_powered(b["pos"]),
				"overgrown": s.tide.hit.has(b["pos"])
			}
			if here["burning"]:
				burning += 1
			if fire.is_empty() or d < fire["d"]:
				fire = here
	return {
		"held": s.tide.is_held_at(s, p),
		"lamp": lamp,
		"scorcher": fire,
		"scorch_reach": Data.SCORCH_REACH,
		"lamps_lit": lit,
		"scorchers_burning": burning,
		"coal": s.economy.inv.get("coal", 0),
		"given": s.livewire.nets.map(func(n): return [n["given"], n["asks"]]),
	}


## Engines standing, and (once a Scorcher stands) how little power the nets gave: the edge each win is won on.
func _engines(s) -> void:
	var engines := 0
	for b in s.town.buildings:
		if Data.BUILDINGS[b["type"]]["kind"] == "power":
			engines += 1
	if engines >= _row["engines_peak"]:
		_row["engines_peak"] = engines
		_row["engines_min_after_peak"] = engines
		if _row["engines_dipped"]:
			_row["engine_lost_and_back"] = true
			_row["engines_dipped"] = false
	elif engines < _row["engines_min_after_peak"]:
		_row["engines_min_after_peak"] = engines
		_row["engines_dipped"] = true
	elif engines < _row["engines_peak"]:
		_row["engines_dipped"] = true
	if _count(s, "scorcher") == 0:
		return
	var given := 0
	var asks := 0
	for n in s.livewire.nets:
		given += n["given"]
		asks += n["asks"]
	if _row["power_given_min_after_scorcher"] < 0 or given < _row["power_given_min_after_scorcher"]:
		_row["power_given_min_after_scorcher"] = given
	if asks > 0:
		var share := snappedf(float(given) / float(asks), 0.01)
		if _row["power_share_min_after_scorcher"] < 0.0 or share < _row["power_share_min_after_scorcher"]:
			_row["power_share_min_after_scorcher"] = share


## The probe as plain data (and back), so a long run can be kept and picked up: the rows so far and the era in progress.
func to_dict() -> Dictionary:
	return {"rows": rows, "era": era, "row": _row, "at": _at, "ledger": ledger.to_dict()}


func from_dict(d: Dictionary) -> void:
	rows = d["rows"]
	era = d["era"]
	_row = d["row"]
	_at = d["at"]
	if d.has("ledger") and d["ledger"]["era"] != "":
		ledger.from_dict(d["ledger"])
	_acc = 0.0
	_streak.clear()
	_starve.clear()
	_fuel.clear()
	_made_seen = {}  # Economy.made_on is not saved either, so a resumed run counts from 0
	_burn_seen = {}
	_zero_run = 0.0
	_spill_seen = 0  # a reloaded run starts Economy.spilled again from 0
	_spill_of_seen = {}
	_depots_at = _row["depots_every_5_min"].size() * DEPOTS_EVERY if _row.has("depots_every_5_min") else 0.0
	_town_at = _row["town_every_5_min"].size() * DEPOTS_EVERY if _row.has("town_every_5_min") else 0.0
	_zero_at = -1000.0
