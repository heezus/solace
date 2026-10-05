extends RefCounted
## Visual variation and terrain caching must preserve gameplay state, RNG and hidden terrain.

const Rendered = preload("res://scripts/rendered_art.gd")
const Ground = preload("res://scripts/world_ground.gd")
const World = preload("res://scripts/world.gd")
const Fog = preload("res://scripts/fog.gd")


func run(t) -> void:
	var choices := {}
	for y in 12:
		for x in 18:
			var p := Vector2i(x, y)
			var choice := Rendered.variant(p, 4, 17, 7)
			choices[choice] = true
			t.check(choice == Rendered.variant(p, 4, 17, 7), "a tile keeps its appearance on redraw")
			t.check(choice >= 0 and choice < 4, "a variant stays inside the atlas family")
	t.check(choices.size() == 4, "map variation uses every tree rather than the default")
	for family in Rendered.REGIONS:
		for i in Rendered.REGIONS[family].size():
			var tex := Rendered.sprite(family, i)
			t.check(tex.atlas != null and tex.filter_clip, "atlas exists and prevents neighboring sprite bleed")
			t.check(
				Rect2(Vector2.ZERO, tex.atlas.get_size()).encloses(tex.region), "atlas region stays inside its source"
			)
	var world := World.new(6, 5)
	var fog := Fog.new()
	fog.setup(6, 5)
	var s := {"world": world, "fog": fog, "town": {"building_at": {}}, "tech_tree": {"researched": {}}}
	var ground := Ground.new()
	ground._rebuild(s)
	var before := world.to_dict()
	var first := ground._image.get_data()
	var count := ground.builds
	ground._rebuild(s)
	t.check(ground.builds == count, "unchanged terrain is reused rather than rebuilt")
	world.set_tile(Vector2i(2, 2), "river")
	ground._rebuild(s)
	t.check(ground._image.get_data() == first, "hidden rivers do not leak through neighboring ground")
	fog.reveal_all()
	ground._rebuild(s)
	t.check(ground._image.get_data() != first, "revealing a river refreshes its connected banks")
	world.roads[Vector2i(1, 1)] = true
	count = ground.builds
	ground._rebuild(s)
	t.check(ground.builds == count + 1, "a placed road refreshes terrain")
	world.set_tile(Vector2i(2, 2), "grass")
	world.roads.clear()
	t.check(world.to_dict() == before, "rendering does not mutate world state")
	seed(713)
	var expected := randi()
	seed(713)
	Rendered.variant(Vector2i(4, 6), 3, 81, 7)
	ground._rebuild(s)
	t.check(randi() == expected, "art variation and terrain generation leave simulation RNG untouched")
