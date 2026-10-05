extends RefCounted
## Connected deck modules, with bank caps only at the ends. No span-wide sprite stretching.

const Rendered = preload("res://scripts/rendered_art.gd")
const TILE := 48.0


static func span(s, p: Vector2i) -> Dictionary:
	var horizontal := _axis_span(s, p, Vector2i.RIGHT)
	var vertical := _axis_span(s, p, Vector2i.DOWN)
	if horizontal["length"] != vertical["length"]:
		return horizontal if horizontal["length"] > vertical["length"] else vertical
	var x_banks := int(s.world.roads.has(p + Vector2i.LEFT)) + int(s.world.roads.has(p + Vector2i.RIGHT))
	var y_banks := int(s.world.roads.has(p + Vector2i.UP)) + int(s.world.roads.has(p + Vector2i.DOWN))
	return vertical if y_banks > x_banks else horizontal


static func _axis_span(s, p: Vector2i, axis: Vector2i) -> Dictionary:
	var anchor := p
	while s.world.roads.has(anchor - axis) and s.world.tile_at(anchor - axis) == "river":
		anchor -= axis
	var length := 1
	while s.world.roads.has(anchor + axis * length) and s.world.tile_at(anchor + axis * length) == "river":
		length += 1
	return {
		"anchor": anchor,
		"axis": axis,
		"length": length,
		"part": absi(p.x - anchor.x) if axis.x != 0 else absi(p.y - anchor.y)
	}


static func draw(ci: CanvasItem, s, p: Vector2i) -> void:
	var crossing := span(s, p)
	var vertical: bool = crossing["axis"] == Vector2i.DOWN
	var stone: bool = s.world.stone_bridges.has(p)
	var row := (6 if vertical else 0) + (3 if stone else 0)
	var part: int = crossing["part"]
	var length: int = crossing["length"]
	var module := 0 if part == 0 else (2 if part == length - 1 else 1)
	var at := (Vector2(p) + Vector2(0.5, 0.5)) * TILE
	var width := 30.0 if module == 1 else 38.0
	var size := Vector2(width, TILE + 2.0) if vertical else Vector2(TILE + 2.0, width)
	var box := Rect2(at - size * 0.5, size)
	ci.draw_rect(Rect2(box.position + Vector2(1, 2), box.size + Vector2(2, 2)), Color(0.08, 0.13, 0.1, 0.15))
	if length == 1:
		for half in 2:
			var tex := Rendered.sprite("crossings-v2", row + half * 2)
			var source := tex.region
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
			ci.draw_texture_rect_region(tex.atlas, target, source)
	else:
		ci.draw_texture_rect(Rendered.sprite("crossings-v2", row + module), box, false)
