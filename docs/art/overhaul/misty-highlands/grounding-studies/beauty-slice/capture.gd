extends SceneTree
const World = preload("res://scripts/world.gd")
const Fog = preload("res://scripts/fog.gd")
const Before = preload("res://scripts/world_ground.gd")
const After = preload("res://docs/art/overhaul/misty-highlands/grounding-studies/beauty-slice/ground.gd")
const Art = preload("res://scripts/rendered_art.gd")
const Bridge = preload(
	"res://docs/art/overhaul/misty-highlands/grounding-studies/shoreline-crossings-study/study-bridge.gd"
)
var state: Dictionary
var grounds: Array = []
var canvases: Array[Node2D] = []
var frame := 0
var snapshot: Dictionary


static func make_state() -> Dictionary:
	var world := World.new(16, 12)
	world.map_seed = 47
	var fog := Fog.new()
	fog.setup(16, 12)
	fog.reveal_all()
	for y in 7:
		for x in [10, 11]:
			world.set_tile(Vector2i(x, y), "river")
	for x in [11, 12, 13]:
		world.set_tile(Vector2i(x, 6), "river")
	for y in range(7, 12):
		world.set_tile(Vector2i(13, y), "river")
	for p in [
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(1, 2),
		Vector2i(2, 2),
		Vector2i(3, 2),
		Vector2i(3, 1),
		Vector2i(2, 3),
		Vector2i(1, 3),
		Vector2i(14, 1),
		Vector2i(15, 2),
		Vector2i(15, 1),
		Vector2i(14, 2),
		Vector2i(15, 3)
	]:
		world.set_tile(p, "tree")
	for p in [Vector2i(7, 8), Vector2i(8, 8), Vector2i(8, 9)]:
		world.set_tile(p, "rock")
	for p in [Vector2i(2, 8), Vector2i(2, 9), Vector2i(3, 9)]:
		world.set_tile(p, "berry")
	for p in [Vector2i(7, 1), Vector2i(8, 1), Vector2i(7, 2)]:
		world.set_tile(p, "grain")
	for x in range(4, 16):
		world.roads[Vector2i(x, 4)] = true
	for y in [5, 6]:
		world.roads[Vector2i(4, y)] = true
	var buildings := [{"type": "camp", "pos": Vector2i(4, 6)}, {"type": "gatherers_hut", "pos": Vector2i(7, 4)}]
	return {
		"world": world,
		"fog": fog,
		"town": {"building_at": {Vector2i(4, 6): 0, Vector2i(7, 4): 1}, "buildings": buildings},
		"tech_tree": {"researched": {}}
	}


func _init() -> void:
	state = make_state()
	snapshot = state.world.to_dict()
	grounds = [Before.new(), After.new()]
	grounds[1].layered = true
	for i in 2:
		var canvas := Node2D.new()
		canvas.position = Vector2(24 + i * 800, 72)
		root.add_child(canvas)
		canvas.draw.connect(_draw_panel.bind(i))
		canvases.append(canvas)
		var label := Label.new()
		label.position = Vector2(24 + i * 800, 18)
		label.text = "CURRENT GAME MATERIALS" if i == 0 else "LAYERED GROUND / BANK / WATER STUDY"
		label.add_theme_font_size_override("font_size", 22)
		root.add_child(label)
	var footer := Label.new()
	footer.position = Vector2(24, 670)
	footer.text = "Native Godot · identical state, sprites and 48 px camera · review-only · no game renderer replacement"
	footer.add_theme_font_size_override("font_size", 18)
	root.add_child(footer)
	for canvas in canvases:
		canvas.queue_redraw()


func _draw_panel(i: int) -> void:
	var canvas := canvases[i]
	grounds[i].draw(canvas, state, Rect2i(0, 0, 16, 12))
	for y in state.world.height:
		for x in state.world.width:
			var p := Vector2i(x, y)
			if state.world.roads.has(p) and state.world.tile_at(p) == "river":
				Bridge.draw(canvas, state, p)
			elif state.world.tile_at(p) not in ["grass", "river"]:
				Art.feature(canvas, state.world.tile_at(p), (Vector2(p) + Vector2.ONE * 0.5) * 48, p, 0)
	for b in state.town.buildings:
		var size := Vector2(96, 96) if b.type == "camp" else Vector2(48, 48)
		Art.building(canvas, b.type, Rect2(Vector2(b.pos) * 48, size))
	Art.kith(canvas, Vector2(300, 300), "slice-1", false, 0, false)
	Art.kith(canvas, Vector2(400, 228), "slice-2", false, 0, true)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1616, 720)
		root.content_scale_size = Vector2i(1616, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	if frame == 20:
		_capture.call_deferred()
	return false


func _capture() -> void:
	if snapshot != state.world.to_dict():
		printerr("BEAUTY: capture changed world state")
		quit(1)
		return
	var err := root.get_texture().get_image().save_png("/tmp/solace-beauty-comparison.png")
	print("Native beauty comparison: error=", err)
	quit(err)
