extends "res://docs/art/overhaul/misty-highlands/grounding-studies/sculpted-native-study/study-ground.gd"
## Individual upright props follow the wet-mask contour. Lighting never rotates with the bank.
const Props = preload(
	"res://docs/art/overhaul/misty-highlands/grounding-studies/shoreline-crossings-study/study-props.gd"
)
const Bridge = preload("res://scripts/bridge_art.gd")


func _draw_shore() -> void:
	for part in _shore_parts(_shore_state, Rect2i((_rect.position / TILE).floor(), (_rect.size / TILE).ceil())):
		StudyArt.fit(_shore, Props.sprite(part.index), Rect2(part.at - part.size * 0.5, part.size))


func _shore_parts(s, seen: Rect2i) -> Array:
	var result: Array = []
	var occupied := {}
	for y in range(seen.position.y, seen.end.y):
		for x in range(seen.position.x, seen.end.x):
			var p := Vector2i(x, y)
			if not s.fog.is_revealed(p) or s.world.tile_at(p) != "river":
				continue
			for n in NEIGHBORS:
				var q: Vector2i = p + n
				if not s.world.in_bounds(q) or not s.fog.is_revealed(q) or s.world.tile_at(q) == "river":
					continue
				var tangent := Vector2(-n.y, n.x)
				var family: int = 301 + n.x * 19 + n.y * 7
				for i in 3:
					# Sample the actual blended contour, including concave/convex corners.
					var spread := (i - 1) * 0.30 + (StudyArt.variant(p, 7, family + i, s.world.map_seed) - 3) * 0.025
					var at := Vector2(p) + Vector2.ONE * 0.5 + tangent * spread
					var low := 0.25
					var high := 1.25
					for iteration in 9:
						var mid := (low + high) * 0.5
						if _river(s, at + Vector2(n) * mid) > 0.40:
							low = mid
						else:
							high = mid
					at += Vector2(n) * (high + 0.06)
					if _clearance(s, at * TILE):
						continue
					var key := Vector2i((at * TILE / 12.0).floor())
					if occupied.has(key):
						continue
					occupied[key] = true
					var index := StudyArt.variant(p, 9, family + 23 + i * 31, s.world.map_seed)
					var width := 10.0 + StudyArt.variant(p, 7, family + i * 43, s.world.map_seed)
					result.append({"at": at * TILE, "size": Vector2(width, width), "index": index, "normal": n})
	return result


func _clearance(s, at: Vector2) -> bool:
	var cell := Vector2i((at / TILE).floor())
	for y in range(-1, 2):
		for x in range(-1, 2):
			var p := cell + Vector2i(x, y)
			if not s.fog.is_revealed(p) or not s.world.roads.has(p) or s.world.tile_at(p) != "river":
				continue
			var crossing := Bridge.span(s, p)
			var center := (Vector2(p) + Vector2.ONE * 0.5) * TILE
			var offset := at - center
			if crossing.axis == Vector2i.RIGHT:
				if absf(offset.x) < TILE * 1.5 and absf(offset.y) < 28.0:
					return true
			elif absf(offset.y) < TILE * 1.5 and absf(offset.x) < 28.0:
				return true
	return false


func _approach_center(s, p: Vector2i) -> Vector2:
	for n in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var q: Vector2i = p + n
		if s.fog.is_revealed(q) and s.world.roads.has(q) and s.world.tile_at(q) == "river":
			return Vector2(p) + Vector2.ONE * 0.5
	return _road_center(p, s.world.map_seed)


func _road(s, p: Vector2) -> float:
	var tile := Vector2i(p.floor())
	var distance := INF
	for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var q: Vector2i = tile + offset
		if not s.fog.is_revealed(q) or not s.world.roads.has(q):
			continue
		var center := _approach_center(s, q)
		distance = minf(distance, p.distance_to(center))
		for n in NEIGHBORS:
			if s.fog.is_revealed(q + n) and (s.world.roads.has(q + n) or s.town.building_at.has(q + n)):
				var end := _approach_center(s, q + n)
				distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, center, end)))
	var edge := _noise.get_noise_2dv(p * 7.0) * 0.035
	return 1.0 - smoothstep(0.09, 0.29 + edge, distance)
