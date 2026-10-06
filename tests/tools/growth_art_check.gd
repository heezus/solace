extends SceneTree
## Slot/alpha/atlas contract for the imported growth kit; independent of gameplay schemas.

const Growth = preload("res://scripts/growth_art.gd")

var failures: Array[String] = []


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _initialize() -> void:
	for slot in Growth.REGIONS:
		var tex: AtlasTexture = Growth.named(slot)
		check(tex != null, "Slot resolves: " + slot)
		check(Rect2(Vector2.ZERO, tex.atlas.get_size()).encloses(tex.region), "Region inside source: " + slot)
		check(tex.filter_clip, "Atlas clipping enabled: " + slot)
		check(Growth.named(slot) == tex, "Stable cached slot: " + slot)
	check(Growth.house(1) != Growth.house(2) and Growth.house(2) != Growth.house(3), "Distinct house tiers")
	check(Growth.road_material(0) != Growth.road_material(1), "Distinct road materials")
	check(Growth.named("unknown") == null, "Unknown slots do not borrow an unrelated sprite")
	for source in [Growth.HOUSES, Growth.SCAFFOLD, Growth.HAND_CART]:
		var image: Image = source.get_image()
		check(image.get_pixel(0, 0).a < 0.01, "Transparent subject background")
	var scaffold: Image = Growth.SCAFFOLD.get_image()
	check(scaffold.get_pixel(720, 470).a < 0.01, "Scaffold has an open center")
	seed(1234)
	var expected := randi()
	seed(1234)
	for slot in Growth.REGIONS:
		Growth.named(slot)
	check(randi() == expected, "Visual slot resolution does not consume simulation RNG")
	var preview := Image.load_from_file("res://docs/art/growth-visuals/native-assets.png")
	check(
		preview != null and preview.get_size() == Vector2i(1080, 560), "Native review capture exists at expected scale"
	)
	var background := Color("263c38")
	for tier in range(3):
		var seam_x := 35 + tier * 350 + 48
		for x in [seam_x - 1, seam_x]:
			var c := preview.get_pixel(x, 418)
			check(
				Vector3(c.r, c.g, c.b).distance_to(Vector3(background.r, background.g, background.b)) > 0.05,
				"Road join has no empty tile seam"
			)
	print("Growth art: ", failures.size(), " failures; regions, transparency, tiers, cached slots, RNG, road seams")
	for failure in failures:
		print(failure)
	quit(0 if failures.is_empty() else 1)
