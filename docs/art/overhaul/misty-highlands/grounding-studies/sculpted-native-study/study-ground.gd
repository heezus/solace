extends "res://scripts/world_ground.gd"
## Cached terrain masks with full-resolution world-space material shading.

const StudyArt = preload("res://docs/art/overhaul/misty-highlands/grounding-studies/sculpted-native-study/study-art.gd")

var _shore: Node2D
var _shore_state


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
		_surface.z_index = -2
		_material = ShaderMaterial.new()
		_material.shader = load(
			"res://docs/art/overhaul/misty-highlands/grounding-studies/sculpted-native-study/study-terrain.gdshader"
		)
		_material.set_shader_parameter("turf_texture", StudyArt.sheet("sculpted-ground"))
		_material.set_shader_parameter("water_texture", StudyArt.sheet("calm-river"))
		_material.set_shader_parameter("earth_texture", StudyArt.sheet("woodland-ground"))
		_material.set_shader_parameter("woodland_texture", StudyArt.sheet("woodland-ground"))
		_surface.material = _material
		_surface.draw.connect(_draw_surface)
		ci.add_child(_surface)
		_shore = Node2D.new()
		_shore.name = "TerrainShore"
		_shore.z_index = -1
		_shore.draw.connect(_draw_shore)
		ci.add_child(_shore)
	_material.set_shader_parameter("terrain_mask", texture)
	_material.set_shader_parameter("world_size", Vector2(s.world.width, s.world.height) * TILE)
	_material.set_shader_parameter("stone_paths", s.tech_tree.researched.has("causeways"))
	_material.set_shader_parameter("map_seed", float(s.world.map_seed % 10007))
	var rect := Rect2(Vector2(seen.position) * TILE, Vector2(seen.size) * TILE)
	if _rect != rect or _surface.get_meta("builds", -1) != builds:
		_rect = rect
		_shore_state = s
		_shore.queue_redraw()
		_surface.set_meta("builds", builds)
		_surface.queue_redraw()


## Small rendered stone/reed clusters add the same sculpted relief as map subjects.
func _draw_shore() -> void:
	for part in _shore_parts(_shore_state, Rect2i((_rect.position / TILE).floor(), (_rect.size / TILE).ceil())):
		var tex := StudyArt.sprite("riverbank-details", part["index"])
		StudyArt.fit(_shore, tex, Rect2(part["at"] - part["size"] * 0.5, part["size"]))


## Both water and neighboring land must be revealed: decorative banks never expose hidden rivers.
func _shore_parts(s, seen: Rect2i) -> Array:
	var result: Array = []
	for y in range(seen.position.y, seen.end.y):
		for x in range(seen.position.x, seen.end.x):
			var p := Vector2i(x, y)
			if not s.fog.is_revealed(p) or s.world.tile_at(p) != "river":
				continue
			for n in NEIGHBORS:
				var q: Vector2i = p + n
				if not s.world.in_bounds(q) or not s.fog.is_revealed(q) or s.world.tile_at(q) == "river":
					continue
				var edge := Vector2(p) + Vector2.ONE * 0.5 + Vector2(n) * 0.64
				var tangent := Vector2(-n.y, n.x)
				var count := 1 + StudyArt.variant(p, 3, 211 + n.x * 19 + n.y * 17, s.world.map_seed)
				for i in count:
					var family: int = 101 + n.x * 13 + n.y * 7 + i * 31
					var variation := StudyArt.variant(p, 6, family, s.world.map_seed)
					var spread := (float(StudyArt.variant(p, 17, family + 41, s.world.map_seed)) / 16.0 - 0.5) * 0.75
					var inset := (float(StudyArt.variant(p, 11, family + 67, s.world.map_seed)) / 10.0 - 0.4) * 0.18
					var at := (edge + tangent * spread + Vector2(n) * inset) * TILE
					var width := (20.0 if n.x != 0 else 28.0) + StudyArt.variant(p, 13, family + 83, s.world.map_seed)
					result.append({"at": at, "size": Vector2(width, width * 0.56), "index": variation})
	return result


func _draw_surface() -> void:
	_surface.draw_rect(_rect, Color.WHITE)


func _rebuild(s) -> void:
	_noise.seed = s.world.map_seed
	_noise.frequency = 0.12
	var size := Vector2i(s.world.width, s.world.height) * SAMPLES
	if _image == null or _image.get_size() != size or _seed != s.world.map_seed:
		_image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
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
	for y in range(-2, 4):
		for x in range(-2, 4):
			var q := tile + Vector2i(x, y)
			values.append(s.fog.is_revealed(q) and s.world.tile_at(q) == "river")
			values.append(s.fog.is_revealed(q) and s.world.roads.has(q))
			var occupied: bool = s.fog.is_revealed(q) and s.town.building_at.has(q)
			values.append(s.town.buildings[s.town.building_at[q]]["type"] if occupied else "")
			values.append(s.world.tile_at(q) if s.fog.is_revealed(q) else "")
	return hash(values)


func _paint_tile(s, tile: Vector2i) -> void:
	var woods: Array[float] = []
	for corner in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		woods.append(_forest_density(s, tile + corner))
	var aprons := _aprons(s, tile)
	for y in SAMPLES:
		for x in SAMPLES:
			var pixel := tile * SAMPLES + Vector2i(x, y)
			var p := (Vector2(pixel) + Vector2(0.5, 0.5)) / SAMPLES
			var n := _noise.get_noise_2dv(p)
			var wet := clampf(_river(s, p) + n * 0.025, 0.0, 1.0)
			var path := _road(s, p)
			var frac := p - Vector2(tile)
			var forest := lerpf(lerpf(woods[0], woods[1], frac.x), lerpf(woods[2], woods[3], frac.x), frac.y)
			var wear := 0.0
			for apron in aprons:
				var d := (p - Vector2(apron.x, apron.y)) / Vector2(apron.z, apron.w)
				wear = maxf(wear, 1.0 - smoothstep(0.5, 1.0, d.length() + n * 0.12))
			_image.set_pixelv(pixel, Color(wet, path, forest, wear))


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
	var distance := INF
	# Sample nearby road geometry even in the verge cell so shoulders and rounded ends do not clip to squares.
	for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var q: Vector2i = tile + offset
		if not s.fog.is_revealed(q) or not s.world.roads.has(q):
			continue
		var center := _road_center(q, s.world.map_seed)
		distance = minf(distance, p.distance_to(center))
		for n in NEIGHBORS:
			if s.fog.is_revealed(q + n) and (s.world.roads.has(q + n) or s.town.building_at.has(q + n)):
				var end: Vector2 = _road_center(q + n, s.world.map_seed)
				distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, center, end)))
	var edge := _noise.get_noise_2dv(p * 7.0) * 0.035
	return 1.0 - smoothstep(0.09, 0.29 + edge, distance)


func _road_center(tile: Vector2i, map_seed: int) -> Vector2:
	var offset := Vector2(StudyArt.variant(tile, 7, 19, map_seed) - 3, StudyArt.variant(tile, 7, 23, map_seed) - 3)
	return Vector2(tile) + Vector2(0.5, 0.5) + offset * 0.024


## Visual ground regions follow revealed tree groups, without new biome gameplay state.
func _forest_density(s, tile: Vector2i) -> float:
	var density := 0.0
	for y in range(-2, 3):
		for x in range(-2, 3):
			var q := tile + Vector2i(x, y)
			if s.fog.is_revealed(q) and s.world.tile_at(q) == "tree":
				density += maxf(0.0, 1.0 - Vector2(x, y).length() / 3.0)
	return clampf(density / 6.0, 0.0, 1.0)


## Worn contact areas follow visible building and resource bases, independently of road connectivity.
func _aprons(s, tile: Vector2i) -> Array[Vector4]:
	var result: Array[Vector4] = []
	for y in range(-1, 2):
		for x in range(-1, 2):
			var q := tile + Vector2i(x, y)
			if not s.fog.is_revealed(q):
				continue
			if s.world.tile_at(q) in ["rock", "plain_ore", "copper_hills", "clay", "gravel"]:
				result.append(Vector4(q.x + 0.5, q.y + 0.90, 0.43, 0.20))
			if not s.town.building_at.has(q):
				continue
			var b: Dictionary = s.town.buildings[s.town.building_at[q]]
			var hearth: bool = b["type"] == "camp"
			result.append(
				Vector4(q.x + 0.5, q.y + (1.43 if hearth else 0.94), 1.08 if hearth else 0.62, 0.52 if hearth else 0.32)
			)
	return result
