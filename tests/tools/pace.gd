extends SceneTree
## Pacing report: the bot (tests/autoplay.gd) plays maps and prints when each tech came, with a trace
## of what held it up every minute. Run: godot --headless --path . -s tests/tools/pace.gd -- [map|all] [minutes] [quiet]

const Autoplay = preload("res://tests/autoplay.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var maps: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	if not args.is_empty() and args[0] != "all":
		maps = [int(args[0])]
	var minutes := float(args[1]) if args.size() > 1 else 30.0
	var quiet := "quiet" in args
	var times: Array = []
	for m in maps:
		var bot := Autoplay.new()
		bot.trace = not quiet
		var r: Dictionary = bot.play(m, minutes * 60.0)
		times.append(r["seconds"] / 60.0)
		print("map %d: %s at %.1f min" % [m, "WON" if r["won"] else "not won", r["seconds"] / 60.0])
		if not quiet:
			for line in r["log"]:
				print("   ", line)
			print("   inv ", bot.s.economy.inv)
			print("   ranks ", bot.s.ranks, " kith %d" % bot.s.people.kith.size())
			var counts := {}
			for b in bot.s.town.buildings:
				var key: String = (
					b["type"] + ("/" + "+".join(b["gather_items"]) if b["type"] == "gatherers_hut" else "")
				)
				counts[key] = counts.get(key, 0) + 1
			print("   buildings ", counts)
	var total := 0.0
	for x in times:
		total += x
	print("average %.1f min, from %.1f to %.1f" % [total / times.size(), times.min(), times.max()])
	quit(0)
