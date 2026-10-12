extends RefCounted
## Placeholder art for the Bloom patches in the far south (design-system/19-ironfall.md, stage 2): a tile of green and magenta
## ground and, at a patch's middle, a breathing bulb in the colour of its sample (spore, root, sap). Drawn in design units (a tile is
## Art.DESIGN across, centred on `c`) from Rendered.feature until Codex paints tiles for them (docs/art/requests.md, "Bloom patch
## tiles"). The look depends only on the tile's position, never on chance.

const GROUND := Color(0.62, 0.22, 0.58, 0.5)
const GREEN := Color(0.33, 0.62, 0.25, 0.55)
const MAGENTA := Color(0.75, 0.29, 0.62, 0.6)
const OUTLINE := Color("1b1b1f")
const SAMPLE := {"bloom_spore": Color("c04a9d"), "bloom_root": Color("6fa84a"), "bloom_sap": Color("d98ad0")}


## Draw the tile `type` ("bloom_ground" or a sample tile) at `p`. True when `type` is a Bloom tile.
static func draw(ci: CanvasItem, type: String, c: Vector2, p: Vector2i, time: float) -> bool:
	if not type.begins_with("bloom_"):
		return false
	ci.draw_rect(Rect2(c - Vector2(16, 16), Vector2(32, 32)), GROUND)
	for i in 3:
		var h := (p.x * 73 + p.y * 151 + i * 37) % 97
		var at := c + Vector2((h % 19) - 9, ((h * 7) % 19) - 9)
		ci.draw_circle(at, 4.0 + (h % 4), GREEN if (h + i) % 2 == 0 else MAGENTA)
	if SAMPLE.has(type):
		var pulse := 1.0 + 0.12 * sin(time * 1.6 + p.x)
		for i in 5:
			var a := TAU * i / 5.0 + 0.4
			var tip := c + Vector2.from_angle(a) * 11.0 * pulse
			ci.draw_line(c, tip, OUTLINE, 5.0)
			ci.draw_line(c, tip, GREEN.lightened(0.2), 3.0)
		ci.draw_circle(c, 7.5 * pulse, OUTLINE)
		ci.draw_circle(c, 5.5 * pulse, SAMPLE[type])
	return true
