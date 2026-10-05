extends RefCounted
static var _sheet: Texture2D
static var _sprites := {}


static func sprite(index: int) -> AtlasTexture:
	if not _sprites.has(index):
		var image := Image.load_from_file(
			"res://docs/art/overhaul/misty-highlands/grounding-studies/shoreline-crossings-study/bank-props.png"
		)
		if _sheet == null:
			_sheet = ImageTexture.create_from_image(image)
		var row := index / 3
		var col := index % 3
		var heights := [0, 390, 756, 1280]
		var widths := [0, 426, 853, 1280]
		var cell := Rect2i(widths[col], heights[row], widths[col + 1] - widths[col], heights[row + 1] - heights[row])
		var used := image.get_region(cell).get_used_rect()
		var texture := AtlasTexture.new()
		texture.atlas = _sheet
		texture.region = Rect2(cell.position + used.position, used.size)
		texture.filter_clip = true
		_sprites[index] = texture
	return _sprites[index]
