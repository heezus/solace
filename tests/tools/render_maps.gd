extends SceneTree
## Prints generated maps as ASCII, with how the generator fared on each (attempts, patches, faults).
## Run: godot --headless --path . -s tests/tools/render_maps.gd -- [first_seed] [last_seed] [stats]
## `stats` prints only the one-line summary per seed (for sweeping many seeds).

const MapGen = preload("res://scripts/map_gen.gd")
const MapgenTests = preload("res://tests/mapgen_tests.gd")
const World = preload("res://scripts/world.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 1
	var last := int(args[1]) if args.size() > 1 else first
	var quiet := "stats" in args
	var slow := 0
	var patched := 0
	var total_tries := 0
	for map_seed in range(first, last + 1):
		var w := World.new()
		var report := {}
		var t0 := Time.get_ticks_msec()
		MapGen.build(w, map_seed, report)
		slow = maxi(slow, Time.get_ticks_msec() - t0)
		total_tries += report["attempts"]
		patched += 1 if report["patched"] else 0
		print(summary(w, map_seed, report))
		if not quiet:
			print(MapgenTests.ascii(w))
	print(
		(
			"seeds %d to %d: %.2f attempts on average, %d patched, slowest %d ms"
			% [first, last, float(total_tries) / (last - first + 1), patched, slow]
		)
	)
	quit(0)


static func summary(w: World, map_seed: int, report: Dictionary) -> String:
	var counts := []
	for tile in ["tree", "rock", "berry", "grain", "flax", "gravel", "clay"]:
		counts.append("%s %d" % [tile, w.tiles.count(tile)])
	var land: Dictionary = report["terrain"]
	return (
		"map %d: camp %s, shard %s, up %s, %d rivers, attempts %d%s, faults %s | %s"
		% [
			map_seed,
			w.camp_pos,
			w.shard_pos,
			land["dir"],
			land["paths"].size(),
			report["attempts"],
			" PATCHED" if report["patched"] else "",
			report["faults"],
			", ".join(counts),
		]
	)
