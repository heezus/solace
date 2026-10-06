extends RefCounted
## The run save: everything one run of the game holds, written as JSON-safe values and read back into a
## Sim, so a loaded game goes on exactly as the saved one would have. Each block writes and reads its
## own state (to_dict / from_dict); this is the one place that gathers them, plus the few fields Sim
## keeps for itself (the win flag, hand tools, hand counts, the held harvest, rushes, ranks, the message queue).
## Static, and works on the Sim passed in, like Hands and Ranks.
##
## What is not saved because it is derived: the walking grid (rebuilt from the map and the techs), the road
## network cache (rebuilt when Roads next needs it) and the `building_at` index (rebuilt from the list).
## What is not here on purpose: the profile (scripts/profile.gd) holds what outlives a run, and a run save
## holds none of it (the story ids in a run save are that run's own story, not the profile's Chronicle).
##
## The top-level keys are VERSION (an int) and one entry per block: "game", "world", "fog", "economy",
## "research", "buildings", "kith" and "story". A save with another version is refused, never guessed at.
## Write it with to_json(), which keeps dictionary order and full float precision: the order of the roads,
## of a building's goods and of the techs can decide who is served first.

const Codec = preload("res://scripts/save_codec.gd")
const Data = preload("res://scripts/data.gd")

const VERSION := 1
const PATH := "user://run.json"
const SECTIONS := ["game", "world", "fog", "economy", "research", "buildings", "kith", "story"]


## Everything in `s` as a Dictionary of JSON-safe values (copies: later play doesn't change it).
static func dump(s) -> Dictionary:
	return {
		"version": VERSION,
		"game": _game_to_dict(s),
		"world": s.world.to_dict(),
		"fog": s.fog.to_dict(),
		"economy": s.economy.to_dict(),
		"research": s.tech_tree.to_dict(),
		"buildings": s.town.to_dict(),
		"kith": s.people.to_dict(),
		"story": s.story.to_dict(),
	}


## Put a dump (straight from dump(), or parsed back from JSON) into `s`, replacing whatever it held: it need
## not have a map yet. Returns false, and changes nothing, when `d` is not a run save of this version.
static func restore(s, d) -> bool:
	if not is_run_save(d):
		return false
	s.tech_tree.from_dict(d["research"])
	s.world.from_dict(d["world"])
	_lift_old_roads(s, d["world"])
	s.fog.from_dict(d["fog"])
	s.economy.from_dict(d["economy"])
	s.town.from_dict(d["buildings"])
	s.people.from_dict(d["kith"])
	s.story.from_dict(d["story"])
	_game_from_dict(s, d["game"])
	s.pathing.build()  # the walking grid is derived: read every cell of the restored map again
	return true


## A save from before road tiers has no "road_tiers": its roads were all one path, made faster by the techs. Keep what
## the town had earned: with Paved Roads (or Causeways) known, every road on land is paved.
static func _lift_old_roads(s, world: Dictionary) -> void:
	if world.has("road_tiers"):
		return
	if not (s.tech_tree.researched.has("paved_roads") or s.tech_tree.researched.has("causeways")):
		return
	for p in s.world.roads:
		if s.world.tile_at(p) != "river":
			s.world.set_road_tier(p, Data.ROAD_SPEEDS.size() - 1)


## True when `d` looks like a run save this code can read: a Dictionary with this VERSION and every section.
static func is_run_save(d) -> bool:
	if typeof(d) != TYPE_DICTIONARY:
		return false
	var version = d.get("version")
	if (typeof(version) != TYPE_INT and typeof(version) != TYPE_FLOAT) or int(version) != VERSION:
		return false
	for key in SECTIONS:
		if typeof(d.get(key)) != TYPE_DICTIONARY:
			return false
	return true


## The save as text: dictionary order kept and floats at full precision, so a reload is exact.
static func to_json(d: Dictionary) -> String:
	return JSON.stringify(d, "", false, true)


## The Dictionary in `text`, or {} when it is not JSON (or not an object). Prints nothing on bad input.
static func from_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


## Write the run in `s` to `path`. False when the file could not be written.
static func save(s, path: String = PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(to_json(dump(s)))
	file.close()
	return true


## Read the run save at `path` into `s`. False, with `s` untouched, when the file is missing, is not JSON
## or is not a run save of this version.
static func load_into(s, path: String = PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return restore(s, from_json(FileAccess.get_file_as_string(path)))


# --- What Sim keeps for itself -----------------------------------------


static func _game_to_dict(s) -> Dictionary:
	return {
		"won": s.won,
		"hand_tools": s.hand_tools,
		"shard_seen": s.shard_seen,
		"hand_counts": Codec.int_dict(s.hand_counts),
		"harvest_tile": Codec.vec(s.harvest_tile),
		"harvest_held": s.harvest_ring["held"],
		"harvest_frac": s.harvest_frac,
		"rushes": s.rushes,
		"ranks": Codec.int_dict(s.ranks),
		"events": s.events.duplicate(),
		"sky": s.sky.to_dict(),
		"starfall": s.starfall.to_dict(),
	}


static func _game_from_dict(s, d: Dictionary) -> void:
	s.won = bool(d.get("won", false))
	s.hand_tools = bool(d.get("hand_tools", false))
	s.shard_seen = bool(d.get("shard_seen", false))
	s.hand_counts = Codec.int_dict(d.get("hand_counts", {}))
	s.harvest_tile = Codec.to_vec(d.get("harvest_tile", [-1, -1]))
	s.harvest_ring["held"] = float(d.get("harvest_held", 0.0))
	s.harvest_frac = float(d.get("harvest_frac", 0.0))
	s.rushes = int(d.get("rushes", 0))
	s.ranks = Codec.int_dict(d.get("ranks", {}))
	s.events = Codec.strings(d.get("events", []))
	s.sky.from_dict(d.get("sky", {}))
	s.starfall.from_dict(d.get("starfall", {}))
