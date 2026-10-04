extends RefCounted
## A Gatherer's Hut and the patch of one resource around it: which huts reach a tile, what a hut with a worker brings
## home a minute from its patch, and how many tiles that patch has. Numbers only, in tiles and seconds; the words are
## in scripts/field_text.gd and scripts/patch_text.gd; what a hut brings a minute is in scripts/patch_rate.gd.
## Static, and works on the Sim passed in.

const Data = preload("res://scripts/data.gd")


## The huts whose reach holds tile `p` (the Gatherer's Hut kind, built, in building-list order).
static func huts_reaching(s, p: Vector2i) -> Array:
	var out: Array = []
	var r: int = s.town.hut_radius()
	for b in s.town.buildings:
		if Data.BUILDINGS[b["type"]]["kind"] != "gatherer":
			continue
		var d: Vector2i = (b["pos"] - p).abs()
		if maxi(d.x, d.y) <= r:
			out.append(b)
	return out


## Whether a hut works `item` from where it stands: it has the tile in reach and its focus is that item.
static func works(s, b: Dictionary, item: String) -> bool:
	return b["focus"] == item and not s.town.focus_tiles(b).is_empty()


## A hut that is not built yet, at `p` and set to `item`: enough of a building for the timing and yield math.
static func ghost(p: Vector2i, item: String) -> Dictionary:
	return {"type": "gatherers_hut", "pos": p, "worker": -1, "focus": item, "field_extra": 0.0}


## The extra Speed (a share, 0.3 for +30%) a hut gets from `n` tiles of its resource in reach: Data.PATCH_STEP for each
## beyond the first, up to Data.PATCH_MAX_TILES tiles. 0 for none or one.
static func bonus(n: int) -> float:
	return Data.PATCH_STEP * (clampi(n, 1, Data.PATCH_MAX_TILES) - 1)


## Whether `n` tiles are all a hut can use: more add no Speed.
static func is_full(n: int) -> bool:
	return n >= Data.PATCH_MAX_TILES


## The Speed multiplier hut `b` gets from its patch now (its tiles in reach, Wild or Field): 1.0 for anything but a hut.
static func speed(s, b: Dictionary) -> float:
	if Data.BUILDINGS[b["type"]]["kind"] != "gatherer":
		return 1.0
	return 1.0 + bonus(s.town.focus_tiles(b).size())


## The extra share of a bundle a Field tile pays (Calendar, the Plough, the Ploughshare add up); 0 for wild tiles.
static func field_share(s, tile: Vector2i) -> float:
	if not s.world.fields.has(tile):
		return 0.0
	var researched: Dictionary = s.tech_tree.researched
	var more := 0.0
	more += Data.CALENDAR_FIELD_BONUS if researched.has("calendar") else 0.0
	more += Data.PLOUGH_FIELD_BONUS if researched.has("plough") else 0.0
	more += Data.PLOUGHSHARE_FIELD_BONUS if researched.has("bronze_ploughshare") else 0.0
	return more
