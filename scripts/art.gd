extends RefCounted
## Flat, bold-outlined vector art: map features, building shapes and tech-tree arrows.
## Static helpers that draw onto whichever CanvasItem is passed in, during its draw.

const Data = preload("res://scripts/data.gd")

const OUTLINE := Color("1b1b1f")
## The pale-cyan light of the Strange Stone and its cairn.
const STONE_GLOW := Color(0.6, 0.95, 1.0)
const SPRITE_DIR := "res://art/sprites/"

## Buildings whose sprite has another name.
const SPRITE_OF := {"camp": "hearth", "road": "tile_path", "bridge": "tile_bridge_wood"}

static var _sprites := {}


static func building_sprite(type: String) -> Texture2D:
	return sprite(SPRITE_OF.get(type, type))


## The imported SVG sprite `name` from art/sprites, or null if it isn't there
## (callers then draw the shapes themselves).
static func sprite(name: String) -> Texture2D:
	if not _sprites.has(name):
		var path := SPRITE_DIR + name + ".svg"
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
		_sprites[name] = tex
	return _sprites[name]


## An item's sprite drawn in `r` at alpha `a`, or the old colored square when it has none.
static func item_icon(ci: CanvasItem, id: String, r: Rect2, a: float) -> void:
	var tex := sprite("item_" + id)
	if tex != null:
		ci.draw_texture_rect(tex, r, false, Color(1, 1, 1, a))
		return
	var box := r.grow(-r.size.x * 0.2)
	ci.draw_rect(box, Color(Data.ITEMS[id]["color"], a))
	ci.draw_rect(box, Color(OUTLINE, a), false, 1.0)


## A rounded pill with centered text, e.g. a status under a building. `at` is the pill's top center.
static func pill(ci: CanvasItem, at: Vector2, text: String, bg: Color, fg: Color, size: int) -> Rect2:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 12.0
	var h := size + 8.0
	var r := Rect2(at - Vector2(w / 2.0, 0), Vector2(w, h))
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = OUTLINE
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(h / 2.0))
	ci.draw_style_box(box, r)
	ci.draw_string(font, r.position + Vector2(6, size + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fg)
	return r


## Text with a dark outline, readable over the map.
static func outlined_text(ci: CanvasItem, pos: Vector2, text: String, size: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, OUTLINE)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## A dashed circle, `on` long dashes with `off` gaps.
static func dashed_circle(
	ci: CanvasItem, c: Vector2, radius: float, col: Color, width: float, on: float, off: float
) -> void:
	var steps := maxi(int(TAU * radius / 4.0), 24)
	var pts := PackedVector2Array()
	for i in steps + 1:
		pts.append(c + Vector2.from_angle(TAU * i / steps) * radius)
	for part in dash_pattern(pts, on, off, 0.0):
		ci.draw_polyline(part, col, width, true)


## A dashed rectangle outline.
static func dashed_rect(ci: CanvasItem, r: Rect2, col: Color, width: float, on: float, off: float) -> void:
	var pts := PackedVector2Array(
		[r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	)
	for part in dash_pattern(pts, on, off, 0.0):
		ci.draw_polyline(part, col, width)


## A small tech icon in `r`: its sprite, or a few shapes for the "@" icons and missing sprites.
static func tech_icon(ci: CanvasItem, icon: String, r: Rect2, time: float) -> void:
	var c := r.get_center()
	var k := r.size.x / 32.0
	if not icon.begins_with("@"):
		var tex := sprite(icon)
		if tex != null:
			ci.draw_texture_rect(tex, r, false)
			return
	ci.draw_set_transform(c, 0.0, Vector2(k, k))
	match icon:
		"@flint":
			outlined_poly(
				ci,
				PackedVector2Array([Vector2(-9, 8), Vector2(-4, -10), Vector2(6, -6), Vector2(10, 7), Vector2(0, 11)]),
				Color("4a4e69")
			)
			ci.draw_line(Vector2(-2, -6), Vector2(3, 6), Color("9aa0c0"), 1.5)
		"@clay", "@rock":
			ci.draw_rect(Rect2(-14, -14, 28, 28), Color("7cb342"))
			feature(ci, icon.substr(1), Vector2.ZERO, Vector2i.ZERO, time)
		"@irrigation", "@calendar":
			ci.draw_rect(Rect2(-14, -14, 28, 28), Color("3a86c8") if icon == "@irrigation" else Color("14213d"))
			if icon == "@calendar":
				for p in [Vector2(-9, -9), Vector2(8, -10), Vector2(10, 6)]:
					ci.draw_circle(p, 1.2, Color.WHITE)
				outlined_circle(ci, Vector2(-6, 6), 5.0, Color("f1e3c8"))
			else:
				ci.draw_rect(Rect2(-8, -8, 16, 16), Color("8a6a44"))
				for x in [-5, 0, 5]:
					ci.draw_line(Vector2(x, 5), Vector2(x, -5), Color("f2c14e"), 2.0)
		"@axe":
			# A wooden haft with a flint head lashed on with cord.
			ci.draw_line(Vector2(-9, 12), Vector2(6, -9), OUTLINE, 6.0)
			ci.draw_line(Vector2(-9, 12), Vector2(6, -9), Color("a47148"), 3.0)
			outlined_poly(
				ci,
				PackedVector2Array([Vector2(1, -13), Vector2(12, -11), Vector2(13, 0), Vector2(5, -3)]),
				Color("4a4e69")
			)
			ci.draw_line(Vector2(1, -8), Vector2(6, -4), Color("e9c46a"), 2.0)
		"@bread":
			var loaf := PackedVector2Array()
			for i in 16:
				var a := PI + PI * i / 15.0
				loaf.append(Vector2(cos(a) * 11.0, sin(a) * 8.0 + 4.0))
			outlined_poly(ci, loaf, Color("d4a373"))
			for x in [-5, 0, 5]:
				ci.draw_line(Vector2(x - 2, -1), Vector2(x + 2, -3), Color("8d5a3b"), 1.5)
		"@tally":
			# A split stick with a row of notches cut across it.
			ci.draw_line(Vector2(-12, 10), Vector2(12, -10), OUTLINE, 8.0)
			ci.draw_line(Vector2(-12, 10), Vector2(12, -10), Color("c9a26b"), 5.0)
			for i in 4:
				var at := Vector2(-6 + i * 5, 5 - i * 4)
				ci.draw_line(at + Vector2(-2, -3), at + Vector2(2, 3), OUTLINE, 1.5)
		_:
			outlined_circle(ci, Vector2.ZERO, 10.0, Color("9aa0a6"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
		"flax":
			var tex := sprite("flax")
			if tex != null:
				ci.draw_texture_rect(tex, Rect2(c - Vector2(16, 16), Vector2(32, 32)), false)
				return
			# Drawn stand-in if the sprite is missing: slender stems with small blue flowers.
			for i in 4:
				var x := -9 + i * 6
				var top := c + Vector2(x + (i % 2) * 2 - 1, -7 + (i % 2) * 4)
				ci.draw_line(c + Vector2(x, 11), top, OUTLINE, 3.4)
				ci.draw_line(c + Vector2(x, 11), top, Color("6f9a3c"), 1.6)
				outlined_circle(ci, top, 2.5, Color("6d8fe0"))
				ci.draw_circle(top, 1.0, Color("f2c14e"))
		"grain":
			for i in 4:
				var x := -9 + i * 6
				ci.draw_line(c + Vector2(x, 10), c + Vector2(x + 2, -8), Color("8d6e1f"), 2.0)
				ci.draw_circle(c + Vector2(x + 2, -8), 2.5, Color("f2c14e"))
		"river":
			var w := sin(time * 2.0 + p.y * 0.9) * 3.0
			ci.draw_line(c + Vector2(-10 + w, -4), c + Vector2(-2 + w, -4), Color(1, 1, 1, 0.5), 2.0)
			ci.draw_line(c + Vector2(2 - w, 5), c + Vector2(10 - w, 5), Color(1, 1, 1, 0.5), 2.0)
		"copper_hills", "tin_stream":
			var tex := sprite("tile_" + t)
			if tex != null:
				ci.draw_texture_rect(tex, Rect2(c - tex.get_size() / 2.0, tex.get_size()), false)
				return
			# Drawn stand-in if the sprite is missing: low mounds, flecked with green (copper) or silver (tin).
			var fleck := Color("3fa37a") if t == "copper_hills" else Color("d9dde3")
			for off in [Vector2(-5, 5), Vector2(6, 2)]:
				var mound := PackedVector2Array(
					[c + off + Vector2(-8, 5), c + off + Vector2(0, -7), c + off + Vector2(8, 5)]
				)
				outlined_poly(ci, mound, Color("8c8f79") if t == "copper_hills" else Color("a9a69a"))
			for off in [Vector2(-5, 3), Vector2(7, 0), Vector2(0, 8)]:
				ci.draw_circle(c + off, 1.8, fleck)
		"plain_ore":
			# Ore not yet named (before Prospecting): just low grey mounds.
			for off in [Vector2(-5, 5), Vector2(6, 2)]:
				var mound := PackedVector2Array(
					[c + off + Vector2(-8, 5), c + off + Vector2(0, -7), c + off + Vector2(8, 5)]
				)
				outlined_poly(ci, mound, Color("8c8f79"))
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
		"mine":
			# A timber-framed shaft mouth in the hillside.
			outlined_poly(
				ci,
				PackedVector2Array([c + Vector2(-11, 9), c + Vector2(-8, -6), c + Vector2(8, -6), c + Vector2(11, 9)]),
				Color("8c8f79")
			)
			ci.draw_rect(Rect2(c + Vector2(-5, -2), Vector2(10, 11)), OUTLINE)
			ci.draw_rect(Rect2(c + Vector2(-6, -3), Vector2(12, 3)), Color("6d4c41"))
			ci.draw_line(c + Vector2(-5, -2), c + Vector2(-5, 9), Color("6d4c41"), 2.0)
			ci.draw_line(c + Vector2(5, -2), c + Vector2(5, 9), Color("6d4c41"), 2.0)
			if working:
				ci.draw_circle(c + Vector2(sin(time * 8.0) * 3.0, 4), 1.6, Color("e9c46a"))
		"smelter":
			outlined_poly(
				ci,
				PackedVector2Array([c + Vector2(-8, 10), c + Vector2(-5, -9), c + Vector2(5, -9), c + Vector2(8, 10)]),
				Color("b86b3d")
			)
			ci.draw_circle(c + Vector2(0, 5), 3.5, Color("ffb703") if working else OUTLINE)
			if working:
				var t := fmod(time * 0.7, 1.0)
				ci.draw_circle(c + Vector2(0, -11 - t * 6), 2.0 + t * 2.0, Color(0.8, 0.8, 0.8, 1.0 - t))
		"crucible":
			var pot := PackedVector2Array(
				[c + Vector2(-9, -4), c + Vector2(9, -4), c + Vector2(6, 9), c + Vector2(-6, 9)]
			)
			outlined_poly(ci, pot, Color("8d5a3b"))
			ci.draw_rect(Rect2(c + Vector2(-7, -6), Vector2(14, 3)), Color("ffb703") if working else Color("c78f4a"))
			ci.draw_rect(Rect2(c + Vector2(-7, -6), Vector2(14, 3)), OUTLINE, false, 1.5)
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


## An orthogonal polyline with its corners rounded off (radius r, or less where segments are short).
static func rounded(pts: PackedVector2Array, r: float) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var a := pts[i - 1]
		var b := pts[i]
		var c := pts[i + 1]
		var rr := minf(r, minf(a.distance_to(b), b.distance_to(c)) / 2.0)
		if rr < 0.5:
			out.append(b)
			continue
		var p0 := b + (a - b).normalized() * rr
		var p1 := b + (c - b).normalized() * rr
		for j in 7:
			var t := j / 6.0
			out.append(p0.lerp(b, t).lerp(b.lerp(p1, t), t))
	out.append(pts[pts.size() - 1])
	return out


## Cuts a polyline into `on`-long dashes with `off` gaps, starting `offset` into the pattern.
static func dash_pattern(pts: PackedVector2Array, on: float, off: float, offset: float) -> Array:
	var out: Array = []
	var period := on + off
	var pos := fposmod(offset, period)
	var cur := PackedVector2Array()
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		var d := 0.0
		while d < seg:
			var phase := fposmod(pos + d, period)
			var drawing := phase < on
			var left := (on - phase) if drawing else (period - phase)
			var step := minf(left, seg - d)
			if drawing:
				if cur.is_empty():
					cur.append(a.lerp(b, d / seg))
				cur.append(a.lerp(b, (d + step) / seg))
			elif cur.size() > 1:
				out.append(cur)
				cur = PackedVector2Array()
			else:
				cur = PackedVector2Array()
			d += step
		pos += seg
	if cur.size() > 1:
		out.append(cur)
	return out


## A small unoutlined arrowhead pointing right, its tip at b.
static func small_head(ci: CanvasItem, b: Vector2, col: Color, size: float) -> void:
	ci.draw_colored_polygon(
		PackedVector2Array([b, b + Vector2(-size, -size * 0.6), b + Vector2(-size, size * 0.6)]), col
	)


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
