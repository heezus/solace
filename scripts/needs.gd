extends RefCounted
## Who provides what a building or a goal waits on (design-system/25-playtesting.md, "Fun playtest 3"). A "Needs X" that does not say
## where X comes from is a dead end, so every line here is built from the data: a good is made at the buildings whose `out` holds it or
## gathered from the tiles that yield it, a building is opened by its tech, Lesson or Lumen set, and shardlight comes from a Shard Cairn
## or a Lantern. `provider` is the one sentence for a good, `why_short` walks the chain a step further (the maker is not built, is not
## open, or stands but waits itself), `goal_note` is the IN THE WAY line of a goal that asks for a building.
## Pure functions of the game state.

const Bonuses = preload("res://scripts/bonuses.gd")
const CardText = preload("res://scripts/card_text.gd")
const Data = preload("res://scripts/data.gd")
const Power = preload("res://scripts/power.gd")


## "Brick is made at a Kiln.", "Clay is gathered from Clay Bank tiles, by hand or at a Gatherer's Hut." "" for a good nothing provides.
static func provider(item: String) -> String:
	var name: String = Data.ITEMS[item]["name"]
	var makers := makers_of(item)
	if item == Data.SHARD_ITEM:
		return "Shards are chipped from the Strange Stone by hand once Shard Lamps is learned."
	if not makers.is_empty():
		return "%s is made at a %s." % [name, " or a ".join(makers.map(func(t): return Data.BUILDINGS[t]["name"]))]
	var tiles: Array = []
	for t in Data.TILES:
		if Data.TILES[t]["yields"] == item:
			tiles.append(Data.TILES[t]["name"])
	if not tiles.is_empty():
		return "%s is gathered from %s, by hand or at a Gatherer's Hut." % [name, " or ".join(tiles)]
	return ""


## The building types whose output holds `item`.
static func makers_of(item: String) -> Array:
	var out: Array = []
	for type in Data.BUILDINGS:
		if Data.BUILDINGS[type].get("out", {}).has(item):
			out.append(type)
	return out


## The goods a building makes, named for a line about it: "Copper", "Bricks and Charcoal" ("" for one that makes nothing).
static func made_by(b: Dictionary) -> String:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	var names: Array = []
	if def["kind"] == "gatherer" and b["focus"] != "":
		names.append(Data.ITEMS[b["focus"]]["name"])
	for id in def.get("out", {}):
		names.append(Data.ITEMS[id]["name"])
	return " and ".join(names)


## The goods the goal in front of the player is made of, down the recipes: its price, what makes that, what that is made of. {item: true}.
static func goal_goods(s) -> Dictionary:
	var list: Array = s.story.goal_list()
	var at: int = s.story.current_goal()
	var out := {}
	if at >= list.size():
		return out
	var g: Dictionary = list[at]
	var cost := {}
	if g.has("tech"):
		cost = s.tech_tree.cost_of(g["tech"])
	elif g.has("building") and Data.BUILDINGS.has(g["building"]):
		cost = Data.BUILDINGS[g["building"]]["cost"]
	for id in cost:
		_down(id, out)
	return out


static func _down(id: String, out: Dictionary) -> void:
	if out.has(id):
		return
	out[id] = true
	for type in makers_of(id):
		for input in Data.BUILDINGS[type].get("in", {}):
			_down(input, out)


## How many of `item` the goal in front of the player still asks for in its price (0 when it asks for none, or the goal is done).
static func goal_need(s, item: String) -> int:
	if item == "":
		return 0
	var list: Array = s.story.goal_list()
	var at: int = s.story.current_goal()
	if at >= list.size():
		return 0
	var g: Dictionary = list[at]
	if g.has("tech"):
		return int(s.tech_tree.cost_of(g["tech"]).get(item, 0))
	if g.has("building") and Data.BUILDINGS.has(g["building"]):
		return int(Data.BUILDINGS[g["building"]]["cost"].get(item, 0))
	return 0


## True when good `item` can still be had by a town that has lost every building: a tile that yields it is left to gather by hand, or a
## Trading Post can swap another good into it, or the buildings that make it can be built again out of goods that can themselves be
## had. `seen` stops a good from waiting on itself. This is the test that the Bloom (or anything) can never take away every way back.
static func way_back(s, item: String, seen := {}) -> bool:
	if seen.has(item):
		return false
	seen[item] = true
	if item == Data.SHARD_ITEM and _tiles_left(s, "shard"):
		return true
	for t in Data.TILES:
		if Data.TILES[t]["yields"] == item and _tiles_left(s, t):
			return true
	if s.tech_tree.researched.has("markets") and item != Data.SHARD_ITEM:
		return true  # a Trading Post swaps 3 of any other good for 1 of this one, at a poor rate
	for type in makers_of(item):
		var ok := true
		for id in Data.BUILDINGS[type]["cost"]:
			ok = ok and way_back(s, id, seen.duplicate())
		for id in Data.BUILDINGS[type].get("in", {}):
			ok = ok and way_back(s, id, seen.duplicate())
		if ok:
			return true
	return false


static func _tiles_left(s, tile: String) -> bool:
	for y in s.world.height:
		for x in s.world.width:
			if s.world.tile_at(Vector2i(x, y)) == tile:
				return true
	return false


## The shardlight line for a lit workshop that stands in the dark: the Lantern when it is open, else the Cairn's reach alone.
static func shardlight(s) -> String:
	var radius := int(Data.SHARDLIGHT_RADIUS)
	if s.starfall.opens("light"):
		return Data.LUMEN["needs_light_status"] % [radius, radius]
	return Data.LUMEN["needs_light_cairn"] % [radius, Data.LUMEN["cards"]["light"]["set"]]


## Why `type` cannot be built yet, when it is shut: its Lesson, its Lumen set or the story. "" when it is open (or waits on a tech:
## Chain names that).
static func shut(s, type: String) -> String:
	var def: Dictionary = Data.BUILDINGS[type]
	if s.town.unlocked(type):
		return ""
	# a Lesson learned in an earlier telling stays learned: then only the tech stands in the way, and Chain says so
	if def.has("lesson") and not s.teardown.knows(def["lesson"]):
		var part: Dictionary = Data.PARTS[def["lesson"]]
		return (
			"The %s is taught by a %s from the Teardown Bench. The %s comes from %s."
			% [def["name"], part["name"], part["name"], part["from"]]
		)
	if def.has("lumen"):
		return (
			"Read the %s marks on the Glyph Wall to open the %s."
			% [Data.LUMEN["cards"][def["lumen"]]["set"], def["name"]]
		)
	if def["tech"] == "" and def.get("event", "") != "":
		return "The %s opens when the story gets there." % def["name"]
	return ""


## What stands in the way of getting `item` into the stockpile now: "" when it is there, else a sentence that ends in a next step.
static func why_short(s, item: String, want := 1) -> String:
	if s.economy.inv.get(item, 0) >= want:
		return ""
	var name: String = Data.ITEMS[item]["name"]
	var makers := makers_of(item)
	if makers.is_empty():
		return provider(item)
	for type in makers:
		for b in s.town.buildings:
			if b["type"] == type:
				return _waiting(s, b, name)
	var first: String = makers[0]
	var closed := shut(s, first)
	if closed != "":
		return "%s %s" % [provider(item), closed]
	return "%s Build one." % provider(item)


static func _waiting(s, b: Dictionary, name: String) -> String:
	var def: Dictionary = Data.BUILDINGS[b["type"]]
	if b["paused"]:
		return "%s: the %s is paused. Resume it." % [name, def["name"]]
	if def.get("lit", false) and not Bonuses.lit(s, b["pos"]):
		return "%s: the %s stands in the dark. %s" % [name, def["name"], shardlight(s)]
	if b["alert"].begins_with("Needs "):
		return "%s: the %s waits. %s" % [name, def["name"], b["status"]]
	return "%s: the %s is making it. Keep it running." % [name, def["name"]]


## The IN THE WAY line of a goal that asks for a building which is shut or whose price is not in the stockpile ("" when none, or the
## goal waits on a tech: Chain names that).
static func goal_note(s, g: Dictionary) -> String:
	if g.get("id", "") == "net_machine":
		return Power.reach_note(s)  # the distance to the nearest pole, so "within 2 tiles" is a number the player can see
	var type: String = g.get("building", "")
	if type == "" or not Data.BUILDINGS.has(type) or _stands(s, type):
		return ""
	var closed := shut(s, type)
	if closed != "":
		return closed
	for id in Data.BUILDINGS[type]["cost"]:
		if makers_of(id).is_empty():
			continue  # a gathered good is a hand's work, and the Stone Age goals already say how
		var line := why_short(s, id, Data.BUILDINGS[type]["cost"][id])
		if line != "":
			return (
				"The %s needs %d %s. %s"
				% [Data.BUILDINGS[type]["name"], Data.BUILDINGS[type]["cost"][id], Data.ITEMS[id]["name"], line]
			)
	return ""


## When goal `g` lacks a raw good whose ground the Kin have not found ("No Clay found yet. The nearest fog that hides it lies east
## (12 tiles); an expedition or a road reveals it."), "" when every good it lacks has its ground in sight or is made by a workshop
## (fun playtest 5: clay hid in fog and the goal never said so).
static func fog_note(s, g: Dictionary) -> String:
	var cost := {}
	if g.has("tech"):
		cost = s.tech_tree.cost_of(g["tech"])
	elif g.has("building") and Data.BUILDINGS.has(g["building"]):
		cost = Data.BUILDINGS[g["building"]]["cost"]
	var wanted := {}
	for id in cost:
		if int(s.economy.inv.get(id, 0)) < int(cost[id]):
			_down(id, wanted)
	for id in wanted:
		if not makers_of(id).is_empty() or int(s.economy.inv.get(id, 0)) > 0:
			continue
		var line := _fog_line(s, id)
		if line != "":
			return line
	return ""


static func _fog_line(s, item: String) -> String:
	var kinds: Array = []
	for t in Data.TILES:
		if Data.TILES[t]["yields"] == item:
			kinds.append(t)
	if kinds.is_empty():
		return ""
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			if not s.world.tile_at(p) in kinds:
				continue
			if s.fog.is_revealed(p):
				return ""  # its ground is in sight: the hint is not needed
			var d := Vector2(p).distance_to(Vector2(s.world.camp_pos))
			if d < best_d:
				best = p
				best_d = d
	var name: String = Data.ITEMS[item]["name"]
	if best.x < 0:
		return ""  # no such ground on the land the Kin have: the Look east button says where more lies
	return (
		"No %s found yet. The nearest fog that hides it lies %s (%d tiles); an expedition or a road reveals it."
		% [name, CardText.compass(Vector2(best - s.world.camp_pos)), roundi(best_d)]
	)


## What stands between the Kin and the Warning (the Starfall's gate, "Reach the Warning"), first step first: the Glyph Wall it is read
## on, the Lumen Ward the strangers wait for, their questions, and the marks set right. "" once all are done (fun playtest 5: this goal
## named no building, and 13 minutes went on a Glyph Wall that was never built).
static func warning_note(s) -> String:
	var sf = s.starfall
	if sf.ended:
		return ""
	if not sf.has_building("glyph_wall"):
		var why := goal_note(s, {"building": "glyph_wall"})
		return (
			"The Warning is read on the Glyph Wall: build one. " + why
			if why != ""
			else "The Warning is read on the Glyph Wall: build one (Workshops tab)."
		)
	if not sf.ward_stands():
		var why := goal_note(s, {"building": "lumen_ward"})
		return (
			"The strangers will not speak the Warning before a Lumen Ward stands: build one. " + why
			if why != ""
			else "The strangers will not speak the Warning before a Lumen Ward stands: build one."
		)
	if sf.questions_left() > 0:
		return "The strangers still have %d questions: answer their cards." % sf.questions_left()
	if not sf.warning_right():
		return "Set the Warning's marks on the Glyph Wall: each mark's word is guessed there."
	return ""


static func _stands(s, type: String) -> bool:
	for b in s.town.buildings:
		if b["type"] == type:
			return true
	return false
