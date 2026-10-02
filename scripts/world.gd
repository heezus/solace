extends RefCounted
## The World block: the tiles of the map, where the camp and the star shard are, and the roads and
## fields laid on it. It stands alone: it reads Data and nothing else, and never reaches into another
## block. Fog (which tiles have been seen) is its own block and is not held here. What a tile costs to
## walk over is the Pathing block's business, and what may be built on it is decided by the caller.
## Sim owns one, reached as `sim.world`.
## At Bronze Dawn the map doubles to the east (grow_east): the stone-age half keeps every tile, and the new land comes
## from MapEast with the same seed, so a seed always grows the same land.
## Signal: grew(from_width) fires when the map grows, with the width it had; the owner lifts the walking grid and fog.

signal grew(from_width: int)

const Codec = preload("res://scripts/save_codec.gd")
const Data = preload("res://scripts/data.gd")
const MapGen = preload("res://scripts/map_gen.gd")
const MapEast = preload("res://scripts/map_east.gd")

const WIDTH := 36
const HEIGHT := 22
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var width: int
var height: int
var stone_width: int  # the width the map was made with: the stone-age half. The map is wider once it has grown
var map_seed := 0  # the seed the map was made from, so the land that grows east comes from the same one
var tiles: Array = []  # flat array of tile ids, index = y * width + x
var camp_pos := Vector2i.ZERO
var shard_pos := Vector2i(-1, -1)
var roads: Dictionary = {}  # Vector2i -> true (a bridge is a road over the river)
var stone_bridges: Dictionary = {}  # Vector2i -> true, the bridges among them that are stone (they bear carts)
var fields: Dictionary = {}  # Vector2i -> true, grain tiles that were sown


## A map of open grass, `w` by `h` tiles (the game's size unless a test wants a tiny one).
func _init(w: int = WIDTH, h: int = HEIGHT) -> void:
	width = w
	height = h
	stone_width = w
	reset()


## Make the whole map `tile`. Roads and fields are not touched.
func reset(tile: String = "grass") -> void:
	tiles.clear()
	tiles.resize(width * height)
	tiles.fill(tile)


## Make a new map from `seed_value`: the same seed always makes the same map (see MapGen).
func generate(seed_value: int) -> void:
	width = stone_width  # a new map starts as the stone-age half again
	map_seed = seed_value
	MapGen.generate(self, seed_value)


## True once the map has doubled east (see grow_east).
func is_grown() -> bool:
	return width > stone_width


## Double the map to the east: every tile of the stone-age half stays as it is, and the new land beside it is made by
## MapEast from the map's seed (ore in it, copper near its west edge and tin far to the north-east). The new tiles are
## the last `stone_width` columns. Does nothing and returns false when the map has grown already.
func grow_east() -> bool:
	if is_grown():
		return false
	var old := width
	var land: Array = MapEast.make(self)
	var grown: Array = []
	grown.resize(old * 2 * height)
	for y in height:
		for x in old:
			grown[y * old * 2 + x] = tiles[y * old + x]
			grown[y * old * 2 + old + x] = land[y * old + x]
	width = old * 2
	tiles = grown
	grew.emit(old)
	return true


# --- Tiles -------------------------------------------------------------------


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


## The tile id at p, or "" off the map.
func tile_at(p: Vector2i) -> String:
	if not in_bounds(p):
		return ""
	return tiles[p.y * width + p.x]


## Change the tile at p. Off the map, nothing happens.
func set_tile(p: Vector2i, tile: String) -> void:
	if in_bounds(p):
		tiles[p.y * width + p.x] = tile


## True if a tile beside p (not diagonal) is `tile`.
func touches(p: Vector2i, tile: String) -> bool:
	for n in NEIGHBORS:
		if tile_at(p + n) == tile:
			return true
	return false


func touches_river(p: Vector2i) -> bool:
	return touches(p, "river")


## Resource tiles within `radius` of p (a square), in row order: what a gatherer standing at p could work.
func gather_tiles(p: Vector2i, radius: int) -> Array:
	var found: Array = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var t := tile_at(p + Vector2i(dx, dy))
			if t != "" and t != "grass" and Data.TILES[t]["yields"] != "" and not Data.TILES[t].get("mine_only", false):
				found.append(p + Vector2i(dx, dy))
	return found


# --- Roads and fields ----------------------------------------------------------


## Lay a road (or a bridge, on a river tile) at p. The tile itself is left as it is.
func add_road(p: Vector2i) -> void:
	roads[p] = true


func remove_road(p: Vector2i) -> void:
	roads.erase(p)
	stone_bridges.erase(p)


## Lay a stone bridge at p: a road over the river that is also remembered as stone.
func add_stone_bridge(p: Vector2i) -> void:
	roads[p] = true
	stone_bridges[p] = true


## True for a river tile with a Wooden Bridge on it: a road the Kith cross but a cart does not.
func is_wooden_bridge(p: Vector2i) -> bool:
	return roads.has(p) and not stone_bridges.has(p) and tile_at(p) == "river"


## Sow a field at p: the tile becomes grain and is remembered as sown.
func add_field(p: Vector2i) -> void:
	set_tile(p, "grain")
	fields[p] = true


## Clear the field at p: the tile goes back to grass.
func remove_field(p: Vector2i) -> void:
	fields.erase(p)
	set_tile(p, "grass")


# --- Save --------------------------------------------------------------------


## The map as JSON-safe values: its size, the tiles, the camp and shard positions, the roads and the fields
## (each in the order they were laid).
func to_dict() -> Dictionary:
	return {
		"width": width,
		"height": height,
		"stone_width": stone_width,
		"map_seed": map_seed,
		"tiles": tiles.duplicate(),
		"camp_pos": Codec.vec(camp_pos),
		"shard_pos": Codec.vec(shard_pos),
		"roads": Codec.vec_keys(roads),
		"stone_bridges": Codec.vec_keys(stone_bridges),
		"fields": Codec.vec_keys(fields),
	}


## Restore what to_dict wrote, in place. A save whose tile list doesn't fit its size leaves open grass.
func from_dict(d: Dictionary) -> void:
	width = int(d.get("width", width))
	height = int(d.get("height", height))
	stone_width = int(d.get("stone_width", width))
	map_seed = int(d.get("map_seed", 0))
	reset()
	var saved: Array = d.get("tiles", [])
	if saved.size() == width * height:
		tiles = Codec.strings(saved)
	camp_pos = Codec.to_vec(d.get("camp_pos", [0, 0]))
	shard_pos = Codec.to_vec(d.get("shard_pos", [-1, -1]))
	roads = Codec.to_vec_set(d.get("roads", []))
	stone_bridges = Codec.to_vec_set(d.get("stone_bridges", []))
	fields = Codec.to_vec_set(d.get("fields", []))
