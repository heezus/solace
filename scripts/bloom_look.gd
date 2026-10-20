extends RefCounted
## Bloom sample identity in design units (32 per tile). WorldGround paints the ground and creeping edges.
## Existing sample IDs retain their breathing animation and colors beneath a painted vine decal; no state changes.

const OUTLINE := Color("1b1b1f")
const SAMPLE := {"bloom_spore": Color("c04a9d"), "bloom_root": Color("6fa84a"), "bloom_sap": Color("d98ad0")}

static var _sheet: Texture2D


## Draw the tile `type` ("bloom_ground" or a sample tile) at `p`. True when `type` is a Bloom tile.
static func draw(ci: CanvasItem, type: String, c: Vector2, p: Vector2i, time: float) -> bool:
	if not type.begins_with("bloom_"):
		return false
	if SAMPLE.has(type):
		var pulse := 1.0 + 0.12 * sin(time * 1.6 + p.x)
		if _sheet == null:
			_sheet = load("res://art/rendered/era-ground/decals.png") as Texture2D
		var cell := 24 + absi(p.x * 73 + p.y * 151) % 4
		var source := Rect2(Vector2(cell % 8, floori(cell / 8.0)) * 96.0, Vector2(96, 96))
		ci.draw_texture_rect_region(_sheet, Rect2(c - Vector2(16, 16) * pulse, Vector2(32, 32) * pulse), source)
		# Keep the existing sample's color identity as a small breathing center, below the painted detail's size.
		ci.draw_circle(c, 3.5 * pulse, OUTLINE)
		ci.draw_circle(c, 2.5 * pulse, SAMPLE[type])
	return true
