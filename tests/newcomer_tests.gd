extends RefCounted
## The first ten minutes for a newcomer (tests/newcomer.gd): a player who only does what the Goals panel asks,
## in order, must not starve, and a player who does nothing must be warned about the food before anyone leaves.
## Found by the newcomer playtest of 2026-09-30: following the goals, food ran out at 2.5 minutes and the Kith left.
## It must also keep the Food from ever hitting zero, and a hut it placed by the Berry Bushes must bring back
## almost only berries (a hut works one resource). Run from tests/run_tests.gd, which owns check().

const Data = preload("res://scripts/data.gd")
const Newcomer = preload("res://tests/newcomer.gd")

const MINUTES := 10.0
## The warning must come at least this long before the first departure (the food warning time, less a margin).
const LEAD := 45.0

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_goals_start_with_food()
	test_a_newcomer_following_the_goals_stays_fed()
	test_a_newcomer_who_clicks_only_one_berry_hut_stays_fed()
	test_an_idle_player_is_warned_before_anyone_leaves()


## Food comes early in the Goals: the first Berry Bushes goal is among the first three, before any research.
func test_the_goals_start_with_food() -> void:
	var ids: Array = Data.GOALS.map(func(g): return g["id"])
	t.check(
		ids.find("learn_berries") >= 0 and ids.find("learn_berries") <= 2, "hand-gathering berries is an early goal"
	)
	t.check(ids.find("learn_berries") < ids.find("knapping"), "it comes before the first research")
	t.check(ids.find("berries") > ids.find("hut"), "a hut by the Berry Bushes follows the first hut")
	var text: String = Data.GOALS[ids.find("learn_berries")]["text"]
	t.check(text.contains("eat"), "and it says that the %s eat them" % Data.PEOPLE["many"])


## The newcomer follows the goals for ten minutes: nobody leaves, and if the food ever ran low the warning came.
func test_a_newcomer_following_the_goals_stays_fed() -> void:
	for map_seed in [1, 4, 8]:
		var bot := _play("literal", map_seed)
		var goals: int = bot.s.story.current_goal()
		t.check(goals >= 10, "map %d: the newcomer got through the opening goals (%d done)" % [map_seed, goals])
		t.check(bot.s.story.goals_done.has("berries"), "map %d: and placed a hut by the Berry Bushes" % map_seed)
		_check_the_food_hut(bot, map_seed, _last_berry_hut(bot))


## Found by playtest 3: a player who puts up two huts by the bushes but clicks only the first, and does nothing else
## (the warning is ignored too), still keeps everyone fed. An unlinked hut only works when clicked, so this is the
## worst case the rules have to carry.
func test_a_newcomer_who_clicks_only_one_berry_hut_stays_fed() -> void:
	for map_seed in [1, 4, 8]:
		var bot := _play("one_hut", map_seed)
		var huts := 0
		for b in bot.s.town.buildings:
			huts += 1 if b["focus"] == "berries" else 0
		t.check(huts >= 2, "map %d: two huts work the Berry Bushes (%d)" % [map_seed, huts])
		_check_the_food_hut(bot, map_seed, _first_berry_hut(bot))


## Play one map for ten minutes with the bot in `mode`, and check that nobody left and the Food never hit zero.
func _play(mode: String, map_seed: int) -> Newcomer:
	var bot := Newcomer.new()
	bot.mode = mode
	bot.play(map_seed, MINUTES * 60.0)
	print(
		(
			"Newcomer %s, map %d: %d Kith of %d after %.0f min, goal %d of %d, food %d (least %.1f), %d trips, warned at %.0f s"
			% [
				mode,
				map_seed,
				bot.s.people.kith.size(),
				Data.KITH_START,
				bot.clock / 60.0,
				bot.s.story.current_goal(),
				Data.GOALS.size(),
				int(bot.s.economy.food_total()),
				bot.min_food,
				bot.trips_sent,
				bot.warned_at
			]
		)
	)
	t.check(
		bot.left == 0 and bot.min_kith >= Data.KITH_START,
		"%s, map %d: every %s stays for %d minutes" % [mode, map_seed, Data.PEOPLE["one"], int(MINUTES)]
	)
	t.check(bot.min_food > 0.0, "%s, map %d: the Food never hit zero (least %.1f)" % [mode, map_seed, bot.min_food])
	if bot.warned_at >= 0.0:
		t.check(
			bot.left_at < 0.0 or bot.warned_at < bot.left_at,
			"%s, map %d: the food warning came first" % [mode, map_seed]
		)
	return bot


func _first_berry_hut(bot) -> Vector2i:
	for b in bot.s.town.buildings:
		if b["focus"] == "berries":
			return b["pos"]
	return Vector2i(-1, -1)


func _last_berry_hut(bot) -> Vector2i:
	var hut := Vector2i(-1, -1)
	for b in bot.s.town.buildings:
		if b["focus"] == "berries":
			hut = b["pos"]
	return hut


## The hut the newcomer keeps clicking by the Berry Bushes worked berries and nothing else: over the whole run its
## worker brought out well over two minutes' worth of bundles, and every one was berries.
func _check_the_food_hut(bot, map_seed: int, hut: Vector2i) -> void:
	t.check(hut.x >= 0, "map %d: a hut is set to Berries" % map_seed)
	var got: Dictionary = bot.gathered.get(hut, {})
	var total := 0
	for id in got:
		total += got[id]
	var share := float(got.get("berries", 0)) / maxf(float(total), 1.0)
	print("  the berry hut brought out %s (%.0f%% berries)" % [got, share * 100.0])
	t.check(total >= 3 * Data.BUNDLE, "map %d: the berry hut brought out bundles (%d items)" % [map_seed, total])
	t.check(share >= 0.9, "map %d: and mostly berries (%.0f%%)" % [map_seed, share * 100.0])


## A player who never touches the mouse loses Kith in the end, but the warning comes well before the first one goes.
func test_an_idle_player_is_warned_before_anyone_leaves() -> void:
	var bot := Newcomer.new()
	bot.idler = true
	bot.play(3, MINUTES * 60.0)
	t.check(bot.warned_at >= 0.0, "an idle player is warned that the food is running low (at %.0f s)" % bot.warned_at)
	t.check(
		bot.left_at >= 0.0,
		"with nobody feeding them the %s do leave in the end (at %.0f s)" % [Data.PEOPLE["many"], bot.left_at]
	)
	t.check(
		bot.left_at - bot.warned_at >= LEAD,
		"and the warning comes %.0f s before the first one goes" % (bot.left_at - bot.warned_at)
	)
	t.check(bot.warned_at >= 60.0, "not in the first minute, while the pantry is full")
