extends RefCounted
## The endings of a telling (Step 7, design-system/18-roadmap.md "Endings as built"): which of the three the Lumen lean opens, and
## the records an ending leaves in the profile. Exodus is always open, the Cataclysm needs the Lumen as enemies and the Time loop
## needs them as allies. The words are in Data.ENDINGS. Static, and works on the Sim passed in, like Roads and Workers.
## `telling` is the Chronicle's record of a run (its number, map seed, the small Starfall choices, the lean, the trust and the
## ending, and the Chronicle's numbers, small map and Embers: scripts/chronicle.gd); `handoff` is what the next run is made from
## (scripts/carry.gd reads it): the seed it uses, the trust it begins at and, after a Cataclysm,
## the ruins and the dormant Bloom patches (scripts/ruins.gd).

const Chronicle = preload("res://scripts/chronicle.gd")
const Data = preload("res://scripts/data.gd")
const Ruins = preload("res://scripts/ruins.gd")


## True when the lean `lean` ("allies", "neighbours", "enemies" or "") opens `ending`.
static func is_open(ending: String, lean: String) -> bool:
	var need: String = Data.ENDINGS[ending]["lean"]
	return need == "" or need == lean


## Why `ending` is shut at `lean`, in words: "" when it is open.
static func why_locked(ending: String, lean: String) -> String:
	if is_open(ending, lean):
		return ""
	return Data.ENDINGS["needs_" + Data.ENDINGS[ending]["lean"]]


## True once the true endings show on the card: the marks of The Way Out are read in this run (the old set only allies may read) and
## the Lumen still stand as allies (Step 8B).
static func way_open(s) -> bool:
	return s.story.has_event("way_read") and s.starfall.lean == "allies"


## Why the true ending `ending` ("seal", "heal" or "leave") is shut in the run `s`, in words: "" when it is open.
static func true_why(ending: String, s) -> String:
	if not way_open(s):
		return Data.ENDINGS["needs_way"]
	var need: String = Data.ENDINGS[ending]["needs"]
	if need != "" and not s.carry.has_reached(need):
		return Data.ENDINGS["needs_" + need]
	return ""


## True when the true ending `ending` is open in the run `s`.
static func true_open(ending: String, s) -> bool:
	return true_why(ending, s) == ""


## True for one of the true endings.
static func is_true(ending: String) -> bool:
	return ending in Data.ENDINGS["true_order"]


## The record of the run in `s` (a Sim) that ends in `ending`.
static func telling(s, ending: String) -> Dictionary:
	var choices := []
	for id in Data.ENDINGS["choices"]:
		if s.story.has_event(id):
			choices.append(id)
	var record := {
		"run": s.carry.exodus + 1,
		"seed": s.world.map_seed,
		"choices": choices,
		"lean": s.starfall.lean,
		"trust": snappedf(s.starfall.trust, 0.1),
		"ending": ending,
		"minutes": snappedf(s.seasons.time / 60.0, 0.1),
		"kin": s.people.kith.size(),
		"buildings": s.town.buildings.size(),
		"lost": s.tide.lost,
		"embers": Chronicle.embers_of(s),
		"map": Chronicle.map_of(s),
	}
	var eras: Array = s.story.era_minutes(s.seasons.time / 60.0)
	if not eras.is_empty():
		record["eras"] = eras  # minutes in each era reached, the stone age first
	return record


## What the next run is made from, after `ending`: its seed (the Cataclysm keeps the map), the trust the run ended at, the lean
## and, for the Cataclysm, the ruins and the dormant Bloom patches.
static func handoff(s, ending: String) -> Dictionary:
	var out := {
		"ending": ending,
		"seed": s.world.map_seed,
		"lean": s.starfall.lean,
		"trust": snappedf(s.starfall.trust, 0.1),
		"ruins": [],
		"patches": [],
	}
	if ending == "cataclysm":
		var ruins := Ruins.of(s)
		out["ruins"] = ruins
		out["patches"] = Ruins.patches_of(s, ruins)
	return out
