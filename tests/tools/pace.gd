extends SceneTree
## Pacing report: the bot (tests/autoplay.gd) plays maps and prints when each tech came, with a trace
## of what held it up every minute. With `bronze` it plays on past Bronze Dawn to the first Bronze (the era's stage 1) and
## reports the minutes that took.
## With `star` it plays the whole era, on past the first Bronze to The Falling Star, and reports both spans.
## Run: godot --headless --path . -s tests/tools/pace.gd -- [map|all] [minutes] [quiet] [bronze|star]

const Autoplay = preload("res://tests/autoplay.gd")
const AutoplayBronze = preload("res://tests/autoplay_bronze.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var maps: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	if not args.is_empty() and args[0] != "all":
		maps = [int(args[0])]
	var minutes := float(args[1]) if args.size() > 1 else 30.0
	var quiet := "quiet" in args
	if "bronze" in args:
		_bronze(maps, minutes, quiet)
		return
	if "star" in args:
		_star(maps, minutes, quiet)
		return
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


## The era-2 report: minutes from Bronze Dawn to the first Bronze, per map.
func _bronze(maps: Array, minutes: float, quiet: bool) -> void:
	var spans: Array = []
	for m in maps:
		var bot := AutoplayBronze.new()
		bot.trace = not quiet
		var r: Dictionary = bot.play_bronze(m, minutes * 60.0)
		print(
			(
				"map %d: Bronze Dawn at %.1f min, first Bronze %s"
				% [
					m,
					r["seconds"] / 60.0,
					(
						"%.1f min later" % r["minutes"]
						if r["minutes"] >= 0.0
						else "never (stopped at %.1f min)" % [bot.clock / 60.0]
					)
				]
			)
		)
		spans.append(r["minutes"])
		if not quiet:
			for line in r["log"]:
				print("   ", line)
			print("   inv ", bot.s.economy.inv)
	var total := 0.0
	for x in spans:
		total += x
	print("era 2: average %.1f min, from %.1f to %.1f" % [total / spans.size(), spans.min(), spans.max()])
	quit(0)


## The whole era: minutes from Bronze Dawn to the first Bronze, and from the first Bronze to The Falling Star, per map.
func _star(maps: Array, minutes: float, quiet: bool) -> void:
	var firsts: Array = []
	var stars: Array = []
	for m in maps:
		var bot := AutoplayBronze.new()
		bot.trace = not quiet
		var r: Dictionary = bot.play_to_star(m, minutes * 60.0)
		print(
			(
				"map %d: Bronze Dawn at %.1f min, first Bronze %.1f min later, The Falling Star %s"
				% [
					m,
					r["seconds"] / 60.0,
					r["minutes"],
					(
						"%.1f min after that" % r["star_minutes"]
						if r["star_minutes"] >= 0.0
						else "never (stopped at %.1f min)" % [bot.clock / 60.0]
					)
				]
			)
		)
		firsts.append(r["minutes"])
		stars.append(r["star_minutes"])
		if not quiet:
			for line in r["log"]:
				print("   ", line)
			print("   inv ", bot.s.economy.inv)
	print(
		(
			"era 2: first Bronze %.1f min on average (%.1f to %.1f), the star %.1f min after it (%.1f to %.1f)"
			% [_mean(firsts), firsts.min(), firsts.max(), _mean(stars), stars.min(), stars.max()]
		)
	)
	quit(0)


func _mean(xs: Array) -> float:
	var total := 0.0
	for x in xs:
		total += x
	return total / xs.size()
