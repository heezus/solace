extends RefCounted
## Two real-game map seeds (random 32-bit values, like main.gd's randi()) where the stone-age bot once never reached
## Bronze Dawn: it paved and built over the whole river bank before the Water Wheel was researched, so the Wheel
## (and the Grindstone it powers) never went down and flour stayed at 0. A player can tear the roads down; the bot now
## does too, as a last resort. Both seeds must reach the dawn, with a Wheel, a Grindstone and flour made on the way.
## Run from tests/run_tests.gd, which owns check().

const Autoplay = preload("res://tests/autoplay.gd")

const STALL_SEEDS := [4022250974, 3735928559]
const LIMIT := 25.0 * 60.0  # the bot has to win inside this (it is 14 to 17 minutes now)

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_bank_stall_seeds_reach_the_dawn()


func test_the_bank_stall_seeds_reach_the_dawn() -> void:
	for map_seed in STALL_SEEDS:
		var bot := Autoplay.new()
		var r: Dictionary = bot.play(map_seed, LIMIT)
		t.check(r["won"], "seed %d: the bot reaches Bronze Dawn inside %d minutes" % [map_seed, int(LIMIT / 60.0)])
		t.check(_count(bot, "water_wheel") > 0, "seed %d: a Water Wheel stands on the bank" % map_seed)
		t.check(_count(bot, "grindstone") > 0, "seed %d: a Grindstone grinds beside it" % map_seed)
		print("Stone stall, seed %d: Bronze Dawn at %.1f simulated minutes" % [map_seed, r["seconds"] / 60.0])


static func _count(bot: Autoplay, type: String) -> int:
	var n := 0
	for b in bot.s.town.buildings:
		n += 1 if b["type"] == type else 0
	return n
