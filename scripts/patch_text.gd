extends RefCounted
## What the tiles in a Gatherer's Hut's reach do, in plain words: the line under the placement preview, the short pill
## on the map, and the lines on the hut's own panel. More tiles of the hut's resource in reach make it work faster, up to
## a cap (Data.PATCH_STEP, Data.PATCH_MAX_TILES), and the words say which step the hut is on and when more tiles stop
## helping. Static, and works on the Sim passed in. The wording is in Data (scripts/data/words.gd).

const Data = preload("res://scripts/data.gd")
const Patch = preload("res://scripts/patch.gd")
const PatchRate = preload("res://scripts/patch_rate.gd")
const FieldText = preload("res://scripts/field_text.gd")


## "4 Clay tiles in range: +30% speed. Each extra tile adds +10%, up to +50% at 6 tiles." for `n` tiles of `item` in reach.
## "" when there are none.
static func tiles_line(item: String, n: int) -> String:
	if n <= 0:
		return ""
	var name: String = Data.ITEMS[item]["name"]
	var count := "%d %s tile%s" % [n, name, "" if n == 1 else "s"]
	var step := roundi(Data.PATCH_STEP * 100.0)
	var most := roundi(Patch.bonus(Data.PATCH_MAX_TILES) * 100.0)
	if n >= Data.PATCH_MAX_TILES:
		return Data.PATCH_FULL % [count, most]
	if n == 1:
		return Data.PATCH_ONE % [count, step, most, Data.PATCH_MAX_TILES]
	return Data.PATCH_SOME % [count, roundi(Patch.bonus(n) * 100.0), step, most, Data.PATCH_MAX_TILES]


## The Info panel's line while a hut is being placed at `p` to work `item` (the picker's choice, or its default).
static func placement_text(s, p: Vector2i, item: String) -> String:
	return tiles_line(item, s.town.tiles_of(p, item).size()) if item != "" else ""


## The short pill on the map under the placement ghost: "Clay x4 · +30% speed".
static func pill_text(s, p: Vector2i, item: String) -> String:
	var n: int = s.town.tiles_of(p, item).size() if item != "" else 0
	if n < 2:
		return ""
	var pct := roundi(Patch.bonus(n) * 100.0)
	return Data.PATCH_PILL % [Data.ITEMS[item]["name"], n, pct]


## The hut panel's lines: how many tiles it has, the speed they give, what it brings home a minute, how many are Fields.
static func panel_text(s, b: Dictionary) -> String:
	var item: String = b["focus"]
	var tiles: Array = s.town.focus_tiles(b)
	if item == "" or tiles.is_empty():
		return ""
	var lines: Array = [tiles_line(item, tiles.size())]
	var fields := 0
	for t in tiles:
		fields += 1 if s.world.fields.has(t) else 0
	if fields > 0:
		lines.append(Data.PATCH_FIELDS % [fields, tiles.size()])
	if s.people.knows(item):
		lines.append(
			Data.PATCH_RATE % [FieldText.num(PatchRate.per_minute(s, b, tiles, item)), Data.ITEMS[item]["name"]]
		)
	return "\n".join(lines)


## The pill under the placement ghost with the hut's patch added to `note`: "To Hearth · 11 tiles · 22 s a trip · Clay x4 · +30% speed".
static func with_pill(s, placing: String, p: Vector2i, item: String, note: String) -> String:
	if placing != "gatherers_hut":
		return note
	var pill := pill_text(s, p, item)
	return note if pill == "" else (pill if note == "" else note + " · " + pill)
