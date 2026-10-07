extends SceneTree


func bounds(image: Image, area: Rect2i) -> Rect2i:
	var low := area.end
	var high := area.position
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if image.get_pixel(x, y).a > 0.08:
				low = low.min(Vector2i(x, y))
				high = high.max(Vector2i(x, y) + Vector2i.ONE)
	return Rect2i(low, high - low)


func _initialize() -> void:
	for file in ["growth-houses", "growth-scaffold", "growth-hand-cart", "growth-roads"]:
		var path: String = "res://art/rendered/" + file + ".png"
		if not FileAccess.file_exists(path):
			continue
		var source := Image.load_from_file(path)
		print(file, " size ", source.get_size())
		if file == "growth-houses":
			var seam := 0
			var least := source.get_height()
			for x in range(int(source.get_width() * 0.40), int(source.get_width() * 0.55)):
				var count := 0
				for y in range(source.get_height()):
					if source.get_pixel(x, y).a > 0.4:
						count += 1
				if count < least:
					least = count
					seam = x
			print(" seam ", seam, " solid pixels ", least)
			print(" homestead ", bounds(source, Rect2i(0, 0, seam, source.get_height())))
			print(" longhouse ", bounds(source, Rect2i(seam, 0, source.get_width() - seam, source.get_height())))
		else:
			print(" bounds ", bounds(source, Rect2i(Vector2i.ZERO, source.get_size())))
	quit()
