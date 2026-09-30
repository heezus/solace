extends RefCounted
## The first ten minutes for a newcomer (tests/newcomer.gd): a player who only does what the Goals panel asks,
## in order, must not starve, and a player who does nothing must be warned about the food before anyone leaves.
## Found by the newcomer playtest of 2026-09-30: following the goals, food ran out at 2.5 minutes and the Kith left.
## Run from tests/run_tests.gd, which owns check().

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
		var bot := Newcomer.new()
		bot.play(map_seed, MINUTES * 60.0)
		var goals: int = bot.s.story.current_goal()
		print(
			(
				"Newcomer, map %d: %d Kith of %d after %.0f min, goal %d of %d, food %d, warned at %.0f s"
				% [
					map_seed,
					bot.s.people.kith.size(),
					Data.KITH_START,
					bot.clock / 60.0,
					goals,
					Data.GOALS.size(),
					int(bot.s.economy.food_total()),
					bot.warned_at
				]
			)
		)
		t.check(
			bot.left == 0 and bot.min_kith >= Data.KITH_START,
			"map %d: every %s stays for %d minutes" % [map_seed, Data.PEOPLE["one"], int(MINUTES)]
		)
		t.check(goals >= 10, "map %d: the newcomer got through the opening goals (%d done)" % [map_seed, goals])
		t.check(bot.s.story.goals_done.has("berries"), "map %d: and placed a hut by the Berry Bushes" % map_seed)
		if bot.warned_at >= 0.0:
			t.check(bot.left_at < 0.0 or bot.warned_at < bot.left_at, "map %d: the food warning came first" % map_seed)


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
