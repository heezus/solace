extends RefCounted
## Fuel for the metal works (design-system/31-fuel.md): a Bloomery or a Forge (or a Factory Floor copying one) burns one Coal or one
## Charcoal a batch. Coal runs the batch at its normal time; Charcoal takes Data.CHARCOAL_SLOW times as long, so running out of
## Coal slows the metal and never stops it. Each has a fuel setting, "auto" (the default), "coal" or "charcoal"; `fuel_now` is
## the fuel it burns at this moment (kept by `update` once a tick, so the hauler's pick and the work cycle agree). Static, like Work.

const Data = preload("res://scripts/data.gd")


## True for a building that burns fuel: a Bloomery or Forge, or a Floor set to copy one.
static func burns(b: Dictionary) -> bool:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if def.get("fuel", false):
		return true
	return def.has("floor") and Data.BUILDINGS.get(b["make"], {}).get("fuel", false)


## The setting a new fuel burner starts with, and the fuel it starts on.
static func fresh(b: Dictionary) -> void:
	b["fuel"] = "auto"
	b["fuel_now"] = "coal"


## The fuel `b` burns now: its setting, or for Auto the Coal the stores can spare, else Charcoal. A fuel it holds or has on the way
## stays its fuel, so what a hauler brought is burnt before the choice is made again.
static func choose(economy, b: Dictionary) -> String:
	var mode: String = b.get("fuel", "auto")
	if mode != "auto":
		return mode
	for id in ["coal", "charcoal"]:
		if b["inbuf"].get(id, 0) + b["incoming"].get(id, 0) >= 1:
			return id
	var coal: int = economy.inv.get("coal", 0)
	if coal > Data.FUEL_RESERVE:
		return "coal"
	if economy.inv.get("charcoal", 0) > 0:
		return "charcoal"
	return "coal" if coal > 0 else "charcoal"  # nothing but a little coal in the stores: burn it before waiting on the Pits


## Settle `fuel_now` for building `b` (a fuel burner).
static func update(s, b: Dictionary) -> void:
	b["fuel_now"] = choose(s.economy, b)


## The inputs of a cycle with the fuel swapped in: `recipe` with its Coal taken as the fuel the building burns now.
static func swap(b: Dictionary, recipe: Dictionary) -> Dictionary:
	if b.get("fuel_now", "coal") == "coal" or not recipe.has("coal"):
		return recipe
	var out := recipe.duplicate()
	out["charcoal"] = out["coal"]
	out.erase("coal")
	return out


## How many times as long a cycle takes at `b`: 1 on Coal, Data.CHARCOAL_SLOW on Charcoal.
static func slow(b: Dictionary) -> float:
	return Data.CHARCOAL_SLOW if b.get("fuel_now", "coal") == "charcoal" and burns(b) else 1.0


## "Smelting on Charcoal: half speed (Coal is low)" while `b` burns Charcoal, "" on Coal.
static func status(b: Dictionary) -> String:
	if slow(b) == 1.0:
		return ""
	var type: String = b["type"] if not Data.BUILDINGS[b["type"]].has("floor") else b["make"]
	var verb: String = Data.FUEL_VERB.get(type, Data.FUEL_VERB_DEFAULT)
	return (Data.FUEL_STATUS_AUTO if b.get("fuel", "auto") == "auto" else Data.FUEL_STATUS_SET) % verb


## The card's line: what it burns now, and the Auto reserve.
static func line(b: Dictionary) -> String:
	var name: String = Data.ITEMS[b.get("fuel_now", "coal")]["name"]
	if b.get("fuel", "auto") == "auto":
		return Data.FUEL_LINE_AUTO % [name, Data.FUEL_RESERVE]
	return Data.FUEL_LINE_SET % name


## Step fuel burner `b` to its next setting (Auto, Coal, Charcoal, around).
static func cycle(economy, b: Dictionary) -> void:
	set_mode(economy, b, next_mode(b["fuel"]))


## Set fuel burner `b` to `mode`. What it held of the fuel it no longer burns goes back to the stockpile, and a cycle under way
## starts again.
static func set_mode(economy, b: Dictionary, mode: String) -> void:
	b["fuel"] = mode
	b["fuel_now"] = choose(economy, b)
	for id in ["coal", "charcoal"]:
		if id != b["fuel_now"] and b["inbuf"].get(id, 0) > 0:
			economy.give_back(id, b["inbuf"][id])
			b["inbuf"].erase(id)
			b["progress"] = 0.0


## The next setting after `mode` (Auto, Coal, Charcoal, around).
static func next_mode(mode: String) -> String:
	return Data.FUEL_MODES[(Data.FUEL_MODES.find(mode) + 1) % Data.FUEL_MODES.size()]
