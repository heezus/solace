extends RefCounted
## No silent gates (design-system/25-playtesting.md, "Fun playtest 1"): what stands in the way of a tech or a goal is said, a locked card
## says what it waits on, a refused research or line build says why.
## Registered by AiPlayerTests.run.

const Chain = preload("res://scripts/chain.gd")
const CardText = preload("res://scripts/card_text.gd")
const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Snapshot = preload("res://tests/tools/ai_snapshot.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_a_hidden_tech_names_the_good_it_waits_on()
	test_the_goal_and_the_locked_card_walk_back_the_chain()
	test_research_and_line_refusals_say_why()


func _fresh() -> Sim:
	var s := Sim.new()
	s.generate(3)
	return s


## A town that has learned and held everything on the way to Farming but Grain: the one thing out of view is Farming itself.
func _before_grain(s: Sim) -> void:
	for tech in ["gatherers_hut", "stone_axe", "masonry", "cordage", "fire", "knapping", "haulers", "pottery"]:
		s.tech_tree.researched[tech] = true
	for id in Data.ITEM_ORDER:
		s.economy.seen[id] = true
		s.economy.inv[id] = 200
	s.economy.seen.erase("grain")
	s.economy.inv["grain"] = 0


func test_a_hidden_tech_names_the_good_it_waits_on() -> void:
	var s := _fresh()
	_before_grain(s)
	var step := Chain.step(s, "farming")
	t.check(
		step.get("kind", "") == "unseen" and step["tech"] == "farming",
		"Farming waits on a good never held (%s)" % [step]
	)
	t.check(step["line"].contains("Grain"), "and the line names Grain: " + step.get("line", ""))
	t.check(
		Chain.note(s, "grindstone").begins_with("Grindstone needs "),
		"the Grindstone's note walks back: " + Chain.note(s, "grindstone")
	)
	s.economy.add("grain", 3)
	t.check(Chain.step(s, "farming").get("kind", "") != "unseen", "once Grain has been held it is no longer the gate")
	t.check(
		Chain.note(s, "farming") != "" or s.tech_tree.can_research("farming"), "and what is left is a price or nothing"
	)
	s.tech_tree.researched["farming"] = true
	t.check(Chain.note(s, "farming") == "", "a tech learned has no note")


func test_the_goal_and_the_locked_card_walk_back_the_chain() -> void:
	var s := _fresh()
	_before_grain(s)
	for g in Data.GOALS:
		if g["id"] == "grind":
			break
		s.story.goals_done[g["id"]] = true
	t.check(s.story.asked_building() == "grindstone", "the Grindstone goal asks for the Grindstone")
	t.check(CardText.shown(s, "grindstone"), "so its card shows though its tech is out of view")
	var goal: Dictionary = s.story.goal_list()[s.story.current_goal()]
	t.check(
		s.story.gate_note(s, goal).contains("Farming"), "and the goal line names Farming: " + s.story.gate_note(s, goal)
	)
	t.check(
		CardText.locked_reason("grindstone", 0.0, s).begins_with("Blocked by"), "the locked card says what blocks it"
	)
	t.check(Snapshot.text(s, 1, [], []).contains("IN THE WAY:"), "the AI page carries the same line")


func test_research_and_line_refusals_say_why() -> void:
	var s := _fresh()
	_before_grain(s)
	s.fog.reveal_all()
	var refused := Snapshot.apply(s, [{"do": "research", "tech": "farming"}])
	t.check(refused.size() == 1 and refused[0].contains("Grain"), "a refused research gives its reason: %s" % [refused])
	var gravel := Vector2i(-1, -1)
	for y in s.world.height:
		for x in s.world.width:
			if gravel.x < 0 and s.world.tile_at(Vector2i(x, y)) == "gravel":
				gravel = Vector2i(x, y)
	t.check(gravel.x >= 0, "the map has gravel")
	var report := CardText.line_report(s, "road", [gravel + Vector2i(0, 0)])
	t.check(
		report.contains("Stopped at") and report.contains("Riverbed Gravel"),
		"a line over gravel names the tile and the ground: " + report
	)
	var err := s.town.placement_error("road", gravel)
	t.check(err.contains("go around"), "and a road refusal says to go around: " + err)
	t.check(
		Data.BUILDINGS["water_wheel"]["desc"].begins_with("Needs: "),
		"a wheel's requirement is a Needs line, not a status"
	)
