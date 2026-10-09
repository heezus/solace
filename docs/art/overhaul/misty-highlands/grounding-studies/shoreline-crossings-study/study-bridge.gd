extends RefCounted
## Review-only geometry: extend terminal modules onto dry banks without rotating painted light.
const Bridge = preload("res://scripts/bridge_art.gd")
const Art = preload("res://scripts/rendered_art.gd")
const TILE := 48.0
const SEAT := 14.0
static var _sources := {}
static var _image: Image


static func modules(s, p: Vector2i) -> Array:
	var span := Bridge.span(s, p)
	var vertical: bool = span.axis == Vector2i.DOWN
	var row := (6 if vertical else 0) + (3 if s.world.stone_bridges.has(p) else 0)
	var result: Array = []
	var length: int = span.length
	var part: int = span.part
	var at := Vector2(p) * TILE
	var start := -SEAT if part == 0 else 0.0
	var end := TILE + (SEAT if part == length - 1 else 0.0)
	# Do not extend the cap into unrevealed or wet cells at incomplete crossings.
	var before: Vector2i = span.anchor - span.axis
	var after: Vector2i = span.anchor + span.axis * length
	if not s.fog.is_revealed(before) or s.world.tile_at(before) == "river":
		start = 0.0
	if not s.fog.is_revealed(after) or s.world.tile_at(after) == "river":
		end = TILE
	var size := Vector2(36, end - start) if vertical else Vector2(end - start, 36)
	var position := at + (Vector2(6, start) if vertical else Vector2(start, 6))
	var box := Rect2(position, size)
	if length == 1:
		for half in 2:
			var tex := Art.sprite("crossings-v2", row + half * 2)
			var source := _source(tex, row + half * 2)
			var target := box
			if vertical:
				source.position.y += source.size.y * half * 0.5
				source.size.y *= 0.5
				target.position.y += target.size.y * half * 0.5
				target.size.y *= 0.5
			else:
				source.position.x += source.size.x * half * 0.5
				source.size.x *= 0.5
				target.position.x += target.size.x * half * 0.5
				target.size.x *= 0.5
			result.append({"texture": tex, "source": source, "box": target})
	else:
		var module := 0 if part == 0 else (2 if part == length - 1 else 1)
		var tex := Art.sprite("crossings-v2", row + module)
		result.append({"texture": tex, "source": _source(tex, row + module), "box": box})
	return result


static func draw(ci: CanvasItem, s, p: Vector2i) -> void:
	for module in modules(s, p):
		# Soft narrow under-deck contact, rather than a dark rectangular slab.
		var box: Rect2 = module.box
		ci.draw_style_box(_shadow(), Rect2(box.position + Vector2(1, 3), box.size))
		ci.draw_texture_rect_region(module.texture.atlas, box, module.source)


static func _shadow() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.10, 0.085, 0.18)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.035, 0.10, 0.085, 0.10)
	style.shadow_size = 3
	return style


## Atlas padding/shadow must not become a transparent gap between deck modules.
static func _source(tex: AtlasTexture, index: int) -> Rect2:
	var key := tex.region
	if not _sources.has(key):
		if _image == null:
			_image = tex.atlas.get_image()
			if _image.is_compressed():
				_image.decompress()
		var region := Rect2i(tex.region)
		var low := region.end
		var high := region.position
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				if _image.get_pixel(x, y).a > 0.35:
					low = low.min(Vector2i(x, y))
					high = high.max(Vector2i(x + 1, y + 1))
		# Rail posts extend past the deck. Align inner joins to opaque deck coverage,
		# preserving the complete stone footing at each external terminal.
		var vertical := index >= 6
		var near := high.y if vertical else high.x
		var far := low.y if vertical else low.x
		var axis_low := low.y if vertical else low.x
		var axis_high := high.y if vertical else high.x
		var cross_low := low.x if vertical else low.y
		var cross_high := high.x if vertical else high.y
		for a in range(axis_low, axis_high):
			var opaque := 0
			for sample in 5:
				var b := int(lerpf(cross_low, cross_high, 0.35 + sample * 0.075))
				var at := Vector2i(b, a) if vertical else Vector2i(a, b)
				opaque += int(_image.get_pixelv(at).a > 0.65)
			if opaque >= 4:
				near = mini(near, a)
				far = maxi(far, a + 1)
		if near < far:
			if index % 3 != 0:
				if vertical:
					low.y = near
				else:
					low.x = near
			if index % 3 != 2:
				if vertical:
					high.y = far
				else:
					high.x = far
		_sources[key] = Rect2(low, high - low)
	return _sources[key]
