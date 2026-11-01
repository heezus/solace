extends RefCounted
## What Skyreach (scripts/skyreach.gd) draws on the map, as placeholders until the art comes (Step 8D): the edges of every surveyed
## sector of the sky, a ring and a countdown on each landfall a Signal Tower shows, and a gold ring on the site of the Skyreach. All
## static, over a CanvasItem; nothing here changes the game.

const Data = preload("res://scripts/data.gd")
const Art = preload("res://scripts/art.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Skyreach = preload("res://scripts/skyreach.gd")
const Ui = preload("res://scripts/ui.gd")

const EDGE := Color(0.5, 0.82, 1.0, 0.22)
const FALL := Color(1.0, 0.45, 0.3)
const SITE := Color(0.96, 0.9, 0.65)
const HELD := Color(0.96, 0.9, 0.65, 0.4)  # the ring round the tower and the way to it, which the Bloom never takes
const EDGE_TILES := 48.0  # how far the edges of a surveyed sector run out from the Hearth, in tiles


## Draw the sky's marks: only while the era is on.
static func draw(ci: CanvasItem, s, time: float) -> void:
	if not s.skyreach.is_on(s):
		return
	var k := Art.ui_k
	var font := ThemeDB.fallback_font
	var camp: Vector2i = s.world.camp_pos
	var from := Overlays.center(camp)
	var n: int = Data.SKYREACH["sectors"]
	for sector in s.skyreach.surveyed:
		for edge in [-0.5, 0.5]:  # each sector is centred on the direction it is named for
			var angle := deg_to_rad((sector + edge) * 360.0 / n)
			ci.draw_line(from, from + Vector2(cos(angle), sin(angle)) * EDGE_TILES * Overlays.TILE, EDGE, 2.0 * k, true)
	for m in s.skyreach.marked(s):
		var at := Overlays.center(m["pos"])
		var pulse := 0.5 + 0.5 * sin(time * 4.0)
		var radius := float(Data.SKYREACH["patch_radius"] + 1) * Overlays.TILE
		ci.draw_arc(at, radius, 0, TAU, 40, Color(FALL, 0.5 + 0.3 * pulse), 3.0 * k, true)
		ci.draw_circle(at, 6.0 * k, FALL)
		var px := roundi(14.0 * k)
		var text := "%ds" % ceili(m["eta"])
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		ci.draw_string(
			font, at + Vector2(-wide / 2.0, -radius - 4.0 * k), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Ui.TEXT
		)
	var site: Vector2i = s.skyreach.site_pos()
	if site.x >= 0 and not s.town.building_at.has(site):
		ci.draw_arc(Overlays.center(site), 0.8 * Overlays.TILE, 0, TAU, 32, SITE, 3.0 * k, true)
	if site.x >= 0:
		ci.draw_rect(
			Rect2(Overlays.center(site) - Vector2.ONE * 1.5 * Overlays.TILE, Vector2.ONE * 3.0 * Overlays.TILE),
			HELD,
			false,
			2.0 * k
		)
		var line := PackedVector2Array([Overlays.center(site)])
		for p in s.skyreach.way:
			line.append(Overlays.center(p))
		if line.size() > 1:
			ci.draw_polyline(line, HELD, 3.0 * k, true)
