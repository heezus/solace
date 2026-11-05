extends RefCounted
## Codex's painted Skyreach art (docs/art/skyreach/*): the Signal Tower's two states, the Skyreach's four stages, and the marks the sky
## draws on the map. The buildings are tall, so they stand on one tile and rise above it (a 1x1 footprint), bottom centre two pixels
## above the cell's bottom edge, scaled with the tile. Nothing here touches the simulation.

const DIR := "res://art/rendered/"
const TILE_PX := 48.0  # the tile the draw sizes below are given for
const FOOT_GAP := 2.0  # px above the cell's bottom edge the base stands, at that tile

## Each building picture: the painted region of its sheet [x, y, w, h] and how big it is drawn on a 48 px tile [w, h]
## (docs/art/skyreach/buildings/spec.json).
const TALL := {
	"signal_tower": [[138, 65, 692, 1464], [26, 55]],
	"signal_tower_lit": [[139, 312, 587, 1451], [26, 67]],
	"skyreach_tower_0": [[119, 153, 1290, 738], [46, 26]],
	"skyreach_tower_1": [[176, 0, 1186, 1010], [46, 39]],
	"skyreach_tower_2": [[50, 3, 981, 1448], [44, 65]],
	"skyreach_tower_3": [[68, 0, 883, 1509], [46, 79]],
}
const FRAME_PX := 192
const SIGNAL := "signal_tower"
const TOWER := "skyreach_tower"

static var _whole := {}
static var _tall := {}


## True for a building this file paints (the Signal Tower and the Skyreach).
static func draws(type: String) -> bool:
	return type == SIGNAL or type == TOWER


## The painted sheet `name` (art/rendered/<name>.png) whole, or null when it is not there.
static func whole(name: String) -> Texture2D:
	if not _whole.has(name):
		var path := DIR + name + ".png"
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
		_whole[name] = tex
	return _whole[name]


## The building picture `name` (a key of TALL): its painted region of the sheet, or null when the sheet is not there.
static func tall(name: String) -> Texture2D:
	if not _tall.has(name):
		var sheet := whole(name)
		var tex: AtlasTexture = null
		if sheet != null:
			var region: Array = TALL[name][0]
			tex = AtlasTexture.new()
			tex.atlas = sheet
			tex.region = Rect2(region[0], region[1], region[2], region[3])
			tex.filter_clip = true
		_tall[name] = tex
	return _tall[name]


## Frame `i` of the three-frame seed fall atlas (192 px each, left to right): the descent, the near impact, the landing splash.
static func frame(atlas: Texture2D, i: int) -> Texture2D:
	var key := "seed_fall:%d" % i
	if not _tall.has(key):
		var tex := AtlasTexture.new()
		tex.atlas = atlas
		tex.region = Rect2(i * FRAME_PX, 0, FRAME_PX, FRAME_PX)
		tex.filter_clip = true
		_tall[key] = tex
	return _tall[key]


## Which picture a building shows: the Signal Tower is lit while it warns of a landfall; the Skyreach shows the stage that stands.
static func name_of(type: String, lit: bool, stage: int) -> String:
	if type == SIGNAL:
		return "signal_tower_lit" if lit else "signal_tower"
	return "skyreach_tower_%d" % clampi(stage, 0, 3)


## The picture a card or the build bar shows for `type`: the idle Signal Tower, the finished Skyreach. Null for any other building.
static func icon(type: String) -> Texture2D:
	if not draws(type):
		return null
	return tall(name_of(type, false, 3))


## Where the picture `name` stands on the tile `r`: its drawn size scaled with the tile, bottom centre FOOT_GAP above its bottom edge.
static func rect_of(name: String, r: Rect2) -> Rect2:
	var k := r.size.x / TILE_PX
	var size := Vector2(TALL[name][1][0], TALL[name][1][1]) * k
	return Rect2(Vector2(r.get_center().x - size.x * 0.5, r.end.y - FOOT_GAP * k - size.y), size)


## Draw `type` on the tile `r`. Returns false when the art is missing, so the caller falls back to a plain plate.
static func draw(ci: CanvasItem, type: String, r: Rect2, lit: bool, stage: int, tint := Color.WHITE) -> bool:
	var name := name_of(type, lit, stage)
	var tex := tall(name)
	if tex == null:
		return false
	ci.draw_texture_rect(tex, rect_of(name, r), false, tint)
	return true
