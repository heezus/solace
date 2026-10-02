extends SceneTree
## Scan random 32-bit map seeds with the stone-age bot and say why any of them never reach Bronze Dawn.
## Run: godot --headless --path . -s tests/tools/stone_scan.gd -- [first] [count] [minutes] [seed_stream]
## Seeds come from a fixed stream (seed_stream, default 20260927); `first` and `count` pick a slice of it.
## Prints one line per seed: seed, WON/STALL, seconds, then for a stall the cause and the bank picture.

const Autoplay = preload("res://tests/autoplay.gd")
const Sim = preload("res://scripts/sim.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 0
	var count := int(args[1]) if args.size() > 1 else 10
	var minutes := float(args[2]) if args.size() > 2 else 30.0
	var stream := int(args[3]) if args.size() > 3 else 20260927
	var rng := RandomNumberGenerator.new()
	rng.seed = stream
	var seeds: Array = []
	for i in first + count:
		seeds.append(rng.randi())
	for i in range(first, first + count):
		_one(seeds[i], minutes * 60.0)
	quit(0)


func _one(map_seed: int, limit: float) -> void:
	var game := Sim.new()
	game.generate(map_seed)
	var bot := Autoplay.new()
	bot.attach(game)
	while bot.clock < limit and not bot.s.won:
		bot.step(true)
	if bot.s.won:
		print("%d WON %.0f" % [map_seed, bot.clock])
		return
	print("%d STALL %.0f %s" % [map_seed, bot.clock, cause(bot)])


## Why the run stalled: the tech it waits on and, for the Water Wheel, what the bank looks like.
static func cause(bot: Autoplay) -> String:
	var s: Sim = bot.s
	var next: String = s.tech_tree.queue[0] if not s.tech_tree.queue.is_empty() else "none"
	bot.reach = {}
	bot._flood_reach()
	var bank := {"reach": 0, "free": 0, "roads": 0, "buildings": 0}
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			if s.world.tile_at(p) != "grass" or not s.world.touches_river(p) or not bot.reach.has(p):
				continue
			bank["reach"] += 1
			if s.world.roads.has(p):
				bank["roads"] += 1
			elif s.town.building_at.has(p):
				bank["buildings"] += 1
			elif s.town.placement_error("water_wheel", p) == "":
				bank["free"] += 1
	var kind := "other"
	if next in ["water_wheel", "grindstone"] or s.tech_tree.researched.has("water_wheel"):
		if bot._count("water_wheel") == 0:
			kind = "wheel_unplaced"
		elif bot._count("grindstone") == 0:
			kind = "grindstone_unplaced"
	print("   bank ", bank)
	return "%s next=%s wheels=%d grind=%d" % [kind, next, bot._count("water_wheel"), bot._count("grindstone")]
