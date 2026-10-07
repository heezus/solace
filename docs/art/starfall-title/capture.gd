extends SceneTree
## Captures the actual title scene, without entering gameplay or touching a run save.

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	var title = load("res://scenes/title.tscn").instantiate()
	title.save_path = "user://starfall-title-preview-nonexistent.save"
	root.add_child(title)
	current_scene = title
	for dimensions in [Vector2i(1280, 800), Vector2i(1600, 900)]:
		root.size = dimensions
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var path := "res://docs/art/starfall-title/menu-%dx%d.png" % [dimensions.x, dimensions.y]
		var error := img.save_png(path)
		print("TITLE_CAPTURE ", dimensions, " texture=", title._art.get_size(), " saved=", error)
		if error != OK or title._art == null:
			quit(1)
			return
	quit()
