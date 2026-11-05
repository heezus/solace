extends RefCounted
## What Skyreach (scripts/skyreach.gd) draws on the map (Step 8D), with Codex's marks (docs/art/skyreach/map-marks, scripts/sky_art.gd):
## the edges of every surveyed sector of the sky, a ring and a countdown on each landfall a Signal Tower shows and the seed that falls
## on it, a gold ring on the site of the Skyreach, and a gold glow along the way to it. Each keeps its drawn stand-in for when a
## picture is missing. All static, over a CanvasItem; nothing here changes the game.

const Data = preload("res://scripts/data.gd")
const Art = preload("res://scripts/art.gd")
const Overlays = preload("res://scripts/overlays.gd")
const Skyreach = preload("res://scripts/skyreach.gd")
const SkyArt = preload("res://scripts/sky_art.gd")
const Ui = preload("res://scripts/ui.gd")

const EDGE := Color(0.5, 0.82, 1.0, 0.22)
const FALL := Color(1.0, 0.45, 0.3)
const SITE := Color(0.96, 0.9, 0.65)
const HELD := Color(0.96, 0.9, 0.65, 0.4)  # the ring round the tower and the way to it, which the Bloom never takes
const EDGE_TILES := 48.0  # how far the edges of a surveyed sector run out from the Hearth, in tiles
const FALL_SECONDS := [-1.6, -0.5, 0.0, 1.4]  # a seed's fall by the clock: descends, nears the ground, lands, and the splash fades
## The quarter turns (clockwise on the screen) that bring the corner picture, which joins left and down, to join two sides: by the sum of
## the two sides' steps.
const CORNER_TURNS := {Vector2i(-1, 1): 0, Vector2i(-1, -1): 1, Vector2i(1, -1): 2, Vector2i(1, 1): 3}


## Draw the sky's marks: only while the era is on.
static func draw(ci: CanvasItem, s, time: float) -> void:
	if not s.skyreach.is_on(s):
		return
	var k := Art.ui_k
	var camp: Vector2i = s.world.camp_pos
	var from := Overlays.center(camp)
	var n: int = Data.SKYREACH["sectors"]
	for sector in s.skyreach.surveyed:
		for edge in [-0.5, 0.5]:  # each sector is centred on the direction it is named for
			var angle := deg_to_rad((sector + edge) * 360.0 / n)
			_edge(ci, from, angle, k)
	for m in s.skyreach.marked(s):
		_landfall(ci, m, time, k)
	_seeds(ci, s)
	var site: Vector2i = s.skyreach.site_pos()
	if site.x >= 0 and not s.town.building_at.has(site):
		var ring := SkyArt.whole("skyreach_site_ring")
		if ring != null:
			ci.draw_texture_rect(ring, _cell(site), false)
		else:
			ci.draw_arc(Overlays.center(site), 0.8 * Overlays.TILE, 0, TAU, 32, SITE, 3.0 * k, true)
	if site.x >= 0:
		ci.draw_rect(
			Rect2(Overlays.center(site) - Vector2.ONE * 1.5 * Overlays.TILE, Vector2.ONE * 3.0 * Overlays.TILE),
			HELD,
			false,
			2.0 * k
		)
		_way(ci, s, site, k)


static func _cell(p: Vector2i) -> Rect2:
	return Rect2(Overlays.center(p) - Vector2.ONE * Overlays.TILE * 0.5, Vector2.ONE * Overlays.TILE)


## One edge of a surveyed sector: the faint line picture repeated out from the Hearth along the bearing.
static func _edge(ci: CanvasItem, from: Vector2, angle: float, k: float) -> void:
	var tex := SkyArt.whole("sky_sector_edge")
	if tex == null:
		ci.draw_line(from, from + Vector2(cos(angle), sin(angle)) * EDGE_TILES * Overlays.TILE, EDGE, 2.0 * k, true)
		return
	ci.draw_set_transform(from, angle)
	for i in int(EDGE_TILES):
		ci.draw_texture_rect(tex, Rect2(i * Overlays.TILE, -Overlays.TILE * 0.5, Overlays.TILE, Overlays.TILE), false)
	ci.draw_set_transform(Vector2.ZERO)


## A landfall a Signal Tower shows: the ring of the landfall over its tile (the countdown in its clear middle), and the pulsing reach of
## the patch the Bloom will take.
static func _landfall(ci: CanvasItem, m: Dictionary, time: float, k: float) -> void:
	var at := Overlays.center(m["pos"])
	var pulse := 0.5 + 0.5 * sin(time * 4.0)
	var radius := float(Data.SKYREACH["patch_radius"] + 1) * Overlays.TILE
	var mark := SkyArt.whole("landfall_mark")
	var px := roundi(14.0 * k)
	var text := "%ds" % ceili(m["eta"])
	var wide := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if mark != null:
		ci.draw_arc(at, radius, 0, TAU, 40, Color(FALL, 0.2 + 0.2 * pulse), 2.0 * k, true)
		ci.draw_texture_rect(mark, _cell(m["pos"]).grow(2.0 * pulse), false)
		at.y += px * 0.36  # the text's baseline, so its middle sits in the clear disc
		ci.draw_string(
			ThemeDB.fallback_font, at + Vector2(-wide / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Ui.TEXT
		)
		return
	ci.draw_arc(at, radius, 0, TAU, 40, Color(FALL, 0.5 + 0.3 * pulse), 3.0 * k, true)
	ci.draw_circle(at, 6.0 * k, FALL)
	ci.draw_string(
		ThemeDB.fallback_font,
		at + Vector2(-wide / 2.0, -radius - 4.0 * k),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		px,
		Ui.TEXT
	)


## The last moments of every seed that falls on ground the Kith have seen: it comes down from the upper left, nears the ground, and
## lands in one of three splashes (the frame of the atlas or one of the two alternatives), which fades.
static func _seeds(ci: CanvasItem, s) -> void:
	var atlas := SkyArt.whole("seed_fall")
	if atlas == null:
		return
	var now: float = s.skyreach.now(s)
	for f in s.skyreach.falls:
		var d: float = now - f["at"]
		if d < FALL_SECONDS[0] or d > FALL_SECONDS[3] or not s.fog.is_revealed(f["pos"]):
			continue
		var cell := _cell(f["pos"])
		var tex: Texture2D = null
		var tint := Color.WHITE
		if d < FALL_SECONDS[2]:  # coming down, from the upper left to the ground
			var near := 1.0 - (d - FALL_SECONDS[0]) / (FALL_SECONDS[2] - FALL_SECONDS[0])  # 1 high up, 0 landing
			cell.position -= Vector2.ONE * Overlays.TILE * (0.15 + 1.2 * near)
			tex = SkyArt.frame(atlas, 0 if d < FALL_SECONDS[1] else 1)
		else:  # the splash, a little wider each moment
			var life := (d - FALL_SECONDS[2]) / (FALL_SECONDS[3] - FALL_SECONDS[2])
			tint = Color(1, 1, 1, 1.0 - life * life)
			cell = cell.grow(Overlays.TILE * 0.25 * life)
			var pick: int = posmod(f["pos"].x * 7 + f["pos"].y * 13, 3)
			tex = SkyArt.frame(atlas, 2) if pick == 0 else SkyArt.whole("seed_fall_splash_%d" % pick)
		if tex != null:
			ci.draw_texture_rect(tex, cell, false, tint)


## The way to the site: gold edges laid along the road shoulders on every road tile of it (straight, or a corner where it turns), and
## the faint line where the road is not yet laid.
static func _way(ci: CanvasItem, s, site: Vector2i, k: float) -> void:
	var way: Array = s.skyreach.way
	var straight := SkyArt.whole("skyreach_way")
	var corner := SkyArt.whole("skyreach_way_corner")
	for i in way.size():
		var p: Vector2i = way[i]
		var back: Vector2i = (site if i == 0 else way[i - 1]) - p
		var ahead: Vector2i = (way[i + 1] - p) if i + 1 < way.size() else -back  # the last tile runs on into the depot
		if not s.world.roads.has(p) or straight == null or corner == null:
			ci.draw_line(Overlays.center(p), Overlays.center(p + back), HELD, 3.0 * k, true)
			continue
		var piece := way_piece(back, ahead)
		var tex := straight if piece[0] == "skyreach_way" else corner
		var turns: int = piece[1]
		var c := Overlays.center(p)
		ci.draw_set_transform(c, turns * PI / 2.0)
		ci.draw_texture_rect(tex, Rect2(-Overlays.TILE * 0.5 * Vector2.ONE, Vector2.ONE * Overlays.TILE), false)
		ci.draw_set_transform(Vector2.ZERO)


## Which picture lays a tile of the way that joins the sides `back` and `ahead` (steps to its neighbours), and how many quarter turns
## clockwise it is turned: the straight one runs left to right, the corner one joins left and down.
static func way_piece(back: Vector2i, ahead: Vector2i) -> Array:
	if back + ahead == Vector2i.ZERO:
		return ["skyreach_way", 0 if back.y == 0 else 1]
	return ["skyreach_way_corner", int(CORNER_TURNS[back + ahead])]
