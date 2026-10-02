extends RefCounted
## The land that opens at Bronze Dawn: the map doubles to the east (World.grow_east) and the blocks that follow its size
## take the new land in. It happens on the tick after the tech is researched, so the moment of Bronze Dawn itself is still
## the stone age's last state. The new land starts fogged; what already stands by the old east edge lifts a little of it.
## Static, and works on the Sim passed in, like Roads and Workers.

const Data = preload("res://scripts/data.gd")


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
