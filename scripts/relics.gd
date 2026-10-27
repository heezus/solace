extends RefCounted
## Relics, the Cataclysm's gift (Step 7E, design-system/18-roadmap.md "Relics as built"): in a Cataclysm run the three heaviest ruins
## each hold a relic (Data.ENDINGS["relics"], in that order: the Everburning Forge, the Old Lantern, the Founders' Cart). A Kith crew
## digs one out (Scouting.dig: about Data.ENDINGS["dig_seconds"] and a road beside the ruin), and the ruin becomes the relic's
## building: a Forge that burns nothing, a Shard Lantern that lights twice as far, a Storehouse that makes the haulers near it carry
## half as much again. A relic is used up with the run: `carry.dug` is saved with the run and never handed on, so the next
## Cataclysm finds its own. Static, and works on the Sim passed in; Scouting walks the crew and calls `finish`.

const Data = preload("res://scripts/data.gd")
const Kith = preload("res://scripts/kith.gd")


## The relic under the ruin at `p` (an entry of Data.ENDINGS["relics"]), {} for a ruin with none. The heaviest ruins come first in the
## carry (scripts/ruins.gd), so the first of them hold the first relics.
static func at(s, p: Vector2i) -> Dictionary:
	var list: Array = Data.ENDINGS["relics"]
	for i in mini(list.size(), s.carry.ruins.size()):
		if _pos(s.carry.ruins[i]) == p:
			return list[i]
	return {}


## The ruin that holds relic `id`, (-1, -1) when this run has none.
static func site_of(s, id: String) -> Vector2i:
	var list: Array = Data.ENDINGS["relics"]
	for i in mini(list.size(), s.carry.ruins.size()):
		if list[i]["id"] == id:
			return _pos(s.carry.ruins[i])
	return Vector2i(-1, -1)


## The relics still under their ruins, [{"def": the relic, "pos": its ruin}]: laid on the map and not dug.
static func waiting(s) -> Array:
	var out: Array = []
	for def in Data.ENDINGS["relics"]:
		var p := site_of(s, def["id"])
		if p.x >= 0 and not s.carry.dug.has(def["id"]) and s.world.tile_at(p) == "ruins":
			out.append({"def": def, "pos": p})
	return out


## The road tiles beside the ruin at `p` (all eight neighbours), where a crew can stand to dig.
static func roads_beside(s, p: Vector2i) -> Array:
	var out: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := p + Vector2i(dx, dy)
			if q != p and s.world.roads.has(q):
				out.append(q)
	return out


## The Kith digging out relic `id`, {} when no crew is at it.
static func digging(s, id: String) -> Dictionary:
	for k in s.people.kith:
		if k["job"] == "scout" and String(k["phase"]).begins_with("dig") and k["task"].get("relic", "") == id:
			return k
	return {}


## How far the crew at relic `id` has dug, 0 to 1 (0 until they stand at the ruin).
static func progress(s, id: String) -> float:
	var k := digging(s, id)
	if k.is_empty() or k["phase"] != "dig_work":
		return 0.0
	return clampf(float(k["timer"]) / float(Data.ENDINGS["dig_seconds"]), 0.0, 1.0)


## The hover pill over ruin `p`: what lies under it and how to dig it out, "" for a ruin with no relic left.
static func tip(s, p: Vector2i) -> String:
	var def := at(s, p)
	if def.is_empty() or s.carry.dug.has(def["id"]):
		return ""
	if not digging(s, def["id"]).is_empty():
		return Data.ENDINGS["dig_progress"] % def["name"]
	return Data.ENDINGS["relic_tip"] % def["name"]


## The ruin at `p` is dug out: it becomes grass with the relic's building on it, and the story notes it.
static func finish(s, id: String) -> void:
	var p := site_of(s, id)
	if p.x < 0 or s.carry.dug.has(id):
		return
	var def := {}
	for r in Data.ENDINGS["relics"]:
		if r["id"] == id:
			def = r
	s.carry.dug.append(id)
	s.world.set_tile(p, "grass")
	s.pathing.update_cell(p)
	s.town.add_building(def["building"], p)
	s.town.buildings[s.town.building_at[p]]["relic"] = id
	s.story.record(def["event"])
	s.events.append(Data.ENDINGS["dig_done"] % [def["name"], def["line"]])


## True for a building that is a dug relic (it carries its relic's id in `relic`).
static func is_relic(b: Dictionary) -> bool:
	return b.has("relic")


## How far the shardlight of lantern or Cairn `c` reaches: the Old Lantern lights Data.ENDINGS["lantern_reach"] times as far.
static func radius(c: Dictionary) -> float:
	return Data.SHARDLIGHT_RADIUS * (Data.ENDINGS["lantern_reach"] if is_relic(c) else 1.0)


## A hauler's load `n` (carry_cap) once the Founders' Cart is dug: half as much again for a hauler within its reach, while the
## cart stands and the Bloom is not on it.
static func load_of(s, k: Dictionary, n: int) -> int:
	if not s.carry.dug.has("cart"):
		return n
	var at_cart := site_of(s, "cart")
	var i: int = s.town.building_at.get(at_cart, -1)
	if i < 0 or not is_relic(s.town.buildings[i]) or s.tide.is_overgrown(s.town.buildings[i]):
		return n
	if Vector2(Kith.tile_of(k)).distance_to(Vector2(at_cart)) > Data.ENDINGS["cart_reach"]:
		return n
	return ceili(n * Data.ENDINGS["cart_load"])


static func _pos(r) -> Vector2i:
	return Vector2i(int(r["pos"][0]), int(r["pos"][1]))
