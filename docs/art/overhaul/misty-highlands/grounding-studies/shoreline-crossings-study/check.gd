extends SceneTree
const Fixture = preload(
	"res://docs/art/overhaul/misty-highlands/grounding-studies/shoreline-crossings-study/fixture.gd"
)
const Ground = preload(
	"res://docs/art/overhaul/misty-highlands/grounding-studies/shoreline-crossings-study/study-ground.gd"
)
const Bridge = preload(
	"res://docs/art/overhaul/misty-highlands/grounding-studies/shoreline-crossings-study/study-bridge.gd"
)
const Props = preload(
	"res://docs/art/overhaul/misty-highlands/grounding-studies/shoreline-crossings-study/study-props.gd"
)
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("SHORE CHECK: ", message)


func _init() -> void:
	var s := Fixture.make_state()
	var ground := Ground.new()
	var seen := Rect2i(0, 0, 24, 14)
	var before: Dictionary = s.world.to_dict()
	seed(731)
	var expected := randi()
	seed(731)
	var parts := ground._shore_parts(s, seen)
	check(parts == ground._shore_parts(s, seen), "redraw changes bank decoration")
	var normals := {}
	var families := {}
	for part in parts:
		normals[part.normal] = true
		families[part.index] = true
		check(not ground._clearance(s, part.at), "decoration blocks bridge access")
		var wet := ground._river(s, part.at / 48.0)
		check(wet <= 0.41 and wet >= 0.1, "prop loses contact with shoreline")
		var tex := Props.sprite(part.index)
		check(Rect2(Vector2.ZERO, tex.atlas.get_size()).encloses(tex.region), "prop source exceeds atlas")
	check(normals.size() == 4, "fixture does not cover all bank normals")
	check(families.size() >= 7, "bank family variety is missing")
	for crossing in [Vector2i(5, 3), Vector2i(8, 11), Vector2i(17, 4), Vector2i(21, 4)]:
		var span := Bridge.Bridge.span(s, crossing)
		var start := Vector2(span.anchor) * 48
		var total := Rect2()
		var vertical: bool = span.axis == Vector2i.DOWN
		for i in span.length:
			var p: Vector2i = span.anchor + span.axis * i
			var modules := Bridge.modules(s, p)
			for module in modules:
				var box: Rect2 = module.box
				total = box if not total.has_area() else total.merge(box)
				check(
					Rect2(Vector2.ZERO, module.texture.atlas.get_size()).encloses(module.source),
					"bridge source exceeds atlas"
				)
			if i > 0:
				var previous := Bridge.modules(s, p - span.axis)
				var last: Rect2 = previous[-1].box
				var first: Rect2 = modules[0].box
				check(
					first.position.y <= last.end.y if vertical else first.position.x <= last.end.x,
					"deck geometry has a gap"
				)
		var low := total.position.y - start.y if vertical else total.position.x - start.x
		var high := total.end.y - start.y if vertical else total.end.x - start.x
		check(low == -Bridge.SEAT and high == span.length * 48 + Bridge.SEAT, "bridge does not seat on both dry banks")
		for end in [span.anchor - span.axis, span.anchor + span.axis * span.length]:
			check(ground._approach_center(s, end) == Vector2(end) + Vector2.ONE * 0.5, "road misses bridge centerline")
	ground._rebuild(s)
	check(s.world.to_dict() == before and randi() == expected, "drawing changes world or simulation RNG")
	s.fog.cells.fill(0)
	check(ground._shore_parts(s, seen).is_empty(), "hidden bank leaks props")
	var water := Vector2i(5, 1)
	s.fog.cells[water.y * s.world.width + water.x] = 1
	check(ground._shore_parts(s, seen).is_empty(), "unrevealed land leaks props")
	var modules := Bridge.modules(s, Vector2i(5, 3))
	check(modules[0].box.position.x == 5 * 48, "hidden bank leaks extended bridge seat")
	print(
		"Shoreline/crossing checks: ", failures, " failures; ", parts.size(), " props; ", families.size(), " variants"
	)
	quit(1 if failures else 0)
