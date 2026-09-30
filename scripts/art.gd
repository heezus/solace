extends RefCounted
## Flat, bold-outlined vector art: map features, building shapes and tech-tree arrows.
## Static helpers that draw onto whichever CanvasItem is passed in, during its draw.

const OUTLINE := Color("1b1b1f")
## The pale-cyan light of the Strange Stone and its cairn.
const STONE_GLOW := Color(0.6, 0.95, 1.0)


## A map tile's feature (tree, rock, river ripple...) centered on c.
static func feature(ci: CanvasItem, t: String, c: Vector2, p: Vector2i, time: float) -> void:
	var jitter := Vector2(((p.x * 7 + p.y * 3) % 5) - 2, ((p.x * 3 + p.y * 5) % 5) - 2)
	match t:
		"tree":
			ci.draw_rect(Rect2(c + Vector2(-2, 2), Vector2(4, 9)), Color("6d4c41"))
			outlined_circle(ci, c + Vector2(0, -3) + jitter * 0.5, 10.0, Color("2e7d32"))
			ci.draw_circle(c + Vector2(-3, -6) + jitter * 0.5, 3.0, Color("43a047"))
		"rock":
			var pts := PackedVector2Array(
				[c + Vector2(-11, 8), c + Vector2(-8, -5), c + Vector2(0, -10), c + Vector2(9, -4), c + Vector2(11, 8)]
			)
			outlined_poly(ci, pts, Color("9e9e9e"))
			ci.draw_line(c + Vector2(-2, -6), c + Vector2(2, 4), Color("757575"), 2.0)
		"gravel":
			for i in 5:
				ci.draw_circle(c + Vector2((i * 11) % 20 - 10, (i * 7) % 16 - 8), 2.5, Color("4a4e69"))
		"clay":
			ci.draw_circle(c + Vector2(-5, 3), 5.0, Color("a0522d"))
			ci.draw_circle(c + Vector2(6, -3), 4.0, Color("a0522d"))
		"berry":
			outlined_circle(ci, c + Vector2(0, 2), 10.0, Color("558b2f"))
			for off in [Vector2(-4, -1), Vector2(3, 3), Vector2(4, -4), Vector2(-2, 6)]:
				ci.draw_circle(c + off, 2.5, Color("d62246"))
		"grain":
			for i in 4:
				var x := -9 + i * 6
				ci.draw_line(c + Vector2(x, 10), c + Vector2(x + 2, -8), Color("8d6e1f"), 2.0)
				ci.draw_circle(c + Vector2(x + 2, -8), 2.5, Color("f2c14e"))
		"river":
			var w := sin(time * 2.0 + p.y * 0.9) * 3.0
			ci.draw_line(c + Vector2(-10 + w, -4), c + Vector2(-2 + w, -4), Color(1, 1, 1, 0.5), 2.0)
			ci.draw_line(c + Vector2(2 - w, 5), c + Vector2(10 - w, 5), Color(1, 1, 1, 0.5), 2.0)
		"shard":
			var glow := 0.35 + 0.25 * sin(time * 2.5)
			ci.draw_circle(c, 13.0, Color(STONE_GLOW, glow * 0.5))
			var pts := PackedVector2Array(
				[c + Vector2(0, -10), c + Vector2(6, 0), c + Vector2(0, 10), c + Vector2(-6, 0)]
			)
			outlined_poly(ci, pts, Color("bdf4ff"))


## A building's shapes, drawn over its base plate, centered on c.
static func building(ci: CanvasItem, type: String, c: Vector2, working: bool, time: float) -> void:
	match type:
		"camp":
			outlined_poly(
				ci, PackedVector2Array([c + Vector2(-11, 9), c + Vector2(0, -11), c + Vector2(11, 9)]), Color("f4e1c1")
			)
			var flame := 3.0 + sin(time * 10.0) * 1.0
			ci.draw_circle(c + Vector2(0, 5), flame, Color("ffb703"))
		"charcoal_pit":
			outlined_circle(ci, c + Vector2(0, 4), 9.0, Color("3d405b"))
			if working:
				for i in 3:
					var t := fmod(time * 0.6 + i / 3.0, 1.0)
					ci.draw_circle(
						c + Vector2(sin(t * 6.0) * 3.0, -2 - t * 12), 2.0 + t * 2.0, Color(0.8, 0.8, 0.8, 1.0 - t)
					)
		"twine_post":
			ci.draw_rect(Rect2(c + Vector2(-2, -11), Vector2(4, 20)), Color("6d4c41"))
			outlined_circle(ci, c + Vector2(0, 2), 6.0, Color("bc8a5f"))
		"gatherers_hut":
			ci.draw_rect(Rect2(c + Vector2(-8, -1), Vector2(16, 10)), Color("f4a261"))
			ci.draw_rect(Rect2(c + Vector2(-8, -1), Vector2(16, 10)), OUTLINE, false, 2.0)
			outlined_poly(
				ci, PackedVector2Array([c + Vector2(-11, 0), c + Vector2(0, -11), c + Vector2(11, 0)]), Color("e9c46a")
			)
		"kiln":
			outlined_circle(ci, c + Vector2(0, 2), 10.0, Color("9c3d2e"))
			ci.draw_circle(c + Vector2(0, 5), 4.0, Color("ffb703") if working else OUTLINE)
		"dwelling":
			ci.draw_rect(Rect2(c + Vector2(-9, -1), Vector2(18, 10)), Color("d4a373"))
			ci.draw_rect(Rect2(c + Vector2(-9, -1), Vector2(18, 10)), OUTLINE, false, 2.0)
			outlined_poly(
				ci, PackedVector2Array([c + Vector2(-12, 0), c + Vector2(0, -10), c + Vector2(12, 0)]), Color("a8dadc")
			)
			ci.draw_rect(Rect2(c + Vector2(-2, 3), Vector2(4, 6)), OUTLINE)
		"storehouse":
			var box := Rect2(c + Vector2(-10, -8), Vector2(20, 17))
			ci.draw_rect(box, Color("8d6e63"))
			ci.draw_rect(box, OUTLINE, false, 2.0)
			ci.draw_line(box.position, box.end, OUTLINE, 1.5)
			ci.draw_line(box.position + Vector2(box.size.x, 0), box.position + Vector2(0, box.size.y), OUTLINE, 1.5)
		"water_wheel", "grindstone":
			var col := Color("2a9d8f") if type == "water_wheel" else Color("adb5bd")
			var spinning: bool = type == "water_wheel" or working
			var ang := time * 2.0 if spinning else 0.0
			outlined_circle(ci, c, 11.0, col)
			for i in 4:
				var a := ang + i * PI / 4.0
				ci.draw_line(c - Vector2.from_angle(a) * 10.0, c + Vector2.from_angle(a) * 10.0, OUTLINE, 2.0)
			ci.draw_circle(c, 3.0, OUTLINE)
		"fishing_weir":
			var pool := Rect2(c + Vector2(-11, -3), Vector2(22, 12))
			ci.draw_rect(pool, Color("3a86c8"))
			ci.draw_rect(pool, OUTLINE, false, 2.0)
			for i in 4:
				ci.draw_line(c + Vector2(-9 + i * 6, -10), c + Vector2(-9 + i * 6, 9), Color("6d4c41"), 2.0)
			if working:
				var bob := sin(time * 4.0) * 2.0
				outlined_poly(
					ci,
					PackedVector2Array([c + Vector2(-5, 3 + bob), c + Vector2(3, -1 + bob), c + Vector2(3, 7 + bob)]),
					Color("5fa8d3")
				)
		"standing_stone":
			outlined_poly(
				ci,
				PackedVector2Array(
					[
						c + Vector2(-6, 11),
						c + Vector2(-7, -8),
						c + Vector2(-2, -12),
						c + Vector2(5, -9),
						c + Vector2(6, 11)
					]
				),
				Color("8d8d9a")
			)
			ci.draw_line(c + Vector2(-2, -6), c + Vector2(1, 4), Color("6c5b7b"), 2.0)
		"shard_cairn":
			ci.draw_circle(c, 13.0, Color(STONE_GLOW, 0.2 + 0.1 * sin(time * 2.0)))
			ci.draw_arc(c, 8.0, 0, TAU, 24, OUTLINE, 8.5, true)
			ci.draw_arc(c, 8.0, 0, TAU, 24, Color("9e9e9e"), 4.5, true)
			for i in 6:
				var a := i * TAU / 6.0
				ci.draw_line(c + Vector2.from_angle(a) * 6.0, c + Vector2.from_angle(a) * 10.0, OUTLINE, 1.5)


static func outlined_circle(ci: CanvasItem, c: Vector2, radius: float, color: Color) -> void:
	ci.draw_circle(c, radius, color)
	ci.draw_arc(c, radius, 0, TAU, 24, OUTLINE, 2.0, true)


static func outlined_poly(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	ci.draw_colored_polygon(pts, color)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, OUTLINE, 2.0, true)


# --- Tech tree arrows ----------------------------------------------------------


## An S-curve from a to b that leaves and arrives horizontally.
static func curve(a: Vector2, b: Vector2) -> PackedVector2Array:
	var dx := (b.x - a.x) * 0.5
	var pts := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		pts.append(a.bezier_interpolate(a + Vector2(dx, 0), b - Vector2(dx, 0), b, t))
	return pts


static func draw_curve(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float, dashed: bool) -> void:
	var parts: Array = dashes(pts, 7.0) if dashed else [pts]
	for part in parts:
		ci.draw_polyline(part, OUTLINE, w + 3.0, true)
	for part in parts:
		ci.draw_polyline(part, col, w, true)


## Cuts a polyline into dashes `dash` long, with gaps just as long.
static func dashes(pts: PackedVector2Array, dash: float) -> Array:
	var out: Array = []
	var cur := PackedVector2Array([pts[0]])
	var on := true
	var left := dash
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		var pos := 0.0
		while seg - pos > left:
			pos += left
			var cut := a.lerp(b, pos / seg)
			if on:
				cur.append(cut)
				out.append(cur)
			else:
				cur = PackedVector2Array([cut])
			on = not on
			left = dash
		left -= seg - pos
		if on:
			cur.append(b)
	if on and cur.size() > 1:
		out.append(cur)
	return out


static func draw_head(ci: CanvasItem, b: Vector2, col: Color) -> void:
	var head := PackedVector2Array([b, b + Vector2(-12, -7), b + Vector2(-12, 7)])
	ci.draw_colored_polygon(head, col)
	ci.draw_polyline(PackedVector2Array([b, b + Vector2(-12, -7), b + Vector2(-12, 7), b]), OUTLINE, 1.5)
