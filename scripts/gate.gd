extends RefCounted
## The Skyward gate's two deeds (design-system/23-livewire.md): the town runs on rules (five standing orders written) and has made
## a stand against the green (the south held). Research asks `deed` before the gate can be bought, and the goals panel asks it too.
## It holds the blocks it reads, not the Sim, so the Sim can hand `deed` to Research without a reference cycle.

const Data = preload("res://scripts/data.gd")

var _livewire  # the Order Board's orders
var _town  # the buildings and what is powered
var _world  # where the Hearth is
var _tide  # which buildings the Bloom has overgrown


func _init(livewire, town, world, tide) -> void:
	_livewire = livewire
	_town = town
	_world = world
	_tide = tide


## True when the deed `id` (Data.DEED_NAMES) is done now.
func deed(id: String) -> bool:
	match id:
		"orders_written":
			return orders_written() >= Data.DEED_ORDERS
		"south_held":
			return south_held()
	return false


## Standing orders with a kind of building chosen: a line with no target does nothing, so it is not yet written.
func orders_written() -> int:
	return _livewire.orders.filter(func(o): return o["target"] != "").size()


## True when a Scorcher is burning and at least Data.DEED_LAMPS Arc Lamps are lit, all in the south land.
func south_held() -> bool:
	var scorching := false
	var lamps := 0
	for b in _town.buildings:
		if not in_south(b["pos"]):
			continue
		var kind: String = Data.BUILDINGS[b["type"]]["kind"]
		if kind == "scorcher" and b["burn"] > 0.0 and _town.is_powered(b["pos"]):
			scorching = true
		elif kind == "arc_lamp" and _town.is_powered(b["pos"]) and not _tide.is_overgrown_at(b["pos"]):
			lamps += 1
	return scorching and lamps >= Data.DEED_LAMPS


## True for a tile in the south land: Data.SOUTH_ROWS_BELOW_HEARTH rows below the Hearth, or further south.
func in_south(p: Vector2i) -> bool:
	return p.y >= _world.camp_pos.y + Data.SOUTH_ROWS_BELOW_HEARTH
