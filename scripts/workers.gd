extends RefCounted
## Building workers (design-system/14-hands-to-haulers.md). A worker walks to their building. A hut's
## worker walks out to a resource tile the Kith know and brings back a bundle: to the stockpile, one
## trip per click, before Paths & Haulers; into the hut, over and over, after it. Clicking a building
## sends a trip, or rushes it. Each building also takes its own turn here every tick (tick_building), with
## the timing and yield in scripts/work.gd. Static, and works on the Sim passed in.

const Data = preload("res://scripts/data.gd")
const Kith = preload("res://scripts/kith.gd")
const Roads = preload("res://scripts/roads.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Work = preload("res://scripts/work.gd")
const Hands = preload("res://scripts/hands.gd")
const GrowthNote = preload("res://scripts/growth_note.gd")
const Steam = preload("res://scripts/steam.gd")


## One step of a worker's day at their building.
static func tick(s, k: Dictionary, delta: float) -> void:
	var b: Dictionary = s.town.buildings[k["building"]]
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	match k["phase"]:
		"to_site":
			if k["path"].is_empty() and Kith.tile_of(k) != b["pos"] and not s.people.walk_to(k, b["pos"]):
				b["unreachable"] = 1.0
				return
			if s.people.step(k, delta):
				k["phase"] = "home"
		"home":
			if def["kind"] != "gatherer" or Buildings.buffered(b["out"]) >= Data.BUFFER_CAP:
				return
			if not Roads.automated(s, b) and b["trips"] <= 0:
				return  # waits for a click
			var target := next_gather_tile(s, k, b)
			if target.x < 0:
				return  # nothing here it knows how to gather yet
			if Roads.automated(s, b):
				k["trip"] = false
			else:
				s.people.start_trip(k)
			k["task"] = {"tile": target}
			k["phase"] = "to_tile"
		"to_tile":
			if s.people.step(k, delta):
				k["phase"] = "harvest"
		"harvest":
			var tile: Vector2i = k["task"].get("tile", b["pos"])
			k["timer"] += delta
			if k["timer"] >= Work.harvest_time(s, b, tile):
				_finish_harvest(s, k, b, tile)
		"to_home":
			if s.people.step(k, delta):
				_deliver(s, k, b)
				k["phase"] = "home"
		"to_depot":
			if s.people.step(k, delta):
				_deliver(s, k, b)
				s.people.walk_to(k, b["pos"])
				k["phase"] = "to_site"


## The worker has gathered a bundle at `tile`: carry it to the stockpile on a trip, or home to the hut.
static func _finish_harvest(s, k: Dictionary, b: Dictionary, tile: Vector2i) -> void:
	k["timer"] = 0.0
	var item := tile_item(s, b, tile)
	if item == "":  # the tile changed while they worked (a road cut through it): nothing to bring
		k["task"] = {}
		s.people.walk_to(k, b["pos"])
		k["phase"] = "to_home"
		return
	k["carry"] = {item: Work.harvest_amount(s, b, tile, item)}
	s.people.wear(b)
	k["task"] = {}
	if k["trip"] and s.people.walk_to(k, s.people.nearest_depot(b["pos"])):
		k["phase"] = "to_depot"
	else:
		k["trip"] = false  # no way to the stockpile: leave it in the hut for a click to collect
		s.people.walk_to(k, b["pos"])
		k["phase"] = "to_home"


## What a hut gathers at `tile`.
static func tile_item(s, _b: Dictionary, tile: Vector2i) -> String:
	return Data.TILES[s.world.tile_at(tile)]["yields"]


## Put down what a hut worker carries: into the stockpile at the end of a trip, else into the hut.
static func _deliver(s, k: Dictionary, b: Dictionary) -> void:
	for id in k["carry"]:
		if k["trip"]:
			s.economy.add(id, k["carry"][id])
		else:
			b["out"][id] = b["out"].get(id, 0) + k["carry"][id]
		s.economy.flows.add(id, k["carry"][id], b["type"])
	k["carry"] = {}
	if k["trip"]:
		b["trips"] = maxi(b["trips"] - 1, 0)
	k["trip"] = false


## The next tile in the hut's rotation among those that hold its focus (a hut works one resource), or
## Vector2i(-1, -1) when there's nothing: the focus isn't learned yet, none is in reach, or none can be
## walked to.
static func next_gather_tile(s, k: Dictionary, b: Dictionary) -> Vector2i:
	if not s.people.knows_focus(b):
		return Vector2i(-1, -1)
	var tiles: Array = s.town.focus_tiles(b)
	for _attempt in tiles.size():
		var t: Vector2i = tiles[b["gather_index"] % tiles.size()]
		b["gather_index"] += 1
		if s.people.walk_to(k, t):
			return t
	return Vector2i(-1, -1)


# --- Clicking buildings ------------------------------------------------------


## A click on building i. Before Paths & Haulers a hut sends out a trip and a workshop is loaded and
## emptied by hand; a working building is also rushed. Returns a short note for the map, or "".
static func click(s, i: int, full := false) -> String:
	var b: Dictionary = s.town.buildings[i]
	var kind: String = Data.BUILDINGS[b["type"]]["kind"]
	if not Buildings.needs_worker(b):
		return ""
	if not Roads.automated(s, b):
		var held: int = Buildings.buffered(b["out"])
		s.town.haul(i)
		if kind == "gatherer":
			var note := dispatch(s, i, full)
			return note if held == 0 else "+%d · %s" % [held, note]
	if rush(s, i):
		return "Rushed!"
	if b["rush_cd"] > 0.0:
		return "Rush in %d s" % ceili(b["rush_cd"])
	return ""


## Queue one trip at hut i (up to Data.TRIP_QUEUE). With `full`, a hut with nothing waiting gets all of them, so one
## click from the player sends the Kith out for a whole round. Returns what happened, for the map.
static func dispatch(s, i: int, full := false) -> String:
	var b: Dictionary = s.town.buildings[i]
	if not s.people.knows_focus(b):
		return "Nothing learned yet: %s" % teach_note(s, b)
	if b["trips"] >= Data.TRIP_QUEUE:
		return "Trips full (%d)" % Data.TRIP_QUEUE
	b["trips"] = Data.TRIP_QUEUE if full and b["trips"] == 0 else b["trips"] + 1
	return "Trip%s %d/%d" % ["s" if full and b["trips"] == Data.TRIP_QUEUE else "", b["trips"], Data.TRIP_QUEUE]


## What a hut needs before it can work: its focus taught by hand, or something in reach to focus on.
static func teach_note(s, b: Dictionary) -> String:
	if b["focus"] == "":
		return "nothing in reach to gather"
	return "gather %s by hand %dx to teach it" % [Data.ITEMS[b["focus"]]["name"], Hands.learn_needed(s)]


## True while building b is partway through a cycle that a rush can finish.
static func can_rush(s, b: Dictionary) -> bool:
	if b["rush_cd"] > 0.0 or b["paused"] or not Buildings.is_staffed(b):
		return false
	match Data.BUILDINGS[b["type"]]["kind"]:
		"gatherer":
			return s.people.kith[b["worker"]]["phase"] in ["to_tile", "harvest", "to_home", "to_depot"]
		"processor":
			return b["status"] == "Working"
	return false


## Finish building i's current cycle now: a workshop makes its goods, a hut worker is back home with
## the bundle put away. Then it can't be rushed for Data.RUSH_COOLDOWN seconds.
static func rush(s, i: int) -> bool:
	var b: Dictionary = s.town.buildings[i]
	if not can_rush(s, b):
		return false
	b["rush_cd"] = Data.RUSH_COOLDOWN
	s.rushes += 1
	if Data.BUILDINGS[b["type"]]["kind"] == "processor":
		Work.finish_cycle(s, b)
		return true
	var k: Dictionary = s.people.kith[b["worker"]]
	if k["phase"] in ["to_tile", "harvest"]:
		var tile: Vector2i = k["task"].get("tile", b["pos"])
		var item := tile_item(s, b, tile)
		if item != "":  # "" when a road felled or cut the tile away under them: nothing to bring
			k["carry"] = {item: Work.harvest_amount(s, b, tile, item)}
			s.people.wear(b)
	_deliver(s, k, b)
	k["task"] = {}
	k["path"] = []
	k["timer"] = 0.0
	k["pos"] = Vector2(b["pos"])
	k["phase"] = "home"
	return true


# --- A building's own turn ---------------------------------------------------------


## One tick at building b: what it is doing (its status text) and, for a workshop, its cycle. A building
## with no worker, or a hungry, cut-off or unpowered one, only reports why it stands still.
static func tick_building(s, b: Dictionary, delta: float, fed: bool) -> void:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	b["alert"] = ""
	if not Buildings.needs_worker(b):
		if def.get("fed", false):
			Steam.tick_fed(s, b, delta)  # a Boiler, a Lamp or a Pen has no worker: it burns what haulers bring it
			if b["alert"] != "":
				b["status"] += road_note(s, b)  # hungry and unlinked: haulers cannot bring it anything
		else:
			b["status"] = Steam.shed_status(s, def)
		return
	if def.has("makes"):
		Work.choose_tool(s, b)
	if b["paused"]:
		s.town.set_status(b, "Paused: its %s is free for other jobs" % s.people.building_job(b), "Paused")
		return
	if not Buildings.is_staffed(b):
		s.town.set_status(
			b, GrowthNote.waiting_for_kith(s, s.people.building_job(b)), "Idle: no free %s" % Data.PEOPLE["one"]
		)
		return
	if not fed:
		s.town.set_status(b, "Hungry: bring food (berries, fish or flour)", "Hungry: no food")
		return
	if b["unreachable"] > 0.0:
		s.town.set_status(b, "Cut off by water: build a Wooden Bridge (Paths & Haulers)", "Cut off: needs a bridge")
		return
	if def.get("needs_power", false) and not s.town.is_powered(b["pos"]):
		var how: String = (
			Data.NO_POWER_STATUS if s.tech_tree.researched.has("boiler") else "No power: build a Water Wheel nearby"
		)
		s.town.set_status(b, how, "No power")
		return
	if not s.people.worker_home(b):
		b["status"] = "%s walking here" % s.people.title_of(s.people.kith[b["worker"]])
		return
	if s.livewire.is_held(b) and b["progress"] <= 0.0:
		s.town.set_status(b, Data.ORDER_PAUSED_STATUS, Data.ORDER_PAUSED_ALERT)  # a standing order: the job is done, so it waits
		return
	if Work.enough(s, b):
		b["status"] = Work.bench_text(s, b)
		return
	if not s.town.wants_to_work(b):
		idle_reason(s, b, def)
		return
	if def["kind"] == "gatherer":
		var k: Dictionary = s.people.kith[b["worker"]]
		match k["phase"]:
			"to_tile":
				b["status"] = "Walking out to gather"
			"to_home" when k["carry"].is_empty():
				b["status"] = "Walking home"
			"to_home":
				b["status"] = "Carrying %s home" % Data.ITEMS[k["carry"].keys()[0]]["name"]
			"to_depot":
				b["status"] = "Carrying %s to the stockpile" % Data.ITEMS[k["carry"].keys()[0]]["name"]
			"forage_out", "forage_pick", "forage_back":
				b["status"] = Data.FORAGE_STATUS
			"home":
				if not s.people.knows_focus(b):
					b["status"] = "Can't work it yet: " + teach_note(s, b)
				elif not Roads.automated(s, b) and b["trips"] <= 0:
					b["status"] = "Waiting: click to send a trip" + road_note(s, b)
				else:
					b["status"] = "Working"
			_:
				b["status"] = "Working"
		return
	var speed: float = s.livewire.speed_of(b)  # 1.0 unless it is on a Power Pole net that is short
	b["status"] = "Working" if speed >= 1.0 else Data.NET_SLOW % roundi(speed * 100.0)
	b["progress"] += delta * speed
	if b["progress"] < Work.time(s, b):
		return
	Work.finish_cycle(s, b)


# --- Status ----------------------------------------------------------------------


## Why a staffed building is standing still: full, or short of an input.
static func idle_reason(s, b: Dictionary, def: Dictionary) -> void:
	var auto := Roads.automated(s, b)
	if Buildings.buffered(b["out"]) >= Data.BUFFER_CAP:
		if auto:
			s.town.set_status(b, "Full: waiting for a hauler", "Full: waiting for a hauler")
		else:
			s.town.set_status(b, "Full: click to collect" + road_note(s, b), "Full: click to collect")
		return
	if def.get("trade", false) and not Buildings.is_trading(b):
		s.town.set_status(b, Data.TRADE_UNSET, Data.TRADE_UNSET_ALERT)
		return
	if def.has("dig") and s.world.seam_spent(b["pos"]):
		s.town.set_status(b, Data.SEAM_SPENT_STATUS, Data.SEAM_SPENT_ALERT)
		return
	var missing: Array = []
	var recipe := Buildings.recipe_in(b)
	for id in recipe:
		if b["inbuf"].get(id, 0) < recipe[id]:
			missing.append(Data.ITEMS[id]["name"])
	if missing.is_empty():
		b["status"] = "Idle"
		return
	var how := "waiting for a hauler" if auto else "click to load" + road_note(s, b)
	if auto:
		for id in recipe:
			if b["inbuf"].get(id, 0) + b["incoming"].get(id, 0) < recipe[id] and s.economy.inv.get(id, 0) == 0:
				how = "stockpile is out"
	var more := "" if auto else GrowthNote.hint(s)
	s.town.set_status(
		b,
		"Needs %s (%s)" % [", ".join(missing), how] + (". " + more if more != "" else ""),
		"Needs " + ", ".join(missing)
	)


## After Paths & Haulers, what a building with no road link needs: "" once it's linked (or before).
static func road_note(s, b: Dictionary) -> String:
	if not s.tech_tree.researched.has("haulers") or Roads.linked(s, b):
		return ""
	return ". Needs road: " + road_hint(s, b["pos"])


## "lay Road from here to the Hearth (4 tiles), then haulers carry for it".
static func road_hint(s, p: Vector2i) -> String:
	var g := Roads.gap(s, p)
	if g["to"].x < 0:
		return "linked by road"
	var what := "the road to the Hearth" if s.world.roads.has(g["to"]) else "the Hearth"
	if s.town.building_at.has(g["to"]) and g["to"] != s.world.camp_pos:
		what = "the Storehouse"
	return "lay Road from here to %s (about %d tiles) so haulers carry for it" % [what, g["tiles"]]
