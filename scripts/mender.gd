extends RefCounted
## The Healing House's help (Data.LUMEN, the Body gift): a staffed one tends the homes within Data.LUMEN's "mender_radius" tiles of it,
## so births come sooner there and tools used by the Kith housed there last longer. The Kith ask for the share of the settlement's
## room it reaches (Kith.mender_share) and scale the gift by it. Static, and works on the Buildings passed in.

const Data = preload("res://scripts/data.gd")
const Buildings = preload("res://scripts/buildings.gd")


## 0 to 1: the share of the homes' room (the Hearth's and every home's, at its tier) that a staffed Healing House reaches.
static func cover(town) -> float:
	var houses: Array = []
	for b in town.buildings:
		if Data.BUILDINGS[b["type"]].get("mends", false) and Buildings.is_staffed(b) and not b["paused"]:
			if not town.overgrown.call(b["pos"]):
				houses.append(Vector2(b["pos"]))
	if houses.is_empty():
		return 0.0
	var total := 0
	var covered := 0
	for b in town.buildings:
		var def: Dictionary = Data.BUILDINGS[b["type"]]
		var room: int = _room(b, def)
		total += room
		if room > 0 and houses.any(func(h): return h.distance_to(Vector2(b["pos"])) <= Data.LUMEN["mender_radius"]):
			covered += room
	return float(covered) / float(total) if total > 0 else 0.0


## The room building `b` has for the Kith: a home's tier, the Hearth's own, none for the rest.
static func _room(b: Dictionary, def: Dictionary) -> int:
	if def["kind"] == "house":
		return int(Data.HOME_TIERS[clampi(int(b.get("tier", 0)), 0, Data.HOME_TIERS.size() - 1)]["housing"])
	return def.get("housing", 0)
