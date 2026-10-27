extends RefCounted
## The first ship's site (Step 7F, Data.ENDINGS["old"]): from the second run on, an older wreck lies hidden in the fog, the hull of the
## ship that fell ages ago. An Expedition Post can send a party there (Expedition target "old_ship") and it brings back the old marks:
## sets 7 to 9 of the Glyph Wall (OldShip.add_finds). Where it lies is fixed by the map and the run: the same tile every time for
## the same land, never touching the gameplay random numbers. Static, and works on the Sim passed in.

const Data = preload("res://scripts/data.gd")
const Scouting = preload("res://scripts/scouting.gd")


## The tile of the first ship's site, (-1, -1) for a first run (it has none). Open ground between "site_near" and "site_far" tiles from
## the Hearth, "site_apart" from the crash site, a party can walk to and back in a day, and so, most likely, in the fog. Tried in a
## scrambled order of the Hearth and the map; falls back to the first open tile of that kind when none fits all of it.
static func tile(s) -> Vector2i:
	if s.carry.exodus < 1:
		return Vector2i(-1, -1)
	var old: Dictionary = Data.ENDINGS["old"]
	var wreck := Vector2i(s.world.width - 5, s.world.height / 2)  # where the ship comes down, near enough (Sim._wreck_tile)
	var fallback := Vector2i(-1, -1)
	for k in 400:
		var p := Vector2i(_scramble(s, k * 2) % s.world.width, _scramble(s, k * 2 + 1) % s.world.height)
		if s.world.tile_at(p) != "grass" or s.pathing.astar.is_point_solid(p):
			continue
		var d := maxi(absi(p.x - s.world.camp_pos.x), absi(p.y - s.world.camp_pos.y))
		if d < old["site_near"] or d > old["site_far"]:
			continue
		var apart: bool = maxi(absi(p.x - wreck.x), absi(p.y - wreck.y)) >= old["site_apart"]
		var goal := Scouting.goal(s, p)
		var trip: float = s.people.round_trip(s.world.camp_pos, goal) if goal.x >= 0 else -1.0
		if goal != p or trip <= 0.0 or trip > Data.DAYLIGHT_SECONDS:
			continue  # a party must be able to walk there and back in a day
		if apart:
			return p
		if fallback.x < 0:
			fallback = p
	return fallback


static func _scramble(s, k: int) -> int:
	var at: Vector2i = s.world.camp_pos + Vector2i(s.world.width, s.world.height)
	return absi(((at.x + 3) * 73856093) ^ ((at.y + 5) * 19349663) ^ ((k + 1) * 83492791)) % 1000003


## The old sets (Data.ENDINGS["old"]) the run of `f` (a Starfall block) can read, by number: set 7 from run 2, set 8 from run 3 (run 2
## after a Cataclysm), set 9 from run 4. They sit beside the six sets, never in `set_order` or the "of 6" count, and the Warning
## does not wait on them.
static func sets(f) -> Dictionary:
	var out := {}
	var run: int = f.carry.exodus + 1
	for n in Data.ENDINGS["old"]["sets"]:
		var def: Dictionary = Data.ENDINGS["old"]["sets"][n]
		if (
			run >= def["run"]
			or (def.has("cataclysm_run") and f.carry.ending == "cataclysm" and run >= def["cataclysm_run"])
		):
			out[n] = def
	return out


## The set numbered `n`, of the six or of the old ones: {} for none.
static func set_def(n: int) -> Dictionary:
	return Data.GLYPH_SETS.get(n, Data.ENDINGS["old"]["sets"].get(n, {}))


## The six sets and the old sets this run can read, in order: the ones the Wall can hold and check.
static func all_sets(f) -> Dictionary:
	var out: Dictionary = Data.GLYPH_SETS.duplicate()
	out.merge(sets(f))
	return out


## Where old set `n` is found in the run of `f`: "old_ship" (the first ship's site), or "old_ruin" for What Broke in a Cataclysm
## run, which lies in the sprouting ruins, at the largest ruin.
static func source(f, n: int) -> String:
	if n == 8 and f.carry.ending == "cataclysm" and not f.carry.ruins.is_empty():
		return "old_ruin"
	return "old_ship"


## The largest ruin of a Cataclysm run, where What Broke lies: (-1, -1) when the run has none.
static func ruin_tile(f) -> Vector2i:
	if f.carry.ending != "cataclysm" or f.carry.ruins.is_empty():
		return Vector2i(-1, -1)
	var at: Array = f.carry.ruins[0]["pos"]
	return Vector2i(int(at[0]), int(at[1]))


## A party came back from `from` ("old_ship" or "old_ruin"): put up to `count` more of the old marks found there on the Wall of `f`
## (the lowest set first). Returns how many were added, 0 once every old mark this run can read there is on the Wall.
static func add_finds(f, count: int, from := "old_ship") -> int:
	var added := 0
	var all := sets(f)
	for n in all:
		if f.locked.has(all[n]["id"]) or source(f, n) != from:
			continue
		for g in f.glyph_order(n):
			if added < count and not f.copied.has(g):
				f._copy(g)
				added += 1
	return added


## True while `from` ("old_ship" or "old_ruin") still holds an old mark nobody has copied.
static func has_more(f, from := "old_ship") -> bool:
	var all := sets(f)
	for n in all:
		if not f.locked.has(all[n]["id"]) and source(f, n) == from:
			for g in all[n]["glyphs"]:
				if not f.copied.has(g):
					return true
	return false


## The words a guess on `glyph` can try: the list, and for an old mark the three words the old marks add.
static func words_for(glyph: String) -> Array:
	for n in Data.ENDINGS["old"]["sets"]:
		if glyph in Data.ENDINGS["old"]["sets"][n]["glyphs"]:
			return Data.GLYPH_WORDS + Data.ENDINGS["old"]["words"]
	return Data.GLYPH_WORDS
