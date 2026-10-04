extends RefCounted
## What a Gatherer's Hut brings home a minute from its patch, worked out from the same timing and yield the game uses
## (scripts/work.gd): a round of every tile it works, in turn, against the time the round takes. Also what one more tile
## adds. Static, and works on the Sim passed in. Kept apart from scripts/patch.gd, which Work reads for the patch's Speed.

const Data = preload("res://scripts/data.gd")
const Work = preload("res://scripts/work.gd")
const Patch = preload("res://scripts/patch.gd")


## Seconds for one round of a hut's work on `tile`: the harvest and the walk out and back (open ground). `count` is how
## many tiles the patch has (the hut's own count when -1), for working out what one more tile would do.
static func cycle_seconds(s, b: Dictionary, tile: Vector2i, count := -1) -> float:
	var walk := 2.0 * Vector2(tile).distance_to(Vector2(b["pos"])) / Data.KITH_SPEED
	var harvest := Work.harvest_time(s, b, tile)
	if count >= 0:
		harvest *= Patch.speed(s, b) / (1.0 + Patch.bonus(count))
	return harvest + walk


## What one harvest of `tile` brings on average: the bundle, and a Field's extra share on top (Calendar and on).
static func yield_of(s, b: Dictionary, tile: Vector2i, item: String) -> float:
	return Work.bundle_size(s, b, item) * (1.0 + Patch.field_share(s, tile))


## Items a hut with a worker brings home a minute from the `tiles` it works, taking them in turn: what a round of
## every tile brings against what the round takes. 0 when there are none.
static func per_minute(s, b: Dictionary, tiles: Array, item: String) -> float:
	var got := 0.0
	var secs := 0.0
	for t in tiles:
		got += yield_of(s, b, t, item)
		secs += cycle_seconds(s, b, t, tiles.size())
	return got * 60.0 / secs if secs > 0.0 else 0.0


## What the tile `p` adds to hut `b` a minute: its rate with `p` among its tiles against without it. 0 when the hut
## works something else.
static func tile_gain(s, b: Dictionary, p: Vector2i, item: String) -> float:
	if not Patch.works(s, b, item):
		return 0.0
	var with: Array = s.town.focus_tiles(b)
	var without := with.duplicate()
	if with.has(p):
		without.erase(p)
	else:
		with.append(p)
	return per_minute(s, b, with, item) - per_minute(s, b, without, item)
