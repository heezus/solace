extends RefCounted
## The first ten minutes for a newcomer (tests/newcomer.gd): a player who only does what the Goals panel asks,
## in order, must not starve, and a player who does nothing must be warned about the food before anyone leaves.
## Found by the newcomer playtest of 2026-09-30: following the goals, food ran out at 2.5 minutes and the Kith left.
## It must also keep the Food from ever hitting zero, and a hut it placed by the Berry Bushes must bring back
## almost only berries (a hut works one resource). Run from tests/run_tests.gd, which owns check().

const Data = preload("res://scripts/data.gd")
const Newcomer = preload("res://tests/newcomer.gd")
const Sim = preload("res://scripts/sim.gd")

const MINUTES := 10.0
## The warning must come at least this long before the first departure (the food warning time, less a margin).
const LEAD := 100.0

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_goals_start_with_food()
	test_a_newcomer_following_the_goals_stays_fed()
	test_a_newcomer_who_clicks_only_one_berry_hut_stays_fed()
	test_a_newcomer_who_clicks_each_hut_once_is_carried_by_the_famine_fallback()
	test_a_clumsy_newcomer_with_far_berries_is_still_carried()
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


## Playtest 4's clumsy newcomer clicks each hut exactly once and never again, and ignores the warning. The famine
## fallback (idle Kith forage, scripts/forage.gd) keeps them fed: at most one run out of food, at least three
## of them stay, and once the warning has come the food recovers past it.
func test_a_newcomer_who_clicks_each_hut_once_is_carried_by_the_famine_fallback() -> void:
	for map_seed in [1, 4, 8]:
		var bot := _play("once", map_seed)
		t.check(bot.min_kith >= 3, "once, map %d: at least three Kith stay (least %d)" % [map_seed, bot.min_kith])
		t.check(bot.zeros == 0, "once, map %d: the food never ran out (%d times)" % [map_seed, bot.zeros])
		t.check(bot.min_food >= 10.0, "once, map %d: and never fell below 10 (%.1f)" % [map_seed, bot.min_food])
		t.check(bot.foraging_steps > 0, "once, map %d: idle Kith went foraging" % map_seed)
		t.check(not bot.s.economy.low, "once, map %d: and it ends with no warning up" % map_seed)


## The same clumsy player on a map whose berries are all 8 or more tiles from the Hearth: the walk is longer, so the
## rescue is slower, and the food must still never run out.
func test_a_clumsy_newcomer_with_far_berries_is_still_carried() -> void:
	for map_seed in [1, 4, 8]:
		var game := Sim.new()
		game.generate(map_seed)
		var camp := game.world.camp_pos
		var far := 0
		for y in game.world.height:
			for x in game.world.width:
				var p := Vector2i(x, y)
				if game.world.tile_at(p) == "berry":
					if Vector2(p).distance_to(Vector2(camp)) < 8.0:
						game.world.set_tile(p, "grass")
					else:
						far += 1
		game.pathing.build()
		game.fog.reveal_all()  # as if explored: the bushes are known
		var bot := Newcomer.new()
		bot.mode = "once"
		bot.attach(game)
		while bot.clock < MINUTES * 60.0:
			bot.step()
		print(
			(
				"Newcomer once, far berries (%d), map %d: %d Kith, least food %.1f"
				% [far, map_seed, game.people.kith.size(), bot.min_food]
			)
		)
		t.check(far > 0, "far map %d: there are berries 8 or more tiles away" % map_seed)
		t.check(bot.min_kith >= 3 and bot.zeros == 0, "far map %d: nobody left and the food never ran out" % map_seed)
		t.check(bot.min_food >= 10.0, "far map %d: least food %.1f" % [map_seed, bot.min_food])


## A player who never touches the mouse is fed by the idle Kith, so nobody leaves. With no bush in reach there is
## nothing to forage: then they do leave in the end, and the warning comes well before the first one goes.
func test_an_idle_player_is_warned_before_anyone_leaves() -> void:
	var bot := Newcomer.new()
	bot.idler = true
	bot.play(3, MINUTES * 60.0)
	t.check(bot.left == 0 and bot.min_food > 0.0, "the idle %s forage, so nobody leaves" % Data.PEOPLE["many"])
	t.check(bot.foraging_steps > 0 and bot.min_food >= 6.0, "and the food stays up (least %.1f)" % bot.min_food)
	var bare := Sim.new()
	bare.generate(3)
	var camp := bare.world.camp_pos
	for y in range(camp.y - Data.FORAGE_RADIUS - 2, camp.y + Data.FORAGE_RADIUS + 3):
		for x in range(camp.x - Data.FORAGE_RADIUS - 2, camp.x + Data.FORAGE_RADIUS + 3):
			if bare.world.tile_at(Vector2i(x, y)) == "berry":
				bare.world.set_tile(Vector2i(x, y), "grass")
	var starved := Newcomer.new()
	starved.idler = true
	starved.attach(bare)
	while starved.clock < MINUTES * 60.0:
		starved.step()
	t.check(
		starved.left_at >= 0.0,
		"with no bushes to forage the %s do leave in the end (at %.0f s)" % [Data.PEOPLE["many"], starved.left_at]
	)
	t.check(
		starved.left_at - starved.warned_at >= LEAD,
		"and the warning comes %.0f s before the first one goes" % (starved.left_at - starved.warned_at)
	)
	t.check(starved.warned_at >= 30.0, "not at the very start, while the pantry is full")
