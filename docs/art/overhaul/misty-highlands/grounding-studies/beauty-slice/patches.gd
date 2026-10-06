extends RefCounted
static var _sheet: Texture2D
static var _sprites := {}


static func sprite(index: int) -> AtlasTexture:
	if not _sprites.has(index):
		var image := Image.load_from_file(
			"res://docs/art/overhaul/misty-highlands/grounding-studies/beauty-slice/ground-patches.png"
		)
		if _sheet == null:
			_sheet = ImageTexture.create_from_image(image)
		var w := image.get_width() / 3
		var h := image.get_height() / 2
		var cell := Rect2i(index % 3 * w, index / 3 * h, w, h)
		var used := image.get_region(cell).get_used_rect()
		var tex := AtlasTexture.new()
		tex.atlas = _sheet
		tex.region = Rect2(cell.position + used.position, used.size)
		tex.filter_clip = true
		_sprites[index] = tex
	return _sprites[index]
