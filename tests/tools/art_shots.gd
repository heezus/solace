extends SceneTree
## Looks at the painted Ironfall and Livewire art in the real map view: a kept Livewire start with a showcase laid on open ground
## (every painted building, Rail in each shape, a line of Firebreaks, a few tiles of young Bloom, carts), shot at 48 px a tile.
## Run with a display: xvfb-run -a godot --path . -s tests/tools/art_shots.gd -- <livewire start .json> <output dir> [after|before]
## `before` skips what the old tree has no helper for, so the same fixture runs on main for a before/after pair.

const Data = preload("res://scripts/data.gd")
const Launch = preload("res://scripts/launch.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Sim = preload("res://scripts/sim.gd")
const CutscenePlayer = preload("res://scripts/cutscene_player.gd")

const SHOW := [
	"boiler",
	"shard_boiler",
	"forge",
	"steam_shed",
	"beast_pen",
	"shard_lamp",
	"generator",
	"wire_mill",
	"power_pole",
	"order_board",
	"arc_lamp",
	"scorcher",
	"factory_floor",
	"shard_dynamo",
]

var main: Node
var out := ""
var frames := 0
var spot := Vector2i.ZERO


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	CutscenePlayer.suppress = true
	var s := Sim.new()
	RunSave.restore(s, RunSave.from_json(FileAccess.get_file_as_string(args[0])))
	_lay(s)
	Launch.ask_stage(RunSave.dump(s))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1500, 900)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


## A showcase south-east of the Hearth: two rows of buildings, rail and Firebreaks below them.
func _lay(s: Sim) -> void:
	for id in Data.ITEMS:
		s.economy.add(id, 300)
	for tech in Data.TECHS:
		s.tech_tree.researched[tech] = true
	s.fog.reveal_all()
	spot = _open_ground(s)
	for i in SHOW.size():
		var p := spot + Vector2i((i % 7) * 2, (i / 7) * 2)
		s.world.set_tile(p, "grass")
		s.world.fields.erase(p)
		if not s.place(SHOW[i], p):
			print("could not place ", SHOW[i], " at ", p, ": ", s.town.placement_error(SHOW[i], p))
	var row := spot + Vector2i(0, 5)
	# Rail: a long straight, a corner, a T, a cross and an end.
	var rails := [
		[0, 0], [1, 0], [2, 0], [3, 0], [4, 0], [4, 1], [4, 2], [3, 2], [5, 2], [4, 3], [4, 4], [5, 4], [3, 4], [4, 5]
	]
	for r in rails:
		var p: Vector2i = row + Vector2i(r[0], r[1])
		s.world.set_tile(p, "grass")
		s.world.roads[p] = true
		s.world.set_road_tier(p, Data.RAIL_TIER)
	s.town.road_rev += 1
	# Firebreaks: a line, an L, a T.
	var breaks := [[8, 0], [9, 0], [10, 0], [11, 0], [11, 1], [11, 2], [10, 2], [9, 2], [10, 1], [8, 3], [8, 4], [8, 5]]
	for b in breaks:
		var p: Vector2i = row + Vector2i(b[0], b[1])
		s.world.set_tile(p, "grass")
		s.place("firebreak", p)
	# Young Bloom: a patch.
	s.tide.begin(s)
	for x in 4:
		for y in 3:
			var p: Vector2i = row + Vector2i(14 + x, y)
			s.world.set_tile(p, Data.TILE_BLOOM_TIDE)
			s.tide.grown[p] = true
	s.tide.rev += 1


## The corner of the first 24 by 14 tile window, nearest the Hearth, with no building or road in it.
func _open_ground(s: Sim) -> Vector2i:
	var best := Vector2i(2, 2)
	var best_d := 1.0e9
	for y in range(1, s.world.height - 14):
		for x in range(1, s.world.width - 24):
			var free := true
			for dy in 14:
				for dx in 24:
					var p := Vector2i(x + dx, y + dy)
					if s.town.building_at.has(p) or s.world.roads.has(p) or s.world.tile_at(p) == "river":
						free = false
						break
				if not free:
					break
			var d := Vector2(x + 12, y + 7).distance_to(Vector2(s.world.camp_pos))
			if free and d < best_d:
				best = Vector2i(x, y)
				best_d = d
	return best


## Three haulers with a hand cart, a Steam Cart and a beast cart, each with cargo in the bed (set on the running game, which
## hands carts out itself at load).
func _carts() -> void:
	var kinds := ["hand", "steam", "beast"]
	for i in kinds.size():
		var k: Dictionary = main.state.people.kith[i]
		k["pos"] = Vector2(spot.x + 1 + i * 2, spot.y + 3.2)
		k["path"] = []
		k["job"] = "idle"
		k["cart"] = true
		k["cart_kind"] = kinds[i]
		k["carry"] = {["wire", "steel_tools", "shard"][i]: 1}


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		_carts()
		main.paused = true
		main.zoom_step = 3
		main.cam = (Vector2(spot) + Vector2(10, 5.2)) * 48.0
	if frames == 30:
		var img := root.get_texture().get_image()
		var path := out.path_join("map-48px.png")
		img.save_png(path)
		print("Wrote ", path)
		main.zoom_step = 5
		main.cam = (Vector2(spot) + Vector2(10, 5.2)) * 48.0
	if frames == 60:
		root.get_texture().get_image().save_png(out.path_join("map-64px.png"))
		quit(0)
	return false
