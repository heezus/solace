extends SceneTree
## Native material-scale fixture, not the live terrain shader or a generated-map acceptance pass.
## Uses the production sprite helpers and identical placements for before/after at 24/48/80 px per tile.
## Run with a display: godot --path . -s tests/tools/era_ground_scale.gd -- [output_dir]

const Rendered = preload("res://scripts/rendered_art.gd")
const Art = preload("res://scripts/art.gd")
const FAMILIES := [
	["Starfall meadow", "starfall-meadow"],
	["Starfall woodland", "starfall-woodland"],
	["Bronze Dawn", "bronze-dawn-earth"],
	["Ironfall south", "earth-south"],
	["Coal / Ironstone apron", "ironfall-apron"],
	["Livewire healthy", "livewire-healthy"],
	["Livewire Bloom", "livewire-bloom"],
	["Livewire firebreak", "livewire-firebreak"],
]
const REVIEW := "res://docs/art/terrain-kit/era-ground/corrections-v2/"
const SHEETS := "res://art/rendered/era-ground/"

var out := REVIEW.path_join("native")
var page := 0
var frames := 0
var board: ReviewBoard


class GroundPanel:
	extends Node2D
	var texture: Texture2D

	func _draw() -> void:
		# Eight by four tiles, fixed 96 source texture pixels per tile in both columns.
		draw_texture_rect_region(texture, Rect2(0, 0, 384, 192), Rect2(384, 480, 768, 384))
		Art.map_feature(self, "tree", Vector2(225, 68), Vector2i(4, 1), 0.0, 1.5)
		Art.map_feature(self, "coal_seam", Vector2(319, 56), Vector2i(6, 1), 0.0, 1.5)
		Art.map_feature(self, "rock", Vector2(323, 129), Vector2i(6, 2), 0.0, 1.5)
		Art.map_feature(self, "iron_hills", Vector2(252, 159), Vector2i(5, 3), 0.0, 1.5)
		var hearth := Rect2(42, 48, 96, 96)
		Art.contact_shadow(self, Vector2(hearth.get_center().x, hearth.end.y - 2.0), Vector2(36.48, 5.28))
		Art.map_building(self, "camp", hearth, false, 0.0)
		Art.map_building(self, "dwelling", Rect2(148, 20, 48, 48), false, 0.0)
		Rendered.kith(self, Vector2(172, 146), "scale-worker", false, 0.0, false)
		Rendered.kith(self, Vector2(205, 151), "scale-walker", true, 0.25, false)


class ReviewBoard:
	extends Node2D
	var family := ""

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1560, 1000), Color("202b27"))
		var font: Font = ThemeDB.fallback_font
		draw_string(
			font,
			Vector2(40, 34),
			family + " - native Godot sprite-scale comparison",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			24,
			Color("eee8d3")
		)
		draw_string(
			font,
			Vector2(40, 60),
			"Asset fixture; fixed sprite sizes and 96 texture px/tile. No live terrain shader, biome mask or map generation.",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			17,
			Color("bcc7b3")
		)
		draw_string(font, Vector2(40, 92), "BEFORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("eee8d3"))
		draw_string(font, Vector2(800, 92), "CORRECTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("eee8d3"))
		for spec in [[24, 115], [48, 295], [80, 575]]:
			draw_string(
				font, Vector2(40, spec[1]), "%d px/tile" % spec[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("bcc7b3")
			)
		draw_string(
			font,
			Vector2(40, 964),
			"Production helpers: 2x2 Hearth, 1x1 Dwelling; tree, ordinary rock, Coal Seam, Ironstone; Kith at 35 px per 48 px tile.",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color("bcc7b3")
		)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1560, 1000)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	Rendered.map_seed = 3
	_show_page.call_deferred()


func _texture(path: String) -> Texture2D:
	var source := Image.load_from_file(ProjectSettings.globalize_path(path))
	assert(source != null and not source.is_empty(), "Missing review sheet: " + path)
	assert(source.get_size() == Vector2i(1920, 1920), "Unexpected sheet sampling contract: " + path)
	return ImageTexture.create_from_image(source)


func _show_page() -> void:
	board = ReviewBoard.new()
	board.family = FAMILIES[page][0]
	board.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(board)
	var slot: String = FAMILIES[page][1]
	for col in 2:
		var path := REVIEW.path_join("before/" + slot + ".png") if col == 0 else SHEETS.path_join(slot + ".png")
		var texture := _texture(path)
		for spec in [[24, 130], [48, 310], [80, 590]]:
			var panel := GroundPanel.new()
			panel.texture = texture
			panel.position = Vector2(40 + col * 760, spec[1])
			panel.scale = Vector2.ONE * float(spec[0]) / 48.0
			board.add_child(panel)


func _process(_delta: float) -> bool:
	if board == null:
		return false
	frames += 1
	if frames == 8:
		var path := out.path_join(String(FAMILIES[page][1]) + ".png")
		var capture := root.get_texture().get_image().get_region(Rect2i(0, 0, 1560, 1000))
		var error := capture.save_png(ProjectSettings.globalize_path(path))
		assert(error == OK, "Could not save material scale comparison")
		print("Wrote ", path)
		board.queue_free()
		board = null
		frames = 0
		page += 1
		if page == FAMILIES.size():
			quit()
		else:
			_show_page.call_deferred()
	return false
