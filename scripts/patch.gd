extends RefCounted
## A Gatherer's Hut and the patch of one resource around it: which huts reach a tile, what a hut with a worker brings
## home a minute from its patch, and how many tiles that patch has. Numbers only, in tiles and seconds; the words are
## in scripts/field_text.gd. Static, and works on the Sim passed in.

const Data = preload("res://scripts/data.gd")
const Work = preload("res://scripts/work.gd")


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


## Seconds for one round of a hut's work on `tile`: the harvest and the walk out and back (open ground).
static func cycle_seconds(s, b: Dictionary, tile: Vector2i) -> float:
	var walk := 2.0 * Vector2(tile).distance_to(Vector2(b["pos"])) / Data.KITH_SPEED
	return Work.harvest_time(s, b, tile) + walk


## What one harvest of `tile` brings on average: the bundle, and a Field's extra share on top (Calendar and on).
static func yield_of(s, b: Dictionary, tile: Vector2i, item: String) -> float:
	return Work.bundle_size(s, b, item) * (1.0 + field_share(s, tile))


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


## Items a hut with a worker brings home a minute from the `tiles` it works, taking them in turn: what a round of
## every tile brings against what the round takes. 0 when there are none.
static func per_minute(s, b: Dictionary, tiles: Array, item: String) -> float:
	var got := 0.0
	var secs := 0.0
	for t in tiles:
		got += yield_of(s, b, t, item)
		secs += cycle_seconds(s, b, t)
	return got * 60.0 / secs if secs > 0.0 else 0.0
