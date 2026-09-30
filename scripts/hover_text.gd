extends RefCounted
## The Info panel's text for whatever the mouse is over: a tile, a resource (with how a hold pays), a building,
## or the placement of the building being placed. Static; `m` is the main scene, which owns `state`, `hover`,
## `placing`, `nudge` and the building panel. The one place a hint about the tile under the mouse is shown.

const Data = preload("res://scripts/data.gd")
const Ui = preload("res://scripts/ui.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Roads = preload("res://scripts/roads.gd")
const Workers = preload("res://scripts/workers.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Hands = preload("res://scripts/hands.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")


static func text(m) -> String:
	var s = m.state
	if m.placing == "demolish":
		return "Demolish: click a building, road or field to tear it down for half its cost back. Right-click to stop."
	if m.placing != "":
		return _placing_text(m)
	if not s.world.in_bounds(m.hover):
		return ""
	if not s.fog.is_revealed(m.hover):
		return Data.UNEXPLORED_INFO
	var who := _kith_here(s, m.hover)
	return (who + "\n\n" if who != "" else "") + _tile_text(m)


static func _placing_text(m) -> String:
	var s = m.state
	var def: Dictionary = Data.BUILDINGS[m.placing]
	var t := "Placing %s. Left-click open grassland, right-click to stop." % def["name"]
	if def["kind"] in ["road", "bridge", "field"]:
		t = "Laying %s: click, or drag and release to lay a line. Right-click to stop." % def["name"]
	t += (
		"\nCost (have/need): "
		+ (Ui.progress_text(s.economy.inv, def["cost"], 99) if not def["cost"].is_empty() else "free")
	)
	if s.world.in_bounds(m.hover):
		var err: String = s.town.placement_error(m.placing, m.hover)
		if err != "":
			t += "\n\nCan't build here: " + err + "."
		if m.placing == "gatherers_hut":
			var tiles: Array = s.town.tiles_of(m.hover, s.town.default_focus(m.hover))
			t += "\n\n" + BuildingPanel.gather_text(s, tiles)
			if not tiles.is_empty():
				t += "\nIt will work the resource nearest it: click the hut afterwards to change."
		if s.tech_tree.researched.has("haulers") and def["kind"] in ["gatherer", "processor"]:
			t += "\n" + _road_preview(s, m.hover)
	return t


## Whether a building placed at p would be linked by road, and if not, how far the road has to go.
static func _road_preview(s, p: Vector2i) -> String:
	var g := Roads.gap(s, p)
	if g["to"].x < 0:
		return "Road: linked here, haulers will carry for it."
	return "Needs road: no road touches here. Lay about %d tiles of Road to link it." % g["tiles"]


## "Aro the Woodcutter, Tam the Hauler" for the Kith standing on or walking through tile p.
static func _kith_here(s, p: Vector2i) -> String:
	var names: Array = []
	for k in s.people.kith:
		var at: Vector2 = k["pos"]
		if Vector2i(roundi(at.x), roundi(at.y)) == p:
			names.append(s.people.title_of(k))
	return ", ".join(names)


## What's on the hovered tile: a building, a road, a resource or open ground.
static func _tile_text(m) -> String:
	var s = m.state
	var p: Vector2i = m.hover
	if s.town.building_at.has(p):
		return _building_text(m)
	var t: Dictionary = Data.TILES[s.world.tile_at(p)]
	if s.world.roads.has(p):
		if s.world.tile_at(p) == "river":
			return Data.BRIDGE_HINT % Data.PEOPLE["many"]
		return Data.ROAD_HINT % [t["name"], Data.PEOPLE["many"]]
	var hint := Overlays.blocked_hint(s, p)
	if t["yields"] != "":
		var item: String = t["yields"]
		var how := "Hold the mouse on it to gather."
		if not m.nudge.is_empty() and m.nudge["tile"] == p:
			how = "You let go too soon: keep the mouse down until the ring fills."
		var out := "%s\n%s. %s" % [t["name"], hold_hint(s, item), how]
		if Data.FOOD_VALUE.has(item):
			out += " It's food: the %s eat it." % Data.PEOPLE["many"]
		out += "\n" + learn_text(s, item)
		return out + ("\n" + hint + "." if hint != "" else "")
	return t["name"] + ("\n" + hint + "." if hint != "" else "")


## A hovered building in a few lines. The selected one has its card above, so it says nothing here.
static func _building_text(m) -> String:
	var s = m.state
	var p: Vector2i = m.hover
	if m.building_panel.visible and m.building_panel.pos == p:
		return ""
	var b: Dictionary = s.town.buildings[s.town.building_at[p]]
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	var out: String = def["name"] + "\n" + (b["status"] if b["status"] != def["desc"] else def["desc"])  # a blurb shows once
	if Buildings.buffered(b["out"]) > 0:
		out += "\nHolding " + Ui.cost_text(b["out"])
	if s.tech_tree.researched.has("haulers") and Buildings.needs_worker(b):
		out += (
			"\n"
			+ ("Road: linked, haulers carry for it" if Roads.linked(s, b) else "Needs road: " + Workers.road_hint(s, p))
		)
	var click := BuildingPanel.click_text(s, b)
	return out + "\n\n" + (click + "\n" if click != "" else "") + "Click to select it."


## "Hold: +3 Wood, 0.7s".
static func hold_hint(s, item: String) -> String:
	var secs := str(snappedf(Hands.hold_time(s, item), 0.1))
	return "Hold: +%d %s, %ss" % [Hands.harvest_yield(s, item), Data.ITEMS[item]["name"], secs]


## How far a Kith is from learning to gather `item` by watching you.
static func learn_text(s, item: String) -> String:
	var item_name: String = Data.ITEMS[item]["name"]
	if s.people.knows(item):
		return "%s knows how to gather %s: huts can gather it." % [s.people.learned_by[item], item_name]
	return (
		"Harvested by hand %d/%d. A %s is watching and will learn %s."
		% [s.hand_counts.get(item, 0), Data.LEARN_CLICKS, Data.PEOPLE["one"], item_name]
	)


## The tile under the mouse gives this when clicked, or "" if it isn't a resource you can see.
static func hover_item(m) -> String:
	var s = m.state
	if m.placing != "" or not s.world.in_bounds(m.hover) or not s.fog.is_revealed(m.hover):
		return ""
	if s.town.building_at.has(m.hover) or s.world.roads.has(m.hover) or s.world.tile_at(m.hover) == "":
		return ""
	return Data.TILES[s.world.tile_at(m.hover)]["yields"]
