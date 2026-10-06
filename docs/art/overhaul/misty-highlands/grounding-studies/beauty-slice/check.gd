extends SceneTree
const Slice = preload("res://docs/art/overhaul/misty-highlands/grounding-studies/beauty-slice/capture.gd")
const Ground = preload("res://docs/art/overhaul/misty-highlands/grounding-studies/beauty-slice/ground.gd")
const Patches = preload("res://docs/art/overhaul/misty-highlands/grounding-studies/beauty-slice/patches.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("BEAUTY CHECK: ", message)


func _init() -> void:
	var s := Slice.make_state()
	var before: Dictionary = s.world.to_dict()
	var fog_before: PackedByteArray = s.fog.cells.duplicate()
	var ground := Ground.new()
	ground.layered = true
	seed(79)
	var expected := randi()
	seed(79)
	var patches := ground._patch_parts(s)
	var families := {}
	check(patches == ground._patch_parts(s), "patches shuffle on redraw")
	for part in patches:
		families[part.index] = true
		var tex := Patches.sprite(part.index)
		check(Rect2(Vector2.ZERO, tex.atlas.get_size()).encloses(tex.region), "patch source exceeds atlas")
	check(families.size() == 6, "missing material layer family")
	var image := Patches.sprite(0).atlas.get_image()
	check(image.get_pixel(0, 0).a < 0.01, "generated atlas is not transparent")
	var hearth_contact := false
	for apron in ground._aprons(s, Vector2i(4, 6)):
		if apron.z > 0.9:
			hearth_contact = apron.x == 5.0 and absf(apron.y - 7.88) < 0.01
	check(hearth_contact, "Hearth wear is detached from bottom-anchored foundation")
	ground._rebuild(s)
	check(
		s.world.to_dict() == before and s.fog.cells == fog_before and randi() == expected, "study changes world/fog/RNG"
	)
	s.fog.cells.fill(0)
	check(ground._patch_parts(s).is_empty(), "hidden world leaks patches")
	var known := Vector2i(2, 2)
	s.fog.cells[known.y * s.world.width + known.x] = 1
	check(ground._patch_parts(s).is_empty(), "patch spills into unknown cells")
	print(
		"Beauty slice checks: ",
		failures,
		" failures; ",
		patches.size(),
		" contextual patches; ",
		families.size(),
		" families"
	)
	quit(1 if failures else 0)
