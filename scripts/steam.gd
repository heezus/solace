extends RefCounted
## Ironfall stage 3: the fire (design-system/19-ironfall.md). The buildings haulers feed and that burn what they are given on
## their own (the Boiler, the Shard Boiler, the Shard Lamp, the Beast Pen: a building with `fed` in Data.BUILDINGS), and the
## Steam Cart that burns coal for its trips. The numbers and words are in scripts/data/steam.gd. Static, and works on the Sim
## passed in. A fed building's `burn` is seconds left on what it was given (a Pen's, seconds until the next Grain is eaten).

const Data = preload("res://scripts/data.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Power = preload("res://scripts/power.gd")

# --- The fed buildings ---------------------------------------------------------------------------------------------


## One tick at a fed building: it burns, takes the next of what it burns from its store, and says how it stands.
static func tick_fed(s, b: Dictionary, delta: float) -> void:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	match def["kind"]:
		"power":
			_tick_boiler(s, b, def, delta)
		"lamp":
			_tick_lamp(s, b, def, delta)
		"pen":
			_tick_pen(s, b, def, delta)


## The item a fed building burns (the one in its `in`).
static func fuel_of(def: Dictionary) -> String:
	return def["in"].keys()[0]


## Take one of the fuel from the building's store. False when it has none.
static func _take(s, b: Dictionary, def: Dictionary) -> bool:
	var id := fuel_of(def)
	if b["inbuf"].get(id, 0) < 1:
		return false
	b["inbuf"][id] -= 1
	s.economy.note(id, -1, b["type"])
	return true


## A Boiler lights when a machine in its reach wants power, or the net it stands on is asked for more than its engines give, and
## burns one fuel for def["burn"] seconds; lit, it burns down whether or not the machine is still working. With no fuel it stays
## cold and says so. A Generator is the same, and reaches no tiles of its own: it feeds a net.
static func _tick_boiler(s, b: Dictionary, def: Dictionary, delta: float) -> void:
	var fuel: String = Data.ITEMS[fuel_of(def)]["name"]
	b["burn"] = maxf(b["burn"] - delta, 0.0)
	var wanted := machines_want(s, b) or Power.wants(s, b)
	if b["burn"] <= 0.0 and wanted and _take(s, b, def):
		b["burn"] = def["burn"]
		Power.lit(s, b)
	var stored: int = b["inbuf"].get(fuel_of(def), 0)
	if b["burn"] > 0.0:
		b["status"] = Data.BOILER_LIT % [ceili(b["burn"]), stored]
	elif wanted:
		b["status"] = Data.BOILER_COLD % fuel
		b["alert"] = "Needs " + fuel
	elif def["radius"] <= 0.0:
		b["status"] = Data.NET_BANKED % stored if not s.livewire.net_at(b["pos"]).is_empty() else Data.NET_NONE
	else:
		b["status"] = Data.BOILER_BANKED % stored


## True when a machine within the Boiler's reach that needs power would work if it had it: it has a worker, its inputs and room.
static func machines_want(s, boiler: Dictionary) -> bool:
	var reach: float = Data.BUILDINGS[boiler["type"]]["radius"]
	for o in s.town.buildings:
		if not Data.BUILDINGS[o["type"]].get("needs_power", false) or o["paused"] or not Buildings.is_staffed(o):
			continue
		if Vector2(o["pos"]).distance_to(Vector2(boiler["pos"])) <= reach and s.town.wants_power(o):
			return true
	return false


## A Shard Lamp burns one Shard for def["burn"] seconds, one after another, for as long as it is given Shards.
static func _tick_lamp(s, b: Dictionary, def: Dictionary, delta: float) -> void:
	b["burn"] = maxf(b["burn"] - delta, 0.0)
	if b["burn"] <= 0.0 and _take(s, b, def):
		b["burn"] = def["burn"]
	if b["burn"] > 0.0:
		b["status"] = Data.LAMP_LIT % [ceili(b["burn"]), b["inbuf"].get(fuel_of(def), 0)]
	else:
		b["status"] = Data.LAMP_DARK
		b["alert"] = "Needs Shard"


## A Beast Pen eats one Grain every Data.BEAST_EAT seconds of taming, until the beast is tame (Data.BEAST_TAME seconds).
static func _tick_pen(s, b: Dictionary, def: Dictionary, delta: float) -> void:
	if Buildings.is_tamed(b):
		b["status"] = Data.PEN_TAMED
		return
	if b["burn"] <= 0.0 and _take(s, b, def):
		b["burn"] = Data.BEAST_EAT
	if b["burn"] > 0.0:
		var step := minf(delta, b["burn"])
		b["burn"] -= step
		b["progress"] = minf(b["progress"] + step, Data.BEAST_TAME)
	b["status"] = Data.PEN_TAMING % [roundi(b["progress"] / Data.BEAST_TAME * 100.0), b["inbuf"].get("grain", 0)]
	if b["burn"] <= 0.0:
		b["alert"] = "Needs Grain"


# --- The Steam Cart ------------------------------------------------------------------------------------------------


## True when Steam Cart k can have steam up for its next trip: it has trips left on the Coal it burned, or the stockpile has one.
static func can_stoke(s, k: Dictionary) -> bool:
	return k["fire"] > 0 or s.economy.inv.get("coal", 0) >= 1


## The Steam Cart sets out on a trip: it burns 1 Coal for every Data.STEAM_TRIPS trips.
static func stoke(s, k: Dictionary) -> void:
	if k["fire"] <= 0:
		if not s.economy.try_pay({"coal": 1}):
			return
		s.economy.note("coal", -1, "steam_shed")
		k["fire"] = Data.STEAM_TRIPS
	k["fire"] -= 1


## The status of a building with no worker and nothing to burn: a Steam Shed says when its cart has no Coal, the rest say their own.
static func shed_status(s, def: Dictionary) -> String:
	if def.get("cart", "") == "steam" and s.economy.inv.get("coal", 0) < 1:
		return Data.STEAM_COLD
	return def.get("status", def["desc"])


# --- The lamps -------------------------------------------------------------------------------------------------------


## True while any Shard Lamp burns.
static func lamp_lit(s) -> bool:
	for b in s.town.buildings:
		if Data.BUILDINGS[b["type"]]["kind"] == "lamp" and b["burn"] > 0.0:
			return true
	return false


## True when tile p lies within the light of a burning Shard Lamp.
static func lit_at(s, p: Vector2i) -> bool:
	for b in s.town.buildings:
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		if def["kind"] == "lamp" and b["burn"] > 0.0 and Vector2(b["pos"]).distance_to(Vector2(p)) <= def["light"]:
			return true
	return false


## How long an expedition has before dusk: the day, and past it with the Sap Lesson learned and a Shard Lamp burning (a Lantern Party).
static func daylight(s) -> float:
	if s.teardown.knows("sap") and lamp_lit(s):
		return Data.DAYLIGHT_SECONDS * Data.LANTERN_DAYLIGHT
	return Data.DAYLIGHT_SECONDS
