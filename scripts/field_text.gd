extends RefCounted
## What a Field is for, in plain words with live numbers: the Info panel's lines for a sown tile, the build card's
## tooltip, and the pill while fields are being laid. A Field is a sown tile of a crop; it pays only through a Gatherer's
## Hut that reaches it and works that crop, so every line says which huts do. The crop is read from the tile (its
## `yields`), so another crop's field reads the same. Static, and works on the Sim passed in. The wording is in Data
## (scripts/data/words.gd); the numbers are in scripts/patch.gd.

const Data = preload("res://scripts/data.gd")
const Patch = preload("res://scripts/patch.gd")


## The Info panel's lines under a sown tile: which huts reap it and how much, what a field pays over wild growth, the
## river, and what the crop is for. "" for a tile that is not a field.
static func tile_text(s, p: Vector2i) -> String:
	if not s.world.fields.has(p):
		return ""
	var item: String = Data.TILES[s.world.tile_at(p)]["yields"]
	var lines: Array = [hut_line(s, p, item), yield_line(s, p, item)]
	var river := river_line(s, p)
	if river != "":
		lines.append(river)
	var mill := mill_line(item)
	if mill != "":
		lines.append(mill)
	return "\n".join(lines)


## Who reaps the field at `p`: nobody in reach (and how to fix that), a hut with another job or no worker, or the huts
## that do with what they bring home a minute.
static func hut_line(s, p: Vector2i, item: String) -> String:
	var huts := Patch.huts_reaching(s, p)
	if huts.is_empty():
		return Data.FIELD_NO_HUT % s.town.hut_radius()
	var item_name: String = Data.ITEMS[item]["name"]
	var working: Array = []
	var other := ""
	var empty := false
	for b in huts:
		if not Patch.works(s, b, item):
			other = b["focus"] if other == "" else other
		elif b["worker"] < 0:
			empty = true
		else:
			working.append(b)
	if working.is_empty():
		if other != "":
			return Data.FIELD_HUT_OTHER % [Data.ITEMS[other]["name"], item_name]
		return Data.FIELD_HUT_EMPTY % Data.PEOPLE["one"] if empty else Data.FIELD_NO_HUT % s.town.hut_radius()
	var total := 0.0
	for b in working:
		total += Patch.per_minute(s, b, s.town.focus_tiles(b), item)
	if working.size() == 1:
		return Data.FIELD_HUT_WORKS % [num(total), item_name, s.town.focus_tiles(working[0]).size()]
	return Data.FIELD_HUTS_WORK % [working.size(), num(total), item_name]


## What a field pays over the wild plant: the share Calendar and on give, or which tech would.
static func yield_line(s, p: Vector2i, item: String) -> String:
	var item_name: String = Data.ITEMS[item]["name"]
	var share := Patch.field_share(s, p)
	if share > 0.0:
		return Data.FIELD_PAYS % [roundi(share * 100.0), item_name]
	return (
		Data.FIELD_PAYS_LATER % [item_name, Data.TECHS["calendar"]["name"], roundi(Data.CALENDAR_FIELD_BONUS * 100.0)]
	)


## A field on the river bank is harvested twice as fast once Irrigation is known; "" when it is not on the bank.
static func river_line(s, p: Vector2i) -> String:
	if not s.world.touches_river(p):
		return ""
	if s.tech_tree.researched.has("irrigation"):
		return Data.FIELD_RIVER
	return Data.FIELD_RIVER_LATER % Data.TECHS["irrigation"]["name"]


## What the crop is for, when it is not eaten raw: the workshop that mills it and into what. "" for none.
static func mill_line(item: String) -> String:
	if Data.FOOD_VALUE.has(item):
		return ""
	for type in Data.BUILD_ORDER:
		var def: Dictionary = Data.BUILDINGS[type]
		if def["kind"] == "processor" and def.get("in", {}).has(item) and not def.get("out", {}).is_empty():
			var made: String = def["out"].keys()[0]
			return (
				Data.FIELD_MILL
				% [
					Data.ITEMS[item]["name"],
					def["name"],
					"%d %s" % [def["in"][item], Data.ITEMS[item]["name"]],
					"%d %s" % [def["out"][made], Data.ITEMS[made]["name"]]
				]
			)
	return ""


## The build card's tooltip lines: how many of your fields have no hut in reach, and what the crop is for.
static func card_text(s, crop: String) -> String:
	var fields: Array = s.world.fields.keys()
	var idle := 0
	for p in fields:
		if Patch.huts_reaching(s, p).is_empty():
			idle += 1
	var lines: Array = []
	if fields.is_empty():
		lines.append(Data.FIELD_CARD_NONE)
	elif idle == 0:
		lines.append(Data.FIELD_CARD_OK % fields.size())
	else:
		lines.append(Data.FIELD_CARD % [idle, fields.size(), s.town.hut_radius()])
	lines.append(Data.FIELD_CARD_RULE % [s.town.hut_radius(), Data.ITEMS[crop]["name"]])
	var mill := mill_line(crop)
	if mill != "":
		lines.append(mill)
	return "\n".join(lines)


## The line the Info panel adds while a field is being placed at `p`: the huts that would reap it, or how to get one.
static func placing_text(s, p: Vector2i) -> String:
	var huts := Patch.huts_reaching(s, p)
	if huts.is_empty():
		return Data.FIELD_NO_HUT % s.town.hut_radius()
	return Data.FIELD_PLACE_HUT % ("1 hut" if huts.size() == 1 else "%d huts" % huts.size())


## What a dragged line of fields adds to the pill: how many of its tiles a hut reaches.
static func drag_note(s, tiles: Array) -> String:
	var in_reach := 0
	for p in tiles:
		if s.town.placement_error("field", p) == "" and not Patch.huts_reaching(s, p).is_empty():
			in_reach += 1
	return Data.FIELD_DRAG_SOME % in_reach if in_reach > 0 else Data.FIELD_DRAG_NONE


## A number of items a minute, to one place with no trailing ".0" ("9", "9.4").
static func num(x: float) -> String:
	return str(snappedf(x, 0.1)).trim_suffix(".0")
