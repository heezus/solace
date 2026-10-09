extends RefCounted
## Starfall stage 1 (design-system/16-starfall.md): the landing after the Falling Star, the strangers, the Glyph Wall and
## the first set of marks, trust, and the Lumen Camp. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const CardText = preload("res://scripts/card_text.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_nothing_happens_before_the_star_falls()
	test_the_star_lands_and_the_strangers_come()
	test_a_cairn_first_means_guests()
	test_the_wall_copies_marks_and_the_set_reads_only_all_at_once()
	test_context_grows_with_welcome_and_trust()
	test_the_camp_and_the_wall_open_with_the_story()
	test_the_strangers_stand_closer_as_trust_grows()
	test_the_starfall_has_its_own_goals()
	test_starfall_saves_and_old_saves_load()


## A town where the Falling Star just fell (the story moment, as the tech sets it off). `cairn` builds the Cairn first.
func _fallen(cairn := false) -> Sim:
	var s: Sim = t.fresh()
	s.story.cairn_before_landing = cairn
	s.story.record("star_falling")
	return s


## Run the clock `seconds` forward in whole seconds.
func _wait(s: Sim, seconds: float) -> void:
	for i in int(seconds):
		s.starfall.tick(1.0)


func _arrived(cairn := false) -> Sim:
	var s := _fallen(cairn)
	_wait(s, Data.LANDING_DELAY + Data.ARRIVAL_DELAY)
	return s


## A free, buildable tile near the Hearth for `type`.
func _spot(s: Sim, type: String) -> Vector2i:
	for r in range(2, 8):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var p: Vector2i = s.world.camp_pos + Vector2i(dx, dy)
				if (
					s.town.placement_error(type, p) == ""
					or (
						s.town.placement_error(type, p).begins_with("Not discovered")
						and Data.TILES[s.world.tile_at(p)]["buildable"]
						and not s.town.building_at.has(p)
					)
				):
					return p
	return Vector2i(-1, -1)


func _wall(s: Sim) -> void:
	s.town.add_building("glyph_wall", _spot(s, "glyph_wall"))


func _copy_all(s: Sim) -> void:
	_wall(s)
	_wait(s, Data.COPY_SECONDS * 3)


func _guess_right(s: Sim) -> void:
	for g in Data.GLYPH_SETS[1]["glyphs"]:
		while s.starfall.guesses.get(g, "") != Data.GLYPHS[g]["word"]:
			s.starfall.cycle_guess(g)


func test_nothing_happens_before_the_star_falls() -> void:
	var s: Sim = t.fresh()
	_wait(s, 600)
	t.check(s.starfall.stage == "", "no landing before the Falling Star")
	t.check(not s.story.events.has("star_landed"), "and no story moment")
	s.starfall.begin(true)
	s.starfall.begin(false)
	t.check(s.starfall.guests, "the first begin() counts; a second does nothing")


func test_the_star_lands_and_the_strangers_come() -> void:
	var s := _fallen()
	t.check(s.starfall.stage == "falling", "the Falling Star starts the silence")
	_wait(s, Data.LANDING_DELAY - 1)
	t.check(s.starfall.stage == "falling" and not s.story.events.has("star_landed"), "it is quiet first")
	_wait(s, 2)
	t.check(s.starfall.stage == "landed" and s.story.events.has("star_landed"), "then it comes down")
	t.check(s.events.has(Data.LANDED_LINE), "and the log says so")
	t.check(not s.starfall.arrived(), "the strangers are not here yet")
	_wait(s, Data.ARRIVAL_DELAY)
	t.check(s.starfall.arrived() and s.story.events.has("lumen_arrived"), "they walk out of the fog")
	t.check(s.events.has(Data.ARRIVED_WARY), "wary, with no Cairn raised first")
	t.check(s.starfall.trust == Data.TRUST_START_WARY, "and trust starts at nothing")


func test_a_cairn_first_means_guests() -> void:
	var s := _arrived(true)
	t.check(s.starfall.guests and s.events.has(Data.ARRIVED_GUESTS), "a Cairn raised first: they come as guests")
	t.check(s.starfall.trust == Data.TRUST_START_GUESTS, "with a little trust already")
	t.check(s.starfall.found_lines("g_star").size() == 2, "and the first marks come with more context")
	var wary := _arrived(false)
	t.check(wary.starfall.found_lines("g_star").size() == 1, "wary strangers say less")


func test_the_wall_copies_marks_and_the_set_reads_only_all_at_once() -> void:
	var s := _arrived()
	_wait(s, Data.COPY_SECONDS * 2)
	t.check(s.starfall.copied.is_empty(), "no Wall, nothing copied")
	_wall(s)
	_wait(s, Data.COPY_SECONDS)
	t.check(s.starfall.copied == ["g_star"], "a standing Wall copies one mark in time")
	t.check(s.starfall.cycle_guess("g_come") == "", "a mark not on the Wall cannot be guessed")
	var word: String = s.starfall.cycle_guess("g_star")
	t.check(word == Data.GLYPH_WORDS[0], "a guess starts at the first word")
	_wait(s, Data.COPY_SECONDS * 2)
	t.check(s.starfall.copied.size() == 3 and s.starfall.progress("name") == Vector2i(3, 3), "all three get copied")
	# Two right and one wrong: nothing locks, nothing is said.
	for g in ["g_star", "g_come"]:
		while s.starfall.guesses.get(g, "") != Data.GLYPHS[g]["word"]:
			s.starfall.cycle_guess(g)
	s.starfall.guesses["g_kin"] = "Fire"
	t.check(not s.starfall.check() and s.starfall.locked.is_empty(), "two of three right locks nothing")
	_wait(s, Data.CHECK_SECONDS * 2)
	t.check(not s.story.events.has("name_read"), "and the story waits")
	_guess_right(s)
	var before := s.starfall.trust
	_wait(s, Data.CHECK_SECONDS)
	t.check(s.starfall.locked.has("name"), "all three right at a check reads the set")
	t.check(s.story.events.has("name_read"), "the name is a story moment")
	t.check(s.starfall.people_word() == Data.LUMEN_NAME, "the strangers have a name now")
	t.check(s.events.has(Data.LEAD_NAMED_LINE % [Data.LEAD_NAME, Data.LEAD_NAME]), "and the tall one gives hers")
	t.check(s.starfall.trust >= before + Data.TRUST_SET - 0.001, "and trust goes up")
	t.check(s.starfall.cycle_guess("g_star") == "", "a read set can't be guessed again")


func test_context_grows_with_welcome_and_trust() -> void:
	var s := _arrived()
	t.check(s.starfall.found_lines("g_come").size() == 1, "wary and low trust: one line")
	s.starfall.nudge(Data.CONTEXT_TRUST)
	t.check(s.starfall.found_lines("g_come").size() == 2, "trust adds a line")
	s.starfall.nudge(-1000.0)
	t.check(s.starfall.trust == 0.0, "trust never goes below nothing")
	s.starfall.nudge(1000.0)
	t.check(s.starfall.trust == Data.TRUST_MAX, "or above its top")


func test_the_camp_and_the_wall_open_with_the_story() -> void:
	var s: Sim = t.fresh()
	for id in Data.ITEM_ORDER:
		s.economy.seen[id] = true
	t.give(s, 999)
	t.check(not CardText.shown(s, "glyph_wall") and not CardText.shown(s, "lumen_camp"), "hidden at the start")
	var spot := _spot(s, "glyph_wall")
	t.check(s.town.placement_error("glyph_wall", spot) == "Not discovered yet", "and not placeable")
	s.story.record("lumen_arrived")
	t.check(CardText.shown(s, "glyph_wall") and not CardText.shown(s, "lumen_camp"), "the Wall opens when they arrive")
	t.check(s.place("glyph_wall", spot), "and can be built")
	s.story.record("name_read")
	t.check(CardText.shown(s, "lumen_camp"), "the Camp opens when the name is read")
	var wary := _arrived()
	var before := wary.starfall.trust
	wary.town.add_building("lumen_camp", _spot(wary, "lumen_camp"))
	_wait(wary, 1)
	t.check(wary.starfall.trust >= before + Data.TRUST_CAMP, "a Camp is a step of trust")
	t.check(wary.events.has(Data.CAMP_BUILT_LINE), "and the strangers notice it")
	var after := wary.starfall.trust
	_wait(wary, 60)
	t.check(wary.starfall.trust > after, "and a little more while it stands")


func test_the_strangers_stand_closer_as_trust_grows() -> void:
	var s := _arrived()
	var hearth := s.world.camp_pos
	var far: Array = s.starfall.survivor_spots(hearth, Vector2i(-1, -1))
	s.starfall.nudge(Data.TRUST_MAX)
	var near: Array = s.starfall.survivor_spots(hearth, Vector2i(-1, -1))
	var centre := Vector2(hearth) + Vector2(0.5, 0.5)
	t.check(far.size() == Data.SURVIVORS and near.size() == Data.SURVIVORS, "three strangers")
	t.check(far[0].distance_to(centre) > near[0].distance_to(centre) + 1.0, "they come closer as they trust the Kith")
	var camp := Vector2i(hearth.x + 4, hearth.y)
	var home: Array = s.starfall.survivor_spots(hearth, camp)
	t.check(home[0].distance_to(Vector2(camp) + Vector2(0.5, 0.5)) < 2.0, "and gather at a Lumen Camp once one stands")


func test_the_starfall_has_its_own_goals() -> void:
	var before: Sim = t.fresh()
	t.check(before.story.goal_list() != Data.GOALS_ERA3, "before the star falls the Starfall goals are not in force")
	var s := _fallen()
	t.check(s.story.goal_list() == Data.GOALS_ERA3, "once the star falls the Starfall goals are")
	t.check(Data.GOALS_ERA3.size() == 9, "nine of them")
	var seen := {}
	for g in Data.GOALS_ERA3:
		t.check(g["text"] != "" and not seen.has(g["id"]), "%s: a goal with words and its own id" % g["id"])
		seen[g["id"]] = true
		t.check(
			Data.GOALS_ERA2.filter(func(e): return e["id"] == g["id"]).is_empty(), "%s is not a dawn goal" % g["id"]
		)
	s.story.update(s)
	t.check(s.story.done_count() == 0 and s.story.current_goal() == 0, "none is met yet")
	_wait(s, Data.LANDING_DELAY + Data.ARRIVAL_DELAY)
	s.story.update(s)
	t.check(
		s.story.goals_done.has("strangers_come") and s.story.current_goal() == 1, "the strangers coming ticks the first"
	)
	s.starfall.locked[Data.GLYPH_SETS[1]["id"]] = true
	s.starfall.wreck_found = true
	s.story.update(s)
	t.check(
		s.story.goals_done.has("first_set") and s.story.goals_done.has("wreck_found"), "reading and finding tick theirs"
	)
	t.check(not s.story.goals_done.has("five_sets") and not s.story.goals_done.has("warning_read"), "later ones wait")
	var late := _fallen()
	late.starfall.ended = true
	late.starfall.pending = "ending"  # the Warning is read and the card waits: the era's list is still in force
	late.story.update(late)
	t.check(late.story.goals_done.has("warning_read"), "the Warning read ticks the last")
	# the Ironfall goals: coal in hand counts as found, whatever the fog says
	var iron := _fallen()
	iron.story.record(Data.IRONFALL_EVENT)
	iron.story.update(iron)
	t.check(not iron.story.goals_done.has("find_coal"), "no coal seen, none in the stores: not found")
	iron.economy.add("coal", 5)
	iron.story.update(iron)
	t.check(iron.story.goals_done.has("find_coal"), "coal already in the stores counts as found")


func test_starfall_saves_and_old_saves_load() -> void:
	var s := _arrived(true)
	_copy_all(s)
	s.starfall.cycle_guess("g_star")
	s.starfall.nudge(7.0)
	var d := RunSave.dump(s)
	var s2 := Sim.new()
	t.check(RunSave.restore(s2, RunSave.from_json(RunSave.to_json(d))), "a save with the era loads")
	t.check(s2.starfall.to_dict() == s.starfall.to_dict(), "and the era reads back the same")
	var old := RunSave.dump(s)
	old["game"].erase("starfall")
	var s3 := Sim.new()
	t.check(
		RunSave.restore(s3, old) and s3.starfall.stage == "", "a save from before the era loads as one with no landing"
	)
