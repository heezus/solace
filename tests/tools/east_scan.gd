extends SceneTree
## Scan many map seeds for the era-2 land: does a road from the Hearth reach the copper and the tin, and across how many
## river tiles? Prints the failing seeds and a summary. Map generation and growth only, no simulation.
## With the word `random` the seeds are 32-bit values like the game's own randi(), drawn from a generator seeded with
## `first`, instead of first, first + 1, ...
## Run: godot --headless --path . -s tests/tools/east_scan.gd -- [first] [count] [max_rivers] [all] [random]

const EastFairness = preload("res://tests/east_fairness.gd")
const MapEast = preload("res://scripts/map_east.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 1
	var count := int(args[1]) if args.size() > 1 else 300
	var max_rivers := int(args[2]) if args.size() > 2 else MapEast.MAX_CROSSINGS
	var failed := 0
	var worst := {"copper": 0, "tin": 0}
	var rocks := {"copper": 0, "tin": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = first
	for n in count:
		var map_seed := int(rng.randi()) if "random" in args else first + n
		var w := EastFairness.grown(map_seed)
		var r := EastFairness.report(w)
		var faults := EastFairness.faults(r, max_rivers)
		for ore in worst:
			worst[ore] = maxi(worst[ore], mini(r[ore]["rivers"], 99))
			rocks[ore] = maxi(rocks[ore], mini(r[ore]["rocks"], 99))
		if not faults.is_empty():
			failed += 1
			print("seed %d FAIL: %s (copper %s, tin %s)" % [map_seed, ", ".join(faults), r["copper"], r["tin"]])
		elif "all" in args:
			print("seed %d ok: copper %s tin %s" % [map_seed, r["copper"], r["tin"]])
	print("%d of %d seeds fail; worst river tiles: copper %d, tin %d" % [failed, count, worst["copper"], worst["tin"]])
	print("most rock tiles to cut through: copper %d, tin %d" % [rocks["copper"], rocks["tin"]])
	quit(0)
