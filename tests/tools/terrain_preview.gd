extends SceneTree
## Takes screenshots of the real ground and water on a generated map, so terrain art can be judged in the game's own renderer
## (see docs/art/terrain-kit/README.md). It needs a window: do not pass --headless.
## Run: godot --path . -s tests/tools/terrain_preview.gd -- [map_seed] [output_dir] [era] [baseline|current]
## Eras: stone (legacy default), bronze, starfall, ironfall, livewire. Baseline selects the merged base-kit materials.
## Writes <output_dir>/terrain_<seed>_<view>.png for: the town, a wide view (24 px tiles), a close view (80 px tiles, the most
## the game zooms), the river bank, a stretch of open meadow, a forest edge, and the new land south (after Ironfall grows it).

const TILE := 48.0
const VIEWS := ["town", "wide", "close", "bank", "meadow", "forest", "south"]

var main: Node
var frame := 0
var map_seed := 1
var out := "user://terrain_preview/"
var spots: Dictionary = {}
var era_name := "stone"
var baseline := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		map_seed = int(args[0])
	if args.size() > 1:
		out = args[1].path_join("")
	if args.size() > 2:
		era_name = args[2]
	if args.size() > 3:
		baseline = args[3] == "baseline"
	assert(era_name in ["stone", "starfall", "bronze", "ironfall", "livewire"], "Unknown preview era")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	DirAccess.make_dir_recursive_absolute(out)
	seed(map_seed)  # the game picks its map with randi(), so this makes the map the same every run
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	var s = main.state
	if frame == 2 or frame == 3:
		for n in main.find_children("*", "Control", true, false):  # a new run opens with its story still: skip it
			if n.has_method("skip") and "queue" in n:
				n.queue.clear()
				n.skip()
		main.paused = true
		main.set_process(false)
		main.set_process_unhandled_input(false)
	if frame == 2:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 800)
		root.content_scale_size = Vector2i(1280, 800)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		main.toasts.visible = false
		_prepare_era(s)
		if era_name in ["stone", "ironfall", "livewire"]:
			s.world.grow_south()
		s.fog.lengthen(s.world.height)  # reveal the added southern rows in this art-only fixture
		s.fog.reveal_all()
		spots = _find_spots(s.world)
		if baseline:
			main.ground.preview_family = 0
		if era_name == "bronze":
			spots["wide"] = Vector2i(s.world.stone_width + 10, s.world.base_height / 2)
			spots["close"] = _first(s.world, func(p): return s.world.tile_at(p) == "copper_hills", spots["wide"])
		elif era_name in ["ironfall", "livewire"]:
			spots["wide"] = spots["south"]
			spots["close"] = _southern(s.world, "bloom_spore" if era_name == "livewire" else "coal_seam")
			if era_name == "livewire":
				var burn := Vector2i(spots["close"]) + Vector2i(5, 0)
				for y in range(-2, 3):
					for x in range(-2, 3):
						var tile := burn + Vector2i(x, y)
						if s.world.in_bounds(tile) and s.world.tile_at(tile) != "river":
							s.tide.burnt[tile] = true
				s.tide.rev += 1
				spots["meadow"] = burn
	var step := 6
	var k := floori(float(frame - 4) / step)
	if frame >= 4 and k < VIEWS.size():
		var view: String = VIEWS[k]
		if (frame - 4) % step == 0:
			main.zoom_step = 0 if view == "wide" else (6 if view == "close" else 3)
			main.cam = Vector2(spots[view]) * TILE
		main.hover = Vector2i(-1, -1)
		main._layout()
		main._refresh_ui()
		main.queue_redraw()
		if (frame - 4) % step == step - 1:
			var path := "%sterrain_%d_%s.png" % [out, map_seed, view]
			root.get_texture().get_image().save_png(path)
			print("wrote ", ProjectSettings.globalize_path(path))
	elif k >= VIEWS.size():
		quit()
	return false


## Where to point the camera for each view (tile coordinates).
func _find_spots(w) -> Dictionary:
	var camp: Vector2i = w.camp_pos
	var found := {
		"town": camp,
		"wide": camp + Vector2i(0, 12),
		"close": camp + Vector2i(3, 3),
		"south": Vector2i(floori(w.width / 2.0), w.base_height + 10),
	}
	var bank := _first(w, func(p): return w.tile_at(p) == "grass" and w.touches_river(p), camp)
	found["bank"] = bank
	found["meadow"] = _first(w, func(p): return _all_around(w, p, 4, "grass"), camp)
	found["forest"] = _first(
		w, func(p): return w.tile_at(p) == "tree" and _all_around(w, p + Vector2i(-4, 0), 2, "grass"), camp
	)
	return found


## The tile nearest `near` (inside the original map) that passes `ok`, or `near` when none does.
func _first(w, ok: Callable, near: Vector2i) -> Vector2i:
	var best := near
	var best_d := 1 << 30
	for y in w.base_height:
		for x in w.width:
			var p := Vector2i(x, y)
			var d := (p - near).length_squared()
			if d < best_d and ok.call(p):
				best = p
				best_d = d
	return best


func _all_around(w, c: Vector2i, r: int, tile: String) -> bool:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var p := c + Vector2i(x, y)
			if not w.in_bounds(p) or w.tile_at(p) != tile:
				return false
	return true


## Display-only fixture setup: select existing milestones without running the economy or saving a run.
func _prepare_era(s) -> void:
	if era_name == "stone":
		return
	s.world.grow_east()
	s.fog.widen(s.world.width)
	s.story.events.append("bronze_dawn")
	s.tech_tree.researched["prospecting"] = true
	if era_name != "bronze":
		s.story.events.append("star_falling")
	if era_name in ["ironfall", "livewire"]:
		s.story.events.append("ironfall_begun")
		s.tech_tree.researched["coal_seams"] = true
		s.tech_tree.researched["ironstone"] = true
	if era_name == "livewire":
		s.story.events.append("livewire_begun")
		s.tide.begun = true


func _southern(w, kind: String) -> Vector2i:
	for y in range(w.base_height, w.height):
		for x in w.width:
			var p := Vector2i(x, y)
			if w.tile_at(p) == kind:
				return p
	return Vector2i(w.width / 2, w.base_height + 10)
