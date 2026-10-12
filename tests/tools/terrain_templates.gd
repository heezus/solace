extends SceneTree
## Draws the three template sheets of the terrain kit (docs/art/terrain-kit/): a seamless ground sheet, a decal atlas and a bank
## strip, each with the tile grid on it and the slots numbered. They are guides to paint over, never loaded by the game.
## Run: godot --headless --path . -s tests/tools/terrain_templates.gd -- [output_dir]

const PX_PER_TILE := 96  # source pixels for one 48 px map tile: twice the default zoom, enough for the closest zoom (80 px)
const GROUND_TILES := 20  # a seamless ground sheet covers 20 by 20 map tiles (1920 px)
const DECAL_COLS := 8
const DECAL_ROWS := 4
const BANK_TILES := 20  # the bank strip is as wide as the ground sheet and two tiles tall
const DIGITS := {
	"0": ["111", "101", "101", "101", "111"],
	"1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"],
	"3": ["111", "001", "111", "001", "111"],
	"4": ["101", "101", "111", "001", "001"],
	"5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"],
	"7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"],
	"9": ["111", "101", "111", "001", "111"],
}
const GRID := Color(1, 1, 1, 0.22)
const GRID_5 := Color(1, 1, 1, 0.5)
const MARK_LEFT_RIGHT := Color("e0407a")
const MARK_TOP_BOTTOM := Color("20b8d8")
const SUN := Color("ffd23f")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := (args[0] if args.size() > 0 else "docs/art/terrain-kit").path_join("templates")
	DirAccess.make_dir_recursive_absolute(out)
	_ground().save_png(out.path_join("ground-seamless-1920.png"))
	_decals().save_png(out.path_join("decal-atlas-768x384.png"))
	_bank().save_png(out.path_join("bank-strip-1920x192.png"))
	print("wrote the templates to ", out)
	quit()


## 1920 x 1920: tile grid, the edges colored so left meets right and top meets bottom, one tile outlined at the top left.
func _ground() -> Image:
	var size := GROUND_TILES * PX_PER_TILE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color("5d7a45"))
	_grid(img, Rect2i(0, 0, size, size))
	_rect(img, Rect2i(0, 0, 12, size), MARK_LEFT_RIGHT)  # left and right edges: the same pattern must continue across
	_rect(img, Rect2i(size - 12, 0, 12, size), MARK_LEFT_RIGHT)
	_rect(img, Rect2i(0, 0, size, 12), MARK_TOP_BOTTOM)  # top and bottom edges
	_rect(img, Rect2i(0, size - 12, size, 12), MARK_TOP_BOTTOM)
	_frame(img, Rect2i(PX_PER_TILE, PX_PER_TILE, PX_PER_TILE, PX_PER_TILE), Color.WHITE, 4)  # one map tile at 96 px
	_sun(img, Vector2i(PX_PER_TILE * 2 + 40, PX_PER_TILE + 48))
	_number(img, Vector2i(PX_PER_TILE + 12, PX_PER_TILE + 12), 1, 6, Color.WHITE)
	return img


## 768 x 384: eight by four cells of one map tile (96 px), each numbered 1 to 32, transparent inside.
func _decals() -> Image:
	var img := Image.create(DECAL_COLS * PX_PER_TILE, DECAL_ROWS * PX_PER_TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for row in DECAL_ROWS:
		for col in DECAL_COLS:
			var cell := Rect2i(col * PX_PER_TILE, row * PX_PER_TILE, PX_PER_TILE, PX_PER_TILE)
			var tint := Color.from_hsv(float(row) / DECAL_ROWS, 0.45, 0.9, 0.18)
			_rect(img, cell, tint)
			_frame(img, cell, Color(1, 1, 1, 0.8), 2)
			_cross(img, cell.get_center(), 10, Color(1, 1, 1, 0.7))  # the cell's center: where the decal sits on its tile
			_number(img, cell.position + Vector2i(6, 6), row * DECAL_COLS + col + 1, 4, Color.WHITE)
	return img


## 1920 x 192: land on the top tile, water on the bottom tile, the waterline along the middle; left meets right.
func _bank() -> Image:
	var w := BANK_TILES * PX_PER_TILE
	var h := 2 * PX_PER_TILE
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	_rect(img, Rect2i(0, 0, w, PX_PER_TILE), Color("5d7a45"))
	_rect(img, Rect2i(0, PX_PER_TILE, w, PX_PER_TILE), Color("2f7f95"))
	_grid(img, Rect2i(0, 0, w, h))
	_rect(img, Rect2i(0, PX_PER_TILE - 3, w, 6), Color("ffffff"))  # the waterline
	_rect(img, Rect2i(0, 0, 12, h), MARK_LEFT_RIGHT)
	_rect(img, Rect2i(w - 12, 0, 12, h), MARK_LEFT_RIGHT)
	_sun(img, Vector2i(60, 30))
	return img


func _grid(img: Image, area: Rect2i) -> void:
	for i in range(0, area.size.x + 1, PX_PER_TILE):
		var x := mini(area.position.x + i, area.end.x - 1)
		_rect(img, Rect2i(x, area.position.y, 1, area.size.y), GRID_5 if int(float(i) / PX_PER_TILE) % 5 == 0 else GRID)
	for i in range(0, area.size.y + 1, PX_PER_TILE):
		var y := mini(area.position.y + i, area.end.y - 1)
		_rect(img, Rect2i(area.position.x, y, area.size.x, 1), GRID_5 if int(float(i) / PX_PER_TILE) % 5 == 0 else GRID)


## A sun with a ray pointing to the lower right: light comes from the upper left, so shadows fall to the lower right.
func _sun(img: Image, at: Vector2i) -> void:
	for y in range(-14, 15):
		for x in range(-14, 15):
			if x * x + y * y <= 196:
				_put(img, at + Vector2i(x, y), SUN)
	for i in range(18, 60):
		for t in range(-2, 3):
			_put(img, at + Vector2i(i + t, i - t), SUN)


func _rect(img: Image, r: Rect2i, color: Color) -> void:
	var clipped := r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			img.set_pixel(x, y, img.get_pixel(x, y).blend(color) if color.a < 1.0 else color)


func _frame(img: Image, r: Rect2i, color: Color, thick: int) -> void:
	_rect(img, Rect2i(r.position, Vector2i(r.size.x, thick)), color)
	_rect(img, Rect2i(r.position + Vector2i(0, r.size.y - thick), Vector2i(r.size.x, thick)), color)
	_rect(img, Rect2i(r.position, Vector2i(thick, r.size.y)), color)
	_rect(img, Rect2i(r.position + Vector2i(r.size.x - thick, 0), Vector2i(thick, r.size.y)), color)


func _cross(img: Image, c: Vector2i, arm: int, color: Color) -> void:
	_rect(img, Rect2i(c.x - arm, c.y - 1, arm * 2 + 1, 2), color)
	_rect(img, Rect2i(c.x - 1, c.y - arm, 2, arm * 2 + 1), color)


func _put(img: Image, p: Vector2i, color: Color) -> void:
	if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
		img.set_pixelv(p, color)


## Draws `value` in a 3 by 5 pixel font, each pixel `scale` pixels square, over a dark plate.
func _number(img: Image, at: Vector2i, value: int, scale: int, color: Color) -> void:
	var text := str(value)
	var plate := Rect2i(at - Vector2i(2, 2), Vector2i(text.length() * 4 * scale + 3, 5 * scale + 4))
	_rect(img, plate, Color(0, 0, 0, 0.6))
	for i in text.length():
		var glyph: Array = DIGITS[text[i]]
		for gy in 5:
			for gx in 3:
				if glyph[gy][gx] == "1":
					_rect(img, Rect2i(at + Vector2i((i * 4 + gx) * scale, gy * scale), Vector2i(scale, scale)), color)
