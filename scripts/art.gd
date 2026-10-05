extends RefCounted
## Rendered map art and icons, with vector fallbacks and interface drawing helpers.
## Static helpers that draw onto whichever CanvasItem is passed in, during its draw.

const Data = preload("res://scripts/data.gd")
const Rendered = preload("res://scripts/rendered_art.gd")

const OUTLINE := Color("1b1b1f")
## The pale-cyan light of the Strange Stone and its cairn.
const STONE_GLOW := Color(0.6, 0.95, 1.0)
const SPRITE_DIR := "res://art/sprites/"
const FOREST: Color = Data.TILES["tree"]["color"]

## Buildings whose sprite has another name.
const SPRITE_OF := {"camp": "hearth", "road": "tile_path", "bridge": "tile_bridge_wood", "flax_field": "flax"}

## Map art is drawn in a 32-unit design space (`DESIGN`) and scaled up to the tile, so a 2-unit outline is 3 px at
## 48 px tiles. Sprites are drawn at their native scale, never redrawn thin.
const DESIGN := 32.0

## One screen pixel in map units (1 / the map's zoom), set by the map each frame: text, pills and badges keep the
## same size on screen whatever the zoom. 1.0 anywhere that draws at screen scale.
static var ui_k := 1.0

static var _sprites := {}
static var _hatch: Texture2D = null


static func building_sprite(type: String) -> Texture2D:
	if Rendered.BUILDINGS.has(type):
		return Rendered.sprite("buildings", Rendered.BUILDINGS[type])
	return sprite(SPRITE_OF.get(type, type))


## A rendered atlas sprite or the imported legacy SVG, preserving existing caller IDs.
## (callers then draw the shapes themselves).
static func sprite(name: String) -> Texture2D:
	var rendered := Rendered.named(name)
	if rendered != null:
		return rendered
	if not _sprites.has(name):
		var path := SPRITE_DIR + name + ".svg"
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
		_sprites[name] = tex
	return _sprites[name]


## A tile of unexplored land's very light diagonal hatch (a lines every 12 px, so it runs on across tiles).
static func fog_hatch(tile_px: int) -> Texture2D:
	if _hatch == null:
		var img := Image.create(tile_px, tile_px, false, Image.FORMAT_RGBA8)
		var period := maxi(int(tile_px / 4.0), 2)
		for y in tile_px:
			for x in tile_px:
				var d := (x + y) % period
				if d < 2:
					img.set_pixel(x, y, Color(1.0, 0.92, 0.8, 0.05))
		_hatch = ImageTexture.create_from_image(img)
	return _hatch


## An item's sprite drawn in `r` at alpha `a`, or the old colored square when it has none.
static func item_icon(ci: CanvasItem, id: String, r: Rect2, a: float) -> void:
	var tex := sprite("item_" + id)
	if tex != null:
		Rendered.fit(ci, tex, r, Color(1, 1, 1, a))
		return
	var box := r.grow(-r.size.x * 0.2)
	ci.draw_rect(box, Color(Data.ITEMS[id]["color"], a))
	ci.draw_rect(box, Color(OUTLINE, a), false, 1.0)


## A rounded pill with centered text, e.g. a hint by the cursor. `at` is the pill's top center and `size` the
## text's size in screen px (it is scaled by `ui_k`, so it reads the same at every zoom).
static func pill(ci: CanvasItem, at: Vector2, text: String, bg: Color, fg: Color, size: int) -> Rect2:
	var font := ThemeDB.fallback_font
	var k := ui_k
	var px := maxi(roundi(size * k), 1)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 14.0 * k
	var h := px + 8.0 * k
	var r := Rect2(at - Vector2(w / 2.0, 0), Vector2(w, h))
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = OUTLINE
	box.set_border_width_all(maxi(roundi(2.0 * k), 1))
	box.set_corner_radius_all(int(h / 2.0))
	ci.draw_style_box(box, r)
	ci.draw_string(font, r.position + Vector2(7.0 * k, px + 2.0 * k), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, fg)
	return r


## Text with a dark outline, readable over the map; `size` is in screen px like `pill`.
static func outlined_text(ci: CanvasItem, pos: Vector2, text: String, size: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var px := maxi(roundi(size * ui_k), 1)
	ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(roundi(4.0 * ui_k), 1), OUTLINE)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


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


## A map tile's feature drawn at tile scale `k` (tile px / DESIGN), centered on c.
static func map_feature(ci: CanvasItem, t: String, c: Vector2, p: Vector2i, time: float, k: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2(k, k))
	if t not in ["grass", "river", ""]:
		contact_shadow(ci, Vector2(0, 9), Vector2(10, 3.4))
	feature(ci, t, Vector2.ZERO, p, time)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A map tile's feature (tree, rock, river ripple...) centered on c, in design units.
static func feature(ci: CanvasItem, t: String, c: Vector2, p: Vector2i, time: float) -> void:
	if Rendered.feature(ci, t, c, p, time):
		return
	var jitter := Vector2(((p.x * 7 + p.y * 3) % 5) - 2, ((p.x * 3 + p.y * 5) % 5) - 2)
	match t:
		"tree":
			# A visible trunk under a canopy that fills about 0.9 tile.
			var sway := jitter * 0.4
			var trunk := Rect2(c + Vector2(-2.5, 3), Vector2(5, 11))
			ci.draw_rect(trunk, Color("6d4c41"))
			ci.draw_rect(trunk, OUTLINE, false, 1.5)
			outlined_circle(ci, c + Vector2(0, -3) + sway, 14.0, FOREST)
			ci.draw_circle(c + Vector2(-5, -8) + sway, 4.0, FOREST.lightened(0.18))
		"rock":
			var pts := PackedVector2Array(
				[
					c + Vector2(-13, 9),
					c + Vector2(-10, -5),
					c + Vector2(0, -12),
					c + Vector2(11, -5),
					c + Vector2(13, 9)
				]
			)
			outlined_poly(ci, pts, Color("9e9e9e"))
			ci.draw_line(c + Vector2(-3, -7), c + Vector2(2, 5), Color("757575"), 2.0)
		"gravel":
			for i in 5:
				ci.draw_circle(c + Vector2((i * 11) % 20 - 10, (i * 7) % 16 - 8), 2.5, Color("4a4e69"))
		"clay":
			# A brown bank in the clay color, with darker lumps.
			var bank := Data.TILES["clay"]["color"] as Color
			var lump := PackedVector2Array()
			for i in 14:
				var a := TAU * i / 14.0
				lump.append(c + Vector2(cos(a) * (12.0 + (i % 3)), sin(a) * (9.0 + (i % 2) * 1.5)))
			outlined_poly(ci, lump, bank.darkened(0.12))
			ci.draw_circle(c + Vector2(-5, 2), 3.5, bank.darkened(0.35))
			ci.draw_circle(c + Vector2(5, -2), 3.0, bank.darkened(0.35))
			ci.draw_circle(c + Vector2(1, 5), 2.2, bank.lightened(0.15))
		"berry":
			# A low, round bush (no trunk), so it is never mistaken for a tree.
			var bush := PackedVector2Array()
			for i in 20:
				var a := TAU * i / 20.0
				bush.append(c + Vector2(cos(a) * 13.0, 4.0 + sin(a) * 9.0))
			outlined_poly(ci, bush, Color("5d8c34"))
			ci.draw_circle(c + Vector2(-5, 1), 3.5, Color("7aa64a"))
			for off in [Vector2(-6, 3), Vector2(2, 7), Vector2(7, 2), Vector2(-1, 0), Vector2(8, 8)]:
				ci.draw_circle(c + off, 2.8, Color("d62246"))
				ci.draw_circle(c + off + Vector2(-0.8, -0.8), 0.9, Color("f4a0ab"))
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
		"flax_field":
			# Sown flax: the wild flax sprite in a pale blue-green with seed furrows under it, until it has its own art.
			var sown := sprite("flax")
			if sown != null:
				ci.draw_texture_rect(sown, Rect2(c - Vector2(16, 16), Vector2(32, 32)), false, Color(0.82, 1.0, 0.96))
			else:
				feature(ci, "flax", c, p, time)
			for i in 3:
				ci.draw_line(c + Vector2(-12 + i * 12, 14), c + Vector2(-8 + i * 12, 14), Color(OUTLINE, 0.55), 1.5)
		"grain":
			# Gold heads on slender stalks, as in the Field sprite.
			for i in 5:
				var x := -10 + i * 5
				var base := c + Vector2(x, 12)
				var tip := c + Vector2(x + (i % 2) * 2 - 1, -6 - (i % 3) * 2)
				ci.draw_line(base, tip, Color("8d6e1f"), 2.0)
				var head := PackedVector2Array()
				for j in 10:
					var a := TAU * j / 10.0
					head.append(tip + Vector2(cos(a) * 2.6, sin(a) * 4.0 - 3.0))
				outlined_poly(ci, head, Color("f2c14e"))
		"river":
			pass  # Flow and reflections belong to the continuous terrain shader.
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


## The Shard Cairn's glow, brighter as the Wanderer comes nearer (`approach`, 0 to 1): nothing until Sky Watch has
## named the light. Only flavor, drawn over the cairn's own sprite.
static func cairn_glow(ci: CanvasItem, r: Rect2, approach: float, time: float) -> void:
	if approach <= 0.0:
		return
	var radius := r.size.x * (0.6 + 0.5 * approach)
	ci.draw_circle(r.get_center(), radius, Color(STONE_GLOW, cairn_glow_alpha(approach, time)))


## How strong the cairn's glow is: 0 until the light is named, brighter as it nears, with a slow pulse.
static func cairn_glow_alpha(approach: float, time: float) -> float:
	if approach <= 0.0:
		return 0.0
	return (0.1 + 0.3 * clampf(approach, 0.0, 1.0)) * (0.8 + 0.2 * sin(time * 2.0))


## A building drawn in `r` (a tile, or the Hearth's 2x2): its SVG sprite at native scale (the sprite brings its own
## plate), or a plain plate in the building's color when it has none. `working` adds the charcoal pit's smoke.
static func map_building(ci: CanvasItem, type: String, r: Rect2, working: bool, time: float) -> void:
	if Rendered.building(ci, type, r):
		if type == "charcoal_pit" and working:
			var k := r.size.x / DESIGN
			for i in 3:
				var phase := fmod(time * 0.6 + i / 3.0, 1.0)
				ci.draw_circle(
					r.get_center() + Vector2(sin(phase * 6.0) * 2, -phase * 12) * k,
					(1.0 + phase * 2) * k,
					Color(0.6, 0.65, 0.65, (1.0 - phase) * 0.3)
				)
		return
	var tex := building_sprite(type)
	if tex != null:
		ci.draw_texture_rect(tex, r, false)
	else:
		var plate := r.grow(-r.size.x * 0.06)
		ci.draw_rect(plate, Data.BUILDINGS[type]["color"])
		ci.draw_rect(plate, OUTLINE, false, r.size.x * 0.08)
	if type == "charcoal_pit" and working:
		var k := r.size.x / DESIGN
		for i in 3:
			var t := fmod(time * 0.6 + i / 3.0, 1.0)
			var at := r.get_center() + Vector2(sin(t * 6.0) * 3.0, -2.0 - t * 12.0) * k
			ci.draw_circle(at, (2.0 + t * 2.0) * k, Color(0.8, 0.8, 0.8, 1.0 - t))


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


## Tight soft grounding in the same draw space as the subject, never an opaque floating halo.
static func contact_shadow(ci: CanvasItem, center: Vector2, radius: Vector2) -> void:
	for layer in 3:
		var points := PackedVector2Array()
		var scale := 1.0 - layer * 0.18
		for i in 24:
			points.append(center + Vector2(cos(TAU * i / 24.0), sin(TAU * i / 24.0)) * radius * scale)
		ci.draw_colored_polygon(points, Color(0.08, 0.12, 0.09, 0.05 + layer * 0.025))
