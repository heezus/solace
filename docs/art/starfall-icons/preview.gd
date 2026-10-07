extends SceneTree
## Documentation-only native artwork preview; no saves or simulation.
const Rendered = preload("res://scripts/rendered_art.gd")
const HERE := "res://docs/art/starfall-icons/"

class Board extends Node2D:
	var specs: Array = []
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1120, 600), Color("172c30"))
		text(Vector2(24,32), "Starfall current icons / native 24, 32 and 40 px / Godot art board", 22)
		for i in specs.size():
			var spec: Dictionary = specs[i]
			var x := 24.0 + (i % 7) * 156.0
			var y := 118.0 + int(i / 7) * 138.0
			text(Vector2(x, y - 16), spec.id, 13)
			for sample in 3:
				var px := 24 + sample * 8
				var box := Rect2(Vector2(x + [0, 32, 74][sample], y), Vector2.ONE * px)
				draw_rect(box, Color("243b40"))
				Rendered.fit(self, spec.texture, box)
		text(Vector2(24, 345), "96 px inspection samples; emblems decorate headings, not the twenty code-drawn glyph marks.", 18)
		var selected := [0, 3, 7, 13]
		for i in selected.size():
			var spec: Dictionary = specs[selected[i]]
			var x := 32.0 + i * 268.0
			text(Vector2(x,385), spec.id, 17)
			Rendered.fit(self,spec.texture,Rect2(Vector2(x,402),Vector2(96,96)))
		text(Vector2(24,565), "Original transparent atlas; labels and hover descriptions belong in the live UI. No new stockpile goods.", 16)
	func text(at: Vector2, message: String, px: int) -> void:
		draw_string(ThemeDB.fallback_font, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("e7e3d4"))

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1120, 600)
	root.content_scale_size = Vector2i(1120, 600)
	var specs: Array = JSON.parse_string(FileAccess.get_file_as_string(HERE + "spec.json"))
	var manifest := []
	var board := Board.new()
	for spec in specs:
		var tex: Texture2D = load(spec.path)
		var image := tex.get_image()
		if image.is_compressed():
			image.decompress()
		var step := image.get_size() / Vector2i(int(spec.grid[0]), int(spec.grid[1]))
		var cell := Rect2i(Vector2i(int(spec.cell) % int(spec.grid[0]), int(spec.cell) / int(spec.grid[0])) * step, step)
		var bounds := subject_bounds(image, cell)
		if not image.detect_alpha() or bounds.size.x <= 0 or bounds.size.y <= 0:
			push_error("Missing transparent subject: " + spec.id)
			quit(1)
			return
		var region := AtlasTexture.new()
		region.atlas = tex
		region.region = bounds
		region.filter_clip = true
		board.specs.append({"id": spec.id, "size": spec.size, "texture": region})
		manifest.append({"id":spec.id,"path":spec.path,"source_size":[image.get_width(),image.get_height()],"region":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"size":spec.size,"anchor":"bottom_center"})
		print(spec.id, " region=", bounds)
	root.add_child(board)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(HERE + "native-board.png")
	var file := FileAccess.open(HERE + "regions.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	print("ICONS_CAPTURE saved=", error)
	quit(0 if error == OK else 1)

func subject_bounds(image: Image, cell: Rect2i) -> Rect2i:
	# Seed the nearest opaque pixel to this cell's center; follow only its subject.
	var center := cell.get_center()
	var seed := Vector2i(-1,-1)
	var distance := 2147483647
	for y in range(cell.position.y,cell.end.y):
		for x in range(cell.position.x,cell.end.x):
			var d := (x-center.x)*(x-center.x)+(y-center.y)*(y-center.y)
			if d < distance and image.get_pixel(x,y).a > 0.05:
				seed=Vector2i(x,y)
				distance=d
	if seed.x < 0:
		return Rect2i()
	var low := seed
	var high := seed
	var width := image.get_width()
	var visited := PackedByteArray()
	visited.resize(width*image.get_height())
	var queue := PackedInt32Array([seed.y*width+seed.x])
	visited[queue[0]]=1
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor+=1
		var at := Vector2i(index%width,int(index/width))
		low.x=mini(low.x,at.x)
		low.y=mini(low.y,at.y)
		high.x=maxi(high.x,at.x)
		high.y=maxi(high.y,at.y)
		for dy in range(-1,2):
			for dx in range(-1,2):
				var next := at+Vector2i(dx,dy)
				if next.x<0 or next.y<0 or next.x>=width or next.y>=image.get_height():
					continue
				var next_index := next.y*width+next.x
				if visited[next_index]:
					continue
				visited[next_index]=1
				if image.get_pixel(next.x,next.y).a>0.05:
					queue.append(next_index)
	return Rect2i(low,high-low+Vector2i.ONE).grow(4).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
