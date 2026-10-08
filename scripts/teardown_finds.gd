extends RefCounted
## Where parts come from (design-system/19-ironfall.md, stage 2): the Wreck, which always holds three; the Lumen Camp, which
## hands over what the lean the Starfall ended on allows (enemies none, neighbours two, allies all four); and the three Bloom
## patches at the far edge of the land that grows south, one sample each. Every source waits for Ironfall to begin and for the
## Teardown tech, so no part comes home before the Kith can open it. Static, and works on the Sim passed in; the parts
## themselves are the Teardown block's (`sim.teardown`).

const Data = preload("res://scripts/data.gd")
const Scouting = preload("res://scripts/scouting.gd")


## True once the Kith can open parts: Ironfall has begun and Teardown is learned.
static func active(s) -> bool:
	return s.story.has_event(Data.IRONFALL_EVENT) and s.tech_tree.researched.has("teardown")


# --- The Wreck ---------------------------------------------------------------


## True while the Wreck still holds a part nobody has carried home.
static func wreck_has_parts(s) -> bool:
	return active(s) and s.teardown.wreck_taken.size() < Data.WRECK_PARTS.size()


## The next part the Wreck gives: the first of its three the town does not hold or know yet, else the first left. "" when
## all three are home.
static func next_wreck_part(s) -> String:
	var left: Array = Data.WRECK_PARTS.filter(func(id): return id not in s.teardown.wreck_taken)
	for id in left:
		if not s.teardown.holds(id) and not s.teardown.knows(id):
			return id
	return left[0] if not left.is_empty() else ""


## A party home from the Wreck with pack `pack` (`late`: dusk caught it, half the finds): put its parts in the pack.
## Returns the ids it brought, [] when it brought none.
static func wreck_finds(s, pack: String, late: bool) -> Array:
	var out: Array = []
	if not active(s):
		return out
	var count: int = Data.WRECK_TRIP_PARTS[pack]
	if late:
		count = ceili(count / 2.0)
	for i in count:
		var id := next_wreck_part(s)
		if id == "":
			break
		s.teardown.wreck_taken.append(id)
		s.teardown.add_part(id)
		out.append(id)
	return out


## The line for the event log when a party brings `ids` home from the Wreck.
static func wreck_line(ids: Array) -> String:
	var names: Array = ids.map(func(id): return "a " + Data.PARTS[id]["name"])
	return Data.WRECK_PART_LINE % " and ".join(names)


# --- The Lumen Camp ----------------------------------------------------------


## The parts the Lumen Camp offers by the lean the Starfall ended on: Data.CAMP_PARTS, in the order they are handed over.
static func camp_offer(s) -> Array:
	return Data.CAMP_PARTS.get(s.starfall.lean, [])


## While a Lumen Camp stands (and the Kith can open parts), hand over the next part on offer every Data.CAMP_GIVE_SECONDS.
static func camp_tick(s, delta: float) -> void:
	if not active(s) or not s.starfall.has_building("lumen_camp"):
		return
	var offer := camp_offer(s)
	if s.teardown.gifts >= offer.size():
		return
	s.teardown.gift_clock += delta
	if s.teardown.gift_clock < Data.CAMP_GIVE_SECONDS:
		return
	s.teardown.gift_clock = 0.0
	var id: String = offer[s.teardown.gifts]
	s.teardown.gifts += 1
	s.teardown.add_part(id)
	s.events.append(Data.CAMP_GIVES_LINE % [Data.PARTS[id]["name"], Data.LEAD_NAME])


# --- The Bloom patches -------------------------------------------------------


## True when the Kith may take a Bloom sample: the Bloom Sampling tech, or the placeholder that stands in for it until that
## tech is built (Data.BLOOM_SAMPLING_PLACEHOLDER; `placeholder` lets a test try both).
static func sampling_open(s, placeholder: bool = Data.BLOOM_SAMPLING_PLACEHOLDER) -> bool:
	return placeholder or s.tech_tree.researched.has("bloom_sampling")


## The samples still lying in the south, as [{"kind", "pos"}], in the order of Data.BLOOM_KINDS.
static func patches(s) -> Array:
	var out: Array = []
	if not s.world.is_grown_south():
		return out
	var w: int = s.world.width
	for kind in Data.BLOOM_KINDS:
		var tile: String = Data.BLOOM_TILES[kind]
		for i in range(s.world.base_height * w, s.world.tiles.size()):
			if s.world.tiles[i] == tile:
				out.append({"kind": kind, "pos": Vector2i(i % w, floori(float(i) / w))})
				break
	return out


## The sample nearest the Hearth, (-1, -1) for none.
static func nearest_patch(s) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for patch in patches(s):
		var d := Vector2(patch["pos"]).distance_to(Vector2(s.world.camp_pos))
		if d < best_d:
			best = patch["pos"]
			best_d = d
	return best


## Why a party cannot go to a Bloom patch now, "" when it can.
static func bloom_problem(s) -> String:
	if not active(s):
		return Data.BLOOM_NO_TEARDOWN
	if not s.world.is_grown_south():
		return Data.BLOOM_NO_LAND
	if not sampling_open(s):
		return Data.BLOOM_NO_TECH
	return "" if nearest_patch(s).x >= 0 else Data.BLOOM_NONE_LEFT


## Whether the Expedition Post's target list offers `target`: the Bloom patch only once the Kith can open what they find.
static func target_listed(s, target: String) -> bool:
	return target != "bloom" or active(s)


## A party reached the tile `near` and takes the sample lying within a few tiles of it: the tile becomes plain Bloom ground
## and the sample goes in the pack. Returns the sample's kind, "" when none lies there.
static func take_sample(s, near: Vector2i) -> String:
	var best := {}
	var best_d := 4.5
	for patch in patches(s):
		var d := Vector2(patch["pos"]).distance_to(Vector2(near))
		if d < best_d:
			best = patch
			best_d = d
	if best.is_empty() or not sampling_open(s):
		return ""
	var kind: String = best["kind"]
	s.world.set_tile(best["pos"], Data.BLOOM_GROUND)
	s.teardown.sampled.append(kind)
	s.teardown.add_part(kind)
	s.events.append(Data.SAMPLE_LINE % Data.PARTS[kind]["name"].to_lower())
	return kind


## The walk goal for a party sent to the nearest patch, (-1, -1) for none.
static func bloom_goal(s) -> Vector2i:
	var p := nearest_patch(s)
	return Scouting.goal(s, p) if p.x >= 0 else p
