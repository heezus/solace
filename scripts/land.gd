extends RefCounted
## The land that opens at Bronze Dawn: the map doubles to the east (World.grow_east) and the blocks that follow its size
## take the new land in. It happens on the tick after the tech is researched, so the moment of Bronze Dawn itself is still
## the stone age's last state. The new land starts fogged; what already stands by the old east edge lifts a little of it.
## Static, and works on the Sim passed in, like Roads and Workers.

const Data = preload("res://scripts/data.gd")

const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const ORE_ORDER := ["copper_hills", "tin_stream"]  # the order the player is pointed to them


## Grow the map if Bronze Dawn is researched and it has not grown yet.
static func grow_if_due(s) -> void:
	if not s.tech_tree.researched.has("bronze_dawn") or not s.world.grow_east():
		return
	s.fog.widen(s.world.width)
	s.pathing.build()  # the walking grid and the haulers' road grid are as big as the map
	s.town.road_rev += 1
	var more: int = Data.SCOUTING_SIGHT if s.tech_tree.researched.has("scouting") else 0
	for b in s.town.buildings:
		s.fog.reveal(b["pos"], Data.SIGHT_BUILDING + more)
	for p in s.world.roads:
		s.fog.reveal(p, Data.SIGHT_KITH + more)
	s.events.append(Data.LAND_GREW_EVENT)


## Every tile of `tile` (an ore) in the land that grew east, in row order. Empty before the land has grown.
static func ore_tiles(s, tile: String) -> Array:
	var out: Array = []
	for y in s.world.height:
		for x in range(s.world.stone_width, s.world.width):
			if s.world.tiles[y * s.world.width + x] == tile:
				out.append(Vector2i(x, y))
	return out


## Where to point the player: {"ore": the tile id, "tile": the ore tile nearest the Hearth still under fog}. The copper
## until any of it has been seen, then the tin until any of that has. {} when both have been seen (or the land has not
## grown yet).
static func ore_target(s) -> Dictionary:
	for ore in ORE_ORDER:
		var all := ore_tiles(s, ore)
		if all.is_empty():
			return {}
		if all.any(func(p): return s.fog.is_revealed(p)):
			continue
		var best: Vector2i = all[0]
		for p in all:
			if Vector2(p).distance_to(Vector2(s.world.camp_pos)) < Vector2(best).distance_to(Vector2(s.world.camp_pos)):
				best = p
		return {"ore": ore, "tile": best}
	return {}


## The tile to put in the middle of the view to look at the way to `target`: halfway between the easternmost thing built
## (a building or a road, the Hearth at least) and the target, so the end of the road and the new land are both in sight.
static func look_east_at(s, target: Vector2i) -> Vector2i:
	var front: int = s.world.camp_pos.x
	for b in s.town.buildings:
		front = maxi(front, b["pos"].x)
	for p in s.world.roads:
		front = maxi(front, p.x)
	return Vector2i(mini(front, target.x) + ((target.x - mini(front, target.x)) >> 1), target.y)
