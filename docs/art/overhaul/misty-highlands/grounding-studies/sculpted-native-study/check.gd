extends SceneTree
const Ground = preload(
	"res://docs/art/overhaul/misty-highlands/grounding-studies/sculpted-native-study/study-ground.gd"
)
const Art = preload("res://docs/art/overhaul/misty-highlands/grounding-studies/sculpted-native-study/study-art.gd")
const World = preload("res://scripts/world.gd")
const Fog = preload("res://scripts/fog.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("STUDY CHECK: ", message)


func _init() -> void:
	var world := World.new(5, 5)
	var fog := Fog.new()
	fog.setup(5, 5)
	var s := {"world": world, "fog": fog, "town": {"building_at": {}, "buildings": []}, "tech_tree": {"researched": {}}}
	var ground := Ground.new()
	var seen := Rect2i(0, 0, 5, 5)
	world.set_tile(Vector2i(2, 2), "river")
	check(ground._shore_parts(s, seen).is_empty(), "hidden river leaks decoration")
	fog.cells[2 * 5 + 2] = 1
	check(ground._shore_parts(s, seen).is_empty(), "unknown land gets decoration")
	fog.reveal_all()
	var before := world.to_dict()
	seed(381)
	var expected := randi()
	seed(381)
	var parts := ground._shore_parts(s, seen)
	check(not parts.is_empty(), "visible shore lacks detail")
	check(parts == ground._shore_parts(s, seen), "decoration changes on redraw")
	ground._rebuild(s)
	check(randi() == expected and world.to_dict() == before, "rendering changes world or RNG")
	var sizes := {}
	for part in parts:
		sizes[part.size] = true
		var tex := Art.sprite("riverbank-details", part.index)
		check(Rect2(Vector2.ZERO, tex.atlas.get_size()).encloses(tex.region), "atlas exceeds source")
	check(sizes.size() > 1, "shore clusters have uniform size")
	world.roads = {Vector2i(2, 1): true}
	s.town.building_at[Vector2i(1, 1)] = 0
	var a := ground._road_center(Vector2i(2, 1), 0)
	var b := ground._road_center(Vector2i(1, 1), 0)
	var point := a.lerp(b, (a.x - 2.0) / (a.x - b.x))
	check(
		ground._road(s, point - Vector2(0.001, 0)) > 0.99 and ground._road(s, point + Vector2(0.001, 0)) > 0.99,
		"road clips at destination cell"
	)
	s.town.building_at.clear()
	world.set_tile(Vector2i(3, 3), "rock")
	ground._rebuild(s)
	var pixel := Vector2i(3, 3) * 16 + Vector2i(8, 14)
	check(ground._image.get_pixelv(pixel).a > 0.8, "rock contact is missing")
	world.set_tile(Vector2i(3, 3), "grass")
	ground._rebuild(s)
	check(ground._image.get_pixelv(pixel).a == 0, "cleared rock keeps contact")
	print("Isolated native terrain checks: ", failures, " failures")
	quit(1 if failures else 0)
