extends RefCounted
## Cached terrain masks with full-resolution world-space material shading.

const Rendered = preload("res://scripts/rendered_art.gd")
const NEIGHBORS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const SAMPLES := 16
const TILE := 48.0
## Every road is drawn as a path here: the gravel and paved tiers lie over it as their own material (RoadLayer), so
## Causeways no longer turns every road to stone.
const STONE_PATHS := false

var texture: ImageTexture
var revision := 0
var builds := 0
var _decals: Node2D
var _state
var _seen := Rect2i()
var _surface: Node2D
var _material: ShaderMaterial
var _rect := Rect2()
var _noise := FastNoiseLite.new()
var _image: Image
var _raw := PackedInt32Array()  # _raw_cells as of the last rebuild
var _seed := -1
var _river_corners := {}  # tile -> its river corners (Vector4), kept for one rebuild


func draw(ci: CanvasItem, s, seen: Rect2i) -> void:
	var stamp: int = hash(
		[s.world.tiles, s.world.roads, s.world.width, s.world.map_seed, s.town.building_at, s.fog.cells]
	)
	var revised := texture == null or stamp != revision
	if revised:
		_rebuild(s)
		revision = stamp
	if _surface == null:
		_surface = Node2D.new()
		_surface.name = "TerrainSurface"
		_surface.z_index = -1
		_material = ShaderMaterial.new()
		_material.shader = load("res://art/rendered/terrain.gdshader")
		var sheets := {
			"woodland_texture": "woodland-a",
			"woodland_b_texture": "woodland-b",
			"water_texture": "water-flow",
			"calm_texture": "water-calm",
			"bank_texture": "bank",
		}
		for slot in sheets:
			_material.set_shader_parameter(slot, Rendered.sheet(sheets[slot]))
		# Pack related sheets to stay within the Compatibility renderer's sampler budget.
		_material.set_shader_parameter("turf_texture", _material_atlas(["meadow-a", "meadow-b", "meadow-c"]))
		_material.set_shader_parameter("earth_texture", _material_atlas(["earth", "earth-south"]))
		_surface.material = _material
		_surface.draw.connect(_draw_surface)
		ci.add_child(_surface)
		_decals = Node2D.new()
		_decals.name = "TerrainDecals"
		_decals.z_index = -1
		_decals.draw.connect(_draw_decals)
		ci.add_child(_decals)
	_state = s
	_seen = seen
	_material.set_shader_parameter("south_start", float(s.world.base_height) * TILE)
	_material.set_shader_parameter("terrain_mask", texture)
	_material.set_shader_parameter("world_size", Vector2(s.world.width, s.world.height) * TILE)
	_material.set_shader_parameter("stone_paths", STONE_PATHS)
	_material.set_shader_parameter("map_seed", float(s.world.map_seed % 10007))
	var rect := Rect2(Vector2(seen.position) * TILE, Vector2(seen.size) * TILE)
	# Bare-grass fog reveals change decal visibility even when mask texels stay identical.
	if _rect != rect or _surface.get_meta("builds", -1) != builds or revised:
		_rect = rect
		_surface.set_meta("builds", builds)
		_surface.queue_redraw()
		_decals.queue_redraw()


func _draw_surface() -> void:
	_surface.draw_rect(_rect, Color.WHITE)


func _rebuild(s) -> void:
	_noise.seed = s.world.map_seed
	_noise.frequency = 0.12
	var size := Vector2i(s.world.width, s.world.height) * SAMPLES
	if _image == null or _image.get_size() != size or _seed != s.world.map_seed:
		_image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		_raw = PackedInt32Array()
		texture = null
		_seed = s.world.map_seed
	var w: int = s.world.width
	var h: int = s.world.height
	var now := _raw_cells(s)
	var dirty := {}  # tile -> true: every tile whose picture reads a tile that changed (the window _paint_tile looks at)
	for i in now.size():
		if _raw.size() == now.size() and _raw[i] == now[i]:
			continue
		var at := Vector2i(i % w, floori(float(i) / w))
		for dy in range(-3, 3):
			for dx in range(-3, 3):
				var t := at + Vector2i(dx, dy)
				if t.x >= 0 and t.y >= 0 and t.x < w and t.y < h:
					dirty[t] = true
	_raw = now
	_river_corners.clear()
	for tile in dirty:
		_paint_tile(s, tile)
	if not dirty.is_empty():
		if texture == null:
			texture = ImageTexture.create_from_image(_image)
		else:
			texture.update(_image)
		builds += 1


## What each tile contributes to its neighbours' ground, as one number: whether the fog is lifted on it, and what stands, grows or
## runs there. Worked out in a single pass, so a change is found without walking every tile's whole neighbourhood.
func _raw_cells(s) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(s.world.width * s.world.height)
	for y in s.world.height:
		for x in s.world.width:
			var q := Vector2i(x, y)
			if not s.fog.is_revealed(q):
				continue
			var kind: String = s.world.tile_at(q)
			var v := (
				1 | (2 if kind == "river" else 0) | (4 if kind == "tree" else 0) | (8 if s.world.roads.has(q) else 0)
			)
			if s.town.building_at.has(q):
				v |= hash(s.town.buildings[s.town.building_at[q]]["type"]) << 4
			out[y * s.world.width + x] = v
	return out


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
	var v: Vector4 = _river_corners.get(tile, Vector4(-1, 0, 0, 0))
	if v.x < 0.0:  # the four tiles round this corner, looked at once for all the pixels in it
		var values: Array[float] = []
		for n in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			var q: Vector2i = tile + n
			q.x = clampi(q.x, 0, s.world.width - 1)
			q.y = clampi(q.y, 0, s.world.height - 1)
			values.append(1.0 if s.fog.is_revealed(q) and s.world.tile_at(q) == "river" else 0.0)
		v = Vector4(values[0], values[1], values[2], values[3])
		_river_corners[tile] = v
	return lerpf(lerpf(v.x, v.y, frac.x), lerpf(v.z, v.w, frac.x), frac.y)


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
	return 1.0 - smoothstep(0.10, 0.23, distance)


func _road_center(tile: Vector2i, map_seed: int) -> Vector2:
	var offset := Vector2(Rendered.variant(tile, 7, 19, map_seed) - 3, Rendered.variant(tile, 7, 23, map_seed) - 3)
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


## A small worn apron at each visible foundation; Hearth art spans two cells but its gameplay does not.
func _aprons(s, tile: Vector2i) -> Array[Vector4]:
	var result: Array[Vector4] = []
	for y in range(-1, 2):
		for x in range(-1, 2):
			var q := tile + Vector2i(x, y)
			if not s.fog.is_revealed(q) or not s.town.building_at.has(q):
				continue
			var b: Dictionary = s.town.buildings[s.town.building_at[q]]
			var hearth: bool = b["type"] == "camp"
			result.append(
				Vector4(q.x + 0.5, q.y + (1.15 if hearth else 0.94), 1.0 if hearth else 0.56, 0.52 if hearth else 0.28)
			)
	return result


## Cosmetic scatter uses only coordinate hashes and revealed masks; never simulation RNG.
func _draw_decals() -> void:
	var atlas := Rendered.sheet("decals")
	for decal in decal_layout(_state, _seen):
		var cell := int(decal.z)
		var source := Rect2(Vector2(cell % 8, floori(cell / 8.0)) * 96.0, Vector2(96, 96))
		var size := 32.0 if cell >= 24 else 24.0
		_decals.draw_texture_rect_region(
			atlas, Rect2(Vector2(decal.x, decal.y) - Vector2.ONE * size * 0.5, Vector2.ONE * size), source
		)


func decal_layout(s, seen: Rect2i) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for y in range(maxi(0, seen.position.y), mini(s.world.height, seen.end.y)):
		for x in range(maxi(0, seen.position.x), mini(s.world.width, seen.end.x)):
			var tile := Vector2i(x, y)
			if not s.fog.is_revealed(tile) or s.world.tile_at(tile) == "river":
				continue
			var map_seed: int = s.world.map_seed
			var offset := Vector2(
				Rendered.variant(tile, 23, 71, map_seed) - 11, Rendered.variant(tile, 23, 73, map_seed) - 11
			)
			var center := (Vector2(tile) + Vector2(0.5, 0.5)) * TILE + offset
			var mask := _image.get_pixelv(Vector2i(center / TILE * SAMPLES))
			if mask.g > 0.02 or mask.a > 0.04 or mask.r > 0.30:
				continue
			var roll := Rendered.variant(tile, 100, 79, map_seed)
			var cell: int
			if mask.r > 0.08:
				cell = 24 + Rendered.variant(tile, 8, 83, map_seed)
			elif mask.b > 0.30:
				if roll > 68:
					continue
				cell = 18 + Rendered.variant(tile, 6, 89, map_seed)
			else:
				if roll > 42:
					continue
				cell = Rendered.variant(tile, 18, 97, map_seed)
			if not _decal_clear(s, center, cell >= 24):
				continue
			result.append(Vector3(center.x, center.y, cell))
	return result


func _decal_clear(s, center: Vector2, bank: bool) -> bool:
	for offset in [Vector2.ZERO, Vector2(-20, -20), Vector2(20, -20), Vector2(-20, 20), Vector2(20, 20)]:
		var p: Vector2 = center + offset
		var tile := Vector2i((p / TILE).floor())
		if not s.world.in_bounds(tile) or not s.fog.is_revealed(tile) or s.town.building_at.has(tile):
			return false
		var mask := _image.get_pixelv(Vector2i(p / TILE * SAMPLES))
		if mask.g > 0.02 or mask.a > 0.04 or mask.r > (0.72 if bank else 0.38):
			return false
	return true


func _material_atlas(names: Array[String]) -> ImageTexture:
	var atlas := Image.create(1920 * names.size(), 1920, false, Image.FORMAT_RGB8)
	for index in names.size():
		var source: Texture2D = load("res://art/rendered/" + names[index] + ".png")
		var image := source.get_image()
		image.convert(Image.FORMAT_RGB8)
		atlas.blit_rect(image, Rect2i(0, 0, 1920, 1920), Vector2i(index * 1920, 0))
	return ImageTexture.create_from_image(atlas)
