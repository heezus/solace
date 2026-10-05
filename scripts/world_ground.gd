extends RefCounted
## Cached terrain masks with full-resolution world-space material shading.

const Rendered = preload("res://scripts/rendered_art.gd")
const NEIGHBORS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const SAMPLES := 16
const TILE := 48.0

var texture: ImageTexture
var revision := 0
var builds := 0
var _surface: Node2D
var _material: ShaderMaterial
var _rect := Rect2()
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
	if _surface == null:
		_surface = Node2D.new()
		_surface.name = "TerrainSurface"
		_surface.z_index = -1
		_material = ShaderMaterial.new()
		_material.shader = load("res://art/rendered/terrain.gdshader")
		_material.set_shader_parameter("turf_texture", Rendered.sheet("turf-v2"))
		_material.set_shader_parameter("water_texture", Rendered.sheet("river-v2"))
		_material.set_shader_parameter("earth_texture", Rendered.sheet("earth-v2"))
		_surface.material = _material
		_surface.draw.connect(_draw_surface)
		ci.add_child(_surface)
	_material.set_shader_parameter("terrain_mask", texture)
	_material.set_shader_parameter("world_size", Vector2(s.world.width, s.world.height) * TILE)
	_material.set_shader_parameter("stone_paths", s.tech_tree.researched.has("causeways"))
	_material.set_shader_parameter("map_seed", float(s.world.map_seed % 10007))
	var rect := Rect2(Vector2(seen.position) * TILE, Vector2(seen.size) * TILE)
	if _rect != rect or _surface.get_meta("builds", -1) != builds:
		_rect = rect
		_surface.set_meta("builds", builds)
		_surface.queue_redraw()


func _draw_surface() -> void:
	_surface.draw_rect(_rect, Color.WHITE)


func _rebuild(s) -> void:
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
			values.append(s.fog.is_revealed(q) and s.world.roads.has(q))
			values.append(s.town.building_at.has(q))
	return hash(values)


func _paint_tile(s, tile: Vector2i) -> void:
	for y in SAMPLES:
		for x in SAMPLES:
			var pixel := tile * SAMPLES + Vector2i(x, y)
			var p := (Vector2(pixel) + Vector2(0.5, 0.5)) / SAMPLES
			var n := _noise.get_noise_2dv(p)
			var wet := clampf(_river(s, p) + n * 0.025, 0.0, 1.0)
			var path := _road(s, p)
			_image.set_pixelv(pixel, Color(wet, path, (n + 1.0) * 0.5))


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
	if not s.fog.is_revealed(tile) or not s.world.roads.has(tile):
		return 0.0
	var center := _road_center(tile, s.world.map_seed)
	var distance := p.distance_to(center)
	for n in NEIGHBORS:
		if s.fog.is_revealed(tile + n) and (s.world.roads.has(tile + n) or s.town.building_at.has(tile + n)):
			var end: Vector2 = _road_center(tile + n, s.world.map_seed)
			distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, center, end)))
	return 1.0 - smoothstep(0.12, 0.22, distance)


func _road_center(tile: Vector2i, map_seed: int) -> Vector2:
	var offset := Vector2(Rendered.variant(tile, 7, 19, map_seed) - 3, Rendered.variant(tile, 7, 23, map_seed) - 3)
	return Vector2(tile) + Vector2(0.5, 0.5) + offset * 0.012
