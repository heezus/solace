extends "res://docs/art/overhaul/misty-highlands/grounding-studies/shoreline-crossings-study/study-ground.gd"
## Review-only layered materials. Simulation and tile identities remain unchanged.
const Patches = preload("res://docs/art/overhaul/misty-highlands/grounding-studies/beauty-slice/patches.gd")
var layered := false
var _patch_layer: Node2D
var _patch_stamp := 0


func draw(ci: CanvasItem, s, seen: Rect2i) -> void:
	super.draw(ci, s, seen)
	if layered:
		_material.shader = load(
			"res://docs/art/overhaul/misty-highlands/grounding-studies/beauty-slice/terrain.gdshader"
		)
		_material.set_shader_parameter("turf_texture", StudyArt.sheet("meadow-ground"))
		_material.set_shader_parameter("water_texture", StudyArt.sheet("calm-river"))
		_material.set_shader_parameter("earth_texture", StudyArt.sheet("woodland-ground"))
		_material.set_shader_parameter("terrain_mask", texture)
		_material.set_shader_parameter("world_size", Vector2(s.world.width, s.world.height) * TILE)
		_material.set_shader_parameter("map_seed", float(s.world.map_seed % 10007))
		if _patch_layer == null:
			_patch_layer = Node2D.new()
			_patch_layer.name = "GroundCoverLayer"
			_patch_layer.z_index = -1
			ci.add_child(_patch_layer)
			ci.move_child(_patch_layer, _shore.get_index())
		if _patch_stamp != revision:
			_patch_stamp = revision
			for child in _patch_layer.get_children():
				child.queue_free()
			for part in _patch_parts(s):
				var tex := Patches.sprite(part.index)
				var sprite := Sprite2D.new()
				sprite.texture = tex
				sprite.position = part.at
				var factor := minf(part.size.x / tex.get_width(), part.size.y / tex.get_height())
				sprite.scale = Vector2.ONE * factor
				var material := ShaderMaterial.new()
				material.shader = load(
					"res://docs/art/overhaul/misty-highlands/grounding-studies/beauty-slice/patch.gdshader"
				)
				material.set_shader_parameter("terrain_mask", texture)
				material.set_shader_parameter("world_size", Vector2(s.world.width, s.world.height) * TILE)
				material.set_shader_parameter("patch_center", part.at)
				material.set_shader_parameter("patch_scale", factor)
				material.set_shader_parameter("region_origin", tex.region.position)
				material.set_shader_parameter("region_size", tex.region.size)
				material.set_shader_parameter("opacity", part.alpha)
				sprite.material = material
				_patch_layer.add_child(sprite)


func _draw_shore() -> void:
	for part in _shore_parts(_shore_state, Rect2i((_rect.position / TILE).floor(), (_rect.size / TILE).ceil())):
		var size: Vector2 = part.size * (1.25 if layered else 1.0)
		StudyArt.fit(_shore, Props.sprite(part.index), Rect2(part.at - size * 0.5, size))


func _patch_parts(s) -> Array:
	var result: Array = []
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			if not s.fog.is_revealed(p) or s.world.tile_at(p) == "river":
				continue
			var type: String = s.world.tile_at(p)
			var woods := _forest_density(s, p)
			var family := StudyArt.variant(p, 100, 533, s.world.map_seed)
			var shore := false
			for n in NEIGHBORS:
				shore = shore or (s.fog.is_revealed(p + n) and s.world.tile_at(p + n) == "river")
			if not shore and type not in ["tree", "rock", "berry"] and family > (24 if woods > 0.2 else 8):
				continue
			var at := (Vector2(p) + Vector2(0.5, 0.68)) * TILE
			var width := 80.0 + StudyArt.variant(p, 39, 541, s.world.map_seed)
			var index := StudyArt.variant(p, 3, 577, s.world.map_seed)
			if shore:
				index = 5 if family % 3 != 0 else 3
				width = 65.0 + family % 29
			elif type == "rock":
				index = 3
			elif type == "tree" and family % 3 == 0:
				index = 4
			# All cells touched by the sprite must be known, so the overlay cannot leak hidden ground.
			var safe := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var q := p + Vector2i(dx, dy)
					if not s.world.in_bounds(q) or not s.fog.is_revealed(q):
						safe = false
			if safe:
				result.append(
					{"at": at, "size": Vector2(width, width * 0.75), "index": index, "alpha": 0.68 if shore else 0.80}
				)
	return result


func _aprons(s, tile: Vector2i) -> Array[Vector4]:
	var aprons := super._aprons(s, tile)
	if layered:
		for i in aprons.size():
			if aprons[i].z > 0.9:
				# The 2x2 Hearth is bottom-anchored; contact belongs under its foundation/fire.
				aprons[i] = Vector4(aprons[i].x + 0.5, aprons[i].y + 0.45, 1.06, 0.38)
	return aprons
