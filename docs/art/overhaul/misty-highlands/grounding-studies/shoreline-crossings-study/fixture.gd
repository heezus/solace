extends SceneTree
const World = preload("res://scripts/world.gd")
const Fog = preload("res://scripts/fog.gd")
const Ground = preload(
	"res://docs/art/overhaul/misty-highlands/grounding-studies/shoreline-crossings-study/study-ground.gd"
)
const Bridge = preload(
	"res://docs/art/overhaul/misty-highlands/grounding-studies/shoreline-crossings-study/study-bridge.gd"
)
const Art = preload("res://scripts/rendered_art.gd")
var state: Dictionary
var canvas: Node2D
var ground := Ground.new()
var frames := 0


static func make_state() -> Dictionary:
	var world := World.new(24, 14)
	world.map_seed = 47
	var fog := Fog.new()
	fog.setup(24, 14)
	fog.reveal_all()
	# West: two-cell river, elbow, then a narrow one-cell reach.
	for y in 8:
		for x in [5, 6]:
			world.set_tile(Vector2i(x, y), "river")
	for x in range(5, 9):
		world.set_tile(Vector2i(x, 7), "river")
		world.set_tile(Vector2i(x, 8), "river")
	for y in range(9, 14):
		world.set_tile(Vector2i(8, y), "river")
	# East: broad horizontal reach, with an inlet/convex point below.
	for x in range(13, 24):
		for y in [4, 5, 6]:
			world.set_tile(Vector2i(x, y), "river")
	for y in [7, 8, 9]:
		for x in [13, 14]:
			world.set_tile(Vector2i(x, y), "river")
	for x in [15, 16, 17]:
		world.set_tile(Vector2i(x, 9), "river")
	# Bridges and adjacent existing roads; visual fixture never invokes the economy.
	for x in range(1, 11):
		world.roads[Vector2i(x, 3)] = true
	for x in range(5, 12):
		var p := Vector2i(x, 11)
		world.roads[p] = true
		if world.tile_at(p) == "river":
			world.stone_bridges[p] = true
	for y in range(1, 11):
		world.roads[Vector2i(17, y)] = true
		var p := Vector2i(21, y)
		world.roads[p] = true
		if world.tile_at(p) == "river":
			world.stone_bridges[p] = true
	for p in [Vector2i(1, 1), Vector2i(10, 6), Vector2i(19, 12), Vector2i(22, 12)]:
		world.set_tile(p, "tree")
	world.set_tile(Vector2i(2, 9), "rock")
	return {"world": world, "fog": fog, "town": {"building_at": {}, "buildings": []}, "tech_tree": {"researched": {}}}


func _init() -> void:
	state = make_state()
	root.size = Vector2i(1280, 800)
	root.mode = Window.MODE_WINDOWED
	canvas = Node2D.new()
	canvas.position = Vector2(64, 80)
	canvas.draw.connect(_draw_map)
	root.add_child(canvas)
	var label := Label.new()
	label.position = Vector2(64, 16)
	label.text = "NATIVE GODOT STUDY · 48 px tiles · Wood and stone crossings / bank bends"
	label.add_theme_font_size_override("font_size", 22)
	root.add_child(label)
	var footer := Label.new()
	footer.position = Vector2(64, 758)
	footer.text = "Review fixture only · upper-left lighting stays fixed · separate stones follow the shore · normal game unchanged"
	footer.add_theme_font_size_override("font_size", 17)
	root.add_child(footer)
	canvas.queue_redraw()


func _draw_map() -> void:
	ground.draw(canvas, state, Rect2i(0, 0, 24, 14))
	for y in state.world.height:
		for x in state.world.width:
			var p := Vector2i(x, y)
			if state.world.roads.has(p) and state.world.tile_at(p) == "river":
				Bridge.draw(canvas, state, p)
			elif state.world.tile_at(p) != "grass" and state.world.tile_at(p) != "river":
				Art.feature(canvas, state.world.tile_at(p), (Vector2(p) + Vector2.ONE * 0.5) * 48, p, 0)
	Art.building(canvas, "gatherers_hut", Rect2(48, 144, 48, 48))
	Art.kith(canvas, Vector2(190, 165), "fixture", false, 0, false)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 800)
		root.content_scale_size = Vector2i(1280, 800)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	if frames == 15:
		_capture.call_deferred()
	return false


func _capture() -> void:
	var path := "/tmp/solace-shoreline-crossings.png"
	var error := root.get_texture().get_image().save_png(path)
	print("Native fixture capture: ", path, " error=", error)
	quit(error)
