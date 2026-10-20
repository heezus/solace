extends SceneTree
## Era art preserves discovery/fog privacy, incremental masks, tile/save data and simulation RNG.

const Sim = preload("res://scripts/sim.gd")
const Ground = preload("res://scripts/world_ground.gd")
const Save = preload("res://scripts/run_save.gd")
const Data = preload("res://scripts/data.gd")

var failures: Array[String] = []


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func region(ground, s, p: Vector2i) -> Color:
	return ground._image.get_pixelv((p + Vector2i(s.world.width, 0)) * Ground.SAMPLES + Vector2i(8, 8))


func _initialize() -> void:
	var s := Sim.new()
	s.generate(3)
	s.world.grow_south()
	s.fog.lengthen(s.world.height)
	s.fog.reveal_all()
	var p := Vector2i(8, 8)
	s.world.set_tile(p, "coal_seam")
	var ground := Ground.new()
	ground._rebuild(s)
	check(region(ground, s, p).r == 0.0, "Unidentified ore has no revealing resource apron")
	s.tech_tree.researched["coal_seams"] = true
	ground._rebuild(s)
	check(region(ground, s, p).r > 0.85, "Known resource gets a centered dark apron")
	check(Ground.era_family(s) == 0, "Stone family")
	for milestone in ["bronze_dawn", "star_falling", Data.IRONFALL_EVENT, Data.LIVEWIRE_BEGUN]:
		s.story.events.append(milestone)
		var expected: int = {"bronze_dawn": 2, "star_falling": 1, Data.IRONFALL_EVENT: 3, Data.LIVEWIRE_BEGUN: 4}[milestone]
		check(Ground.era_family(s) == expected, "Existing milestone selects " + milestone)
	var bloom := Vector2i(10, 8)
	s.world.set_tile(bloom, Data.BLOOM_GROUND)
	ground._rebuild(s)
	check(region(ground, s, bloom).g > 0.85, "Existing Bloom ID paints ground")
	s.tide.burnt[bloom] = true
	s.tide.rev += 1
	ground._rebuild(s)
	check(region(ground, s, bloom).b > 0.85, "Existing burnt state paints firebreak")
	var full := Ground.new()
	full._rebuild(s)
	check(ground._image.get_data() == full._image.get_data(), "Incremental era masks equal fresh masks")
	var saved := Save.dump(s).duplicate(true)
	seed(451)
	var expected_random := randi()
	seed(451)
	ground._rebuild(s)
	var decals := ground.era_decal_layout(s, Rect2i(0, 0, s.world.width, s.world.height))
	check(decals == ground.era_decal_layout(s, Rect2i(0, 0, s.world.width, s.world.height)), "Stable era scatter")
	check(randi() == expected_random, "Era art preserves simulation RNG")
	check(saved == Save.dump(s), "Era art preserves saves and tile IDs")
	s.fog.setup(s.world.width, s.world.height)
	ground._rebuild(s)
	var hidden := ground._image.get_data()
	s.world.set_tile(p, "iron_hills")
	s.world.set_tile(bloom, "bloom_sap")
	s.tide.burnt.clear()
	s.tide.grown[p] = true
	ground._rebuild(s)
	check(hidden == ground._image.get_data(), "Hidden ore/Bloom/burnt state cannot alter masks")
	check(ground.era_decal_layout(s, Rect2i(0, 0, s.world.width, s.world.height)).is_empty(), "Fog hides era decals")
	var shader := FileAccess.get_file_as_string("res://art/rendered/terrain.gdshader")
	check(shader.count("uniform sampler2D") <= 8, "Era art retains Compatibility sampler budget")
	for message in failures:
		printerr(message)
	print("Era ground checks: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
