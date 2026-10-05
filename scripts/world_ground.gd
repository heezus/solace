extends RefCounted
## One cached world-space terrain surface, shared at every zoom. No independently tiled ground plates.

const Rendered = preload("res://scripts/rendered_art.gd")
const NEIGHBORS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const SAMPLES := 16
const TILE := 48.0

var texture: ImageTexture
var revision := 0
var builds := 0
var _grass: Image
var _water: Image
var _noise := FastNoiseLite.new()
var _image: Image
var _tile_stamps := {}
var _seed := -1


func draw(ci: CanvasItem, s, seen: Rect2i) -> void:
	var stamp: int = hash(
		[
			s.world.tiles,
			s.world.roads,
			s.world.width,
			s.world.map_seed,
			s.town.building_at,
			s.tech_tree.researched.has("causeways"),
			s.fog.cells
		]
	)
	if texture == null or stamp != revision:
		_rebuild(s)
		revision = stamp
	var rect := Rect2(Vector2(seen.position) * TILE, Vector2(seen.size) * TILE)
	ci.draw_texture_rect_region(texture, rect, Rect2(Vector2(seen.position) * SAMPLES, Vector2(seen.size) * SAMPLES))


func _rebuild(s) -> void:
	if _grass == null:
		_grass = Rendered.sheet("meadow").get_image()
		_water = Rendered.sheet("water").get_image()
	_noise.seed = s.world.map_seed
	_noise.frequency = 0.12
	var size := Vector2i(s.world.width, s.world.height) * SAMPLES
	if _image == null or _image.get_size() != size or _seed != s.world.map_seed:
		_image = Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
		_tile_stamps.clear()
		texture = null
		_seed = s.world.map_seed
	var dirty := false
	for y in s.world.height:
		for x in s.world.width:
			var tile := Vector2i(x, y)
			var stamp := _tile_key(s, tile)
			if _tile_stamps.get(tile, -1) == stamp:
				continue
			_tile_stamps[tile] = stamp
			dirty = true
			_paint_tile(s, tile)
	if dirty:
		if texture == null:
			texture = ImageTexture.create_from_image(_image)
		else:
			texture.update(_image)
		builds += 1


func _tile_key(s, tile: Vector2i) -> int:
	var values: Array = [s.tech_tree.researched.has("causeways")]
	for y in range(-1, 2):
		for x in range(-1, 2):
			var q := tile + Vector2i(x, y)
			values.append(s.fog.is_revealed(q) and s.world.tile_at(q) == "river")
			values.append(s.world.roads.has(q))
			values.append(s.town.building_at.has(q))
	return hash(values)


func _paint_tile(s, tile: Vector2i) -> void:
	for y in SAMPLES:
		for x in SAMPLES:
			var pixel := tile * SAMPLES + Vector2i(x, y)
			var p := (Vector2(pixel) + Vector2(0.5, 0.5)) / SAMPLES
			var n := _noise.get_noise_2dv(p)
			var turf := _sample(_grass, p * 48.0)
			turf = turf.lerp(Color("486956"), 0.32).lightened(n * 0.065)
			var wet := _river(s, p) + n * 0.025
			var bank := smoothstep(0.32, 0.48, wet) * (1.0 - smoothstep(0.48, 0.64, wet))
			turf = turf.lerp(Color("879077"), bank * 0.45)
			var water := _sample(_water, p * 56.0).lerp(Color("47747c"), 0.25)
			var col := turf.lerp(water, smoothstep(0.44, 0.56, wet))
			var path := _road(s, p) * (1.0 - smoothstep(0.4, 0.6, wet))
			var dirt := Color("9e9479").lightened(n * 0.08)
			if s.tech_tree.researched.has("causeways"):
				dirt = Color("93988b").lightened(n * 0.06)
			_image.set_pixelv(pixel, col.lerp(dirt, path * 0.9))


func _sample(img: Image, p: Vector2) -> Color:
	return img.get_pixel(posmod(int(p.x), img.get_width()), posmod(int(p.y), img.get_height()))


func _river(s, p: Vector2) -> float:
	var shifted := p - Vector2(0.5, 0.5)
	var tile := Vector2i(shifted.floor())
	var frac := shifted - Vector2(tile)
	var values: Array[float] = []
	for n in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		var q: Vector2i = tile + n
		q.x = clampi(q.x, 0, s.world.width - 1)
		q.y = clampi(q.y, 0, s.world.height - 1)
		values.append(1.0 if s.fog.is_revealed(q) and s.world.tile_at(q) == "river" else 0.0)
	return lerpf(lerpf(values[0], values[1], frac.x), lerpf(values[2], values[3], frac.x), frac.y)


func _road(s, p: Vector2) -> float:
	var tile := Vector2i(p.floor())
	if not s.world.roads.has(tile):
		return 0.0
	var center := Vector2(tile) + Vector2(0.5, 0.5)
	var distance := p.distance_to(center)
	for n in NEIGHBORS:
		if s.world.roads.has(tile + n) or s.town.building_at.has(tile + n):
			var end: Vector2 = center + Vector2(n) * 0.51
			distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, center, end)))
	return 1.0 - smoothstep(0.17, 0.25, distance)
