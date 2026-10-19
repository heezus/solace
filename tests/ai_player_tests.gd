extends RefCounted
## The AI player's page and hands (tests/tools/ai_snapshot.gd, design-system/25-playtesting.md): the page shows what a person would
## see, the moves go through the game's own commands, and what the game would refuse comes back as a refusal.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Snapshot = preload("res://tests/tools/ai_snapshot.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_page_shows_the_town()
	test_moves_go_through_the_games_commands()
	test_a_move_the_game_refuses_comes_back()
	test_a_season_card_is_on_the_page_and_answered()


func _game() -> Sim:
	var game := Sim.new()
	game.generate(3)
	return game


func test_the_page_shows_the_town() -> void:
	var page := Snapshot.text(_game(), 1, ["Hello"], [])
	for part in [
		"DECISION 1",
		"Stone age",
		"GOAL (",
		"FOOD:",
		"KITH:",
		"STOCK:",
		"BUILDABLE",
		"MAP (",
		"LEGEND:",
		"THE GAME SAID: Hello",
		"MOVES:"
	]:
		t.check(page.contains(part), "the page has %s" % part)
	t.check(page.contains("hearth") or page.contains("= camp"), "and the Hearth on the map")


func test_moves_go_through_the_games_commands() -> void:
	var game := _game()
	var tree := _tile(game, "tree")
	var before: int = game.economy.inv.get("wood", 0)
	var refused := Snapshot.apply(game, [{"do": "gather", "x": tree.x, "y": tree.y, "times": 3}])
	t.check(
		refused.is_empty() and game.economy.inv.get("wood", 0) > before, "gathering by hand adds wood (%s)" % [refused]
	)
	t.check(Snapshot.wait_of([{"do": "wait", "seconds": 30}], 15.0) == 30.0, "a wait move sets the pause")
	t.check(
		Snapshot.wait_of([{"do": "gather", "x": 1, "y": 1}], 15.0) == 15.0, "and the default holds when none is sent"
	)


func test_a_move_the_game_refuses_comes_back() -> void:
	var game := _game()
	var refused := (
		Snapshot
		. apply(
			game,
			[
				{"do": "build", "type": "no_such_building", "x": 1, "y": 1},
				{"do": "research", "tech": "bronze_dawn"},
				{"do": "demolish", "x": 0, "y": 0},
				{"do": "season", "choice": 0},
				"nonsense",
				{"do": "dance"},
			]
		)
	)
	t.check(refused.size() == 6, "six bad moves, six refusals (%d)" % refused.size())
	t.check(game.tech_tree.researched.size() == 0, "and nothing was bought")


func test_a_season_card_is_on_the_page_and_answered() -> void:
	var game := _game()
	game.seasons.phase = "pending"
	game.seasons.kind = "lean"
	var page := Snapshot.text(game, 2, [], [])
	t.check(page.contains("CARD WAITING (season") and page.contains("Ration"), "a waiting season shows on the page")
	var refused := Snapshot.apply(game, [{"do": "season", "choice": 1}])
	t.check(refused.is_empty() and game.seasons.phase == "active" and game.seasons.answer == 1, "and an answer takes")


func _tile(game: Sim, kind: String) -> Vector2i:
	for y in game.world.height:
		for x in game.world.width:
			var p := Vector2i(x, y)
			if game.world.tile_at(p) == kind and game.fog.is_revealed(p):
				return p
	return Vector2i(-1, -1)
