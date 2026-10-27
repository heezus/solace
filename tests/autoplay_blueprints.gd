extends RefCounted
## What the headless players do with blueprints (scripts/blueprints.gd, Step 7D): at the end of a run the bot keeps the yards it
## built round the Hearth, and in an Exodus run it lays them down again where the new Hearth stands. Two blueprints: the Hearth
## yard (every road, field and building but the gatherers within YARD_RADIUS of the Hearth: a hut belongs beside what it
## works, which differs from map to map) and the smelter yard (the box round its smelters, crucibles,
## bloomeries and forges, when they stand close enough to be one yard). Both are kept with their corner's offset from the Hearth, so
## laying puts each where it stood in relation to the new Hearth. All static; tests/tools/pace.gd calls these.

const Blueprints = preload("res://scripts/blueprints.gd")
const Data = preload("res://scripts/data.gd")

const YARD_RADIUS := 8  # the Hearth yard reaches this many tiles each way from the Hearth
const SMELTING := ["smelter", "crucible", "bloomery", "forge"]
const SKIP := ["gatherer"]  # kinds a bot does not keep: they are placed where their resource is
const ROAD_KINDS := ["road", "bridge", "depot"]  # what the "roads" mode keeps: the road grid and its storehouses

const SMELTER_YARD_MAX := 22  # tiles across: wider than this is not one yard

## Hearth-relative corners of the boxes last saved, in blueprint order (the blueprint itself keeps no place).
static var corners: Array = []

## What the bot keeps (`blueprints=<mode>` on the pace tool): "all" the yards, "yards" (roads and storehouses at the Hearth, the smelter
## yard whole), or "roads" (the road grid and storehouses only).
static var mode := "all"


## The boxes worth keeping from the run in `s`: the Hearth yard, then the smelter yard when there is one.
static func boxes(s) -> Array:
	var camp: Vector2i = s.world.camp_pos
	var out := [Rect2i(camp - Vector2i(YARD_RADIUS, YARD_RADIUS), Vector2i.ONE * (2 * YARD_RADIUS + 1))]
	if mode == "roads":
		return out
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	var n := 0
	for b in s.town.buildings:
		if b["type"] in SMELTING:
			lo = lo.min(b["pos"])
			hi = hi.max(b["pos"])
			n += 1
	if n > 0 and maxi(hi.x - lo.x, hi.y - lo.y) < SMELTER_YARD_MAX:
		out.append(Rect2i(lo - Vector2i.ONE, hi - lo + Vector2i.ONE * 3))
	return out


## Keep the boxes of the run in `s` in its blueprint book. Returns how many were kept.
static func save_all(s) -> int:
	corners = []
	var list := boxes(s)
	for i in list.size():
		var box: Rect2i = list[i]
		var skip: Array = SKIP
		if mode != "all" and i == 0:  # the Hearth yard keeps only roads and storehouses
			skip = Data.BUILDINGS.values().map(func(d): return d["kind"]).filter(func(k): return k not in ROAD_KINDS)
		if Blueprints.save(s, box, "", skip) == "":
			corners.append(box.position - s.world.camp_pos)
	return corners.size()


## Lay every kept blueprint of the run in `s` (its book came from the profile) where it stands against `s`'s Hearth.
static func lay_all(s) -> int:
	var n := 0
	for i in mini(s.carry.blueprints.size(), corners.size()):
		n += Blueprints.lay(s, i, s.world.camp_pos + corners[i])
	return n
