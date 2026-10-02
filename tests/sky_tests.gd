extends RefCounted
## Era 2's sky: Sky Watch names the Wanderer, a Watchtower sees far and logs sightings, Star Charts draws the path, the
## Falling Star ends the era (a story moment kept in the profile, a card, and a game that goes on). Run from
## tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const Rules = preload("res://scripts/rules.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Profile = preload("res://scripts/profile.gd")
const Monitor = preload("res://tests/monitor.gd")
const SkyView = preload("res://scripts/sky_view.gd")
const EraCard = preload("res://scripts/era_card.gd")
const Art = preload("res://scripts/art.gd")
const Stage2Tests = preload("res://tests/stage2_tests.gd")

const TEMP_PROFILE := "user://solace_test_sky_profile.json"

var t  # the runner, tests/run_tests.gd
var helper := Stage2Tests.new()  # for game() and spot()


func run(runner) -> void:
	t = runner
	helper.t = runner
	test_sky_is_unseen_before_sky_watch()
	test_a_watchtower_sees_far()
	test_a_watchtower_logs_sightings()
	test_the_wanderer_comes_nearer_with_each_tech()
	test_star_charts_and_the_view()
	test_the_sky_saves()
	test_the_falling_star_ends_the_era()
	test_the_ending_goes_in_the_profile()
	test_the_era_card()
	test_the_cairn_glows()


func _have_all(s: Sim, ids: Array) -> void:
	for id in ids:
		s.tech_tree.researched[id] = true


func test_sky_is_unseen_before_sky_watch() -> void:
	var s := helper.game([])
	t.check(not s.sky.named() and not s.sky.charted(), "the light has no name yet")
	t.check(s.sky.approach() == 0.0, "and counts for nothing")
	t.check(not s.sky.watched(), "no tower stands")
	var m := Monitor.new()
	m.watch(s.sky, "sighted")
	for i in 3000:
		s.tick(0.1)
	t.check(m.count("sighted") == 0, "so no sightings in 300 s")
	t.check(s.sky.to_dict() == {"sightings": 0, "clock": 0.0}, "and the clock never ran")


func test_a_watchtower_sees_far() -> void:
	var a := Sim.new()
	a.generate(42)
	var b := Sim.new()
	b.generate(42)
	for s in [a, b]:
		t.give(s, 999)
	var at: Vector2i = helper.spot(a, 0)
	t.check(t.place_free(a, "watchtower", at), "a Watchtower")
	t.check(t.place_free(b, "standing_stone", at), "or a Standing Stone in the same place")
	t.check(
		a.fog.count() > b.fog.count() + 40, "the tower lifts far more fog (%d vs %d)" % [a.fog.count(), b.fog.count()]
	)
	t.check(Data.BUILDINGS["watchtower"]["tech"] == "sky_watch", "the Watchtower comes with Sky Watch")
	t.check(Data.BUILDINGS["watchtower"]["sight"] > Data.SIGHT_START, "it sees farther than the Hearth does")


func test_a_watchtower_logs_sightings() -> void:
	var s := helper.game(["sky_watch"])
	var m := Monitor.new()
	m.watch(s.sky, "sighted")
	for i in 1800:
		s.tick(0.1)
	t.check(m.count("sighted") == 0, "with no tower the Kith watch from the ground and log nothing")
	t.check(t.place_free(s, "watchtower", helper.spot(s, 0)), "a Watchtower")
	t.check(s.sky.watched(), "now someone watches")
	for i in int(Data.SIGHTING_SECONDS * 10.0 * 2.0) + 20:
		s.tick(0.1)
	t.check(m.count("sighted") == 2, "two sightings in two periods (%d)" % m.count("sighted"))
	t.check(Data.WANDERER_SIGHTINGS[0].has(m.args_of("sighted")[0][0]), "the first is a hopeful one")
	t.check(s.sky.sightings == 2, "and the Kith count them")
	var logged := s.events.filter(func(e): return Data.WANDERER_SIGHTINGS[0].has(e))
	t.check(logged.size() == 2, "each goes to the event log")
	# The Kith are less easy about it as it gets close.
	_have_all(s, Rules.era_techs(2))
	t.check(s.sky.mood() == Data.WANDERER_SIGHTINGS.size() - 1, "the last mood is the frightened one")
	var n := m.count("sighted")
	for i in int(Data.SIGHTING_SECONDS * 10.0) + 20:
		s.tick(0.1)
	t.check(m.count("sighted") == n + 1, "another sighting")
	t.check(Data.WANDERER_SIGHTINGS[2].has(m.args_of("sighted")[n][0]), "and it is a frightened one")
	for mood in Data.WANDERER_SIGHTINGS:
		t.check(mood.size() >= 3, "each mood has lines to rotate through")
	# Sky Watch itself is said aloud once, at once.
	var fresh_sim := helper.game([])
	var m2 := Monitor.new()
	m2.watch(fresh_sim.sky, "sighted")
	fresh_sim.tech_tree.researched["tally_sticks"] = true
	fresh_sim.tech_tree.researched["mining"] = true
	t.check(fresh_sim.research("sky_watch"), "research Sky Watch")
	t.check(m2.count("sighted") == 1 and m2.args_of("sighted")[0][0] == Data.WANDERER_NAMED_LINE, "the light is named")
	t.check(fresh_sim.story.events.has("wanderer_named"), "a story moment")


func test_the_wanderer_comes_nearer_with_each_tech() -> void:
	var s := helper.game([])
	var techs := Rules.era_techs(2)
	t.check(techs.size() == 16, "sixteen techs in the era")
	s.tech_tree.researched["sky_watch"] = true
	var last := s.sky.approach()
	t.check(last > 0.0 and last < 0.2, "the light is only a little near once named (%f)" % last)
	for id in techs:
		if s.tech_tree.researched.has(id):
			continue
		s.tech_tree.researched[id] = true
		var now := s.sky.approach()
		t.check(now > last, "%s brings it nearer" % id)
		last = now
	t.check(is_equal_approx(s.sky.approach(), 1.0), "all of them: the whole way")
	t.check(s.sky.mood() == 2, "the last mood")
	t.check(helper.game([]).sky.mood() == 0, "and the first before anything")


func test_star_charts_and_the_view() -> void:
	var s := helper.game(["sky_watch"])
	t.check(s.sky.named() and not s.sky.charted(), "named, not charted")
	var plain: String = SkyView.line_text(0, 0.2, false)
	t.check(plain.contains(Data.WANDERER_NAME) and not plain.contains("%"), "uncharted: no word of how far")
	var charted: String = SkyView.line_text(1, 0.5, true)
	t.check(charted.contains("50%") and charted.contains(Data.WANDERER_STATES[1]), "charted: a state and the path")
	s.tech_tree.researched["star_charts"] = true
	t.check(s.sky.charted(), "Star Charts draws the path")
	var box := Vector2(240, 64)
	var start := SkyView.light_at(0.0, box)
	var mid := SkyView.light_at(0.5, box)
	var end := SkyView.light_at(1.0, box)
	t.check(start.x < mid.x and mid.x < end.x, "the light crosses the sky left to right")
	t.check(mid.y < start.y and mid.y < end.y, "up over the middle and down")
	t.check(Rect2(Vector2.ZERO, box).has_point(start) and Rect2(Vector2.ZERO, box).has_point(end), "inside the sky")
	t.check(SkyView.light_radius(1.0) > SkyView.light_radius(0.0), "it grows as it nears")
	t.check(SkyView.light_at(-3.0, box) == start and SkyView.light_at(7.0, box) == end, "out-of-range clamps")
	var view := SkyView.new()
	view.setup(s, 240.0)
	view.refresh()
	t.check(view.visible, "the window shows once the light is named")
	var none := SkyView.new()
	none.setup(helper.game([]), 240.0)
	none.refresh()
	t.check(not none.visible, "and not before")
	view.free()
	none.free()


func test_the_sky_saves() -> void:
	var s := helper.game(["sky_watch"])
	t.check(t.place_free(s, "watchtower", helper.spot(s, 0)), "a Watchtower")
	for i in 1800:
		s.tick(0.1)
	var copy := Sim.new()
	t.check(RunSave.restore(copy, RunSave.dump(s)), "restore")
	t.check(copy.sky.sightings == s.sky.sightings and is_equal_approx(copy.sky.clock, s.sky.clock), "the sky is kept")
	var old := RunSave.dump(s)
	old["game"].erase("sky")
	var plain := Sim.new()
	t.check(RunSave.restore(plain, old) and plain.sky.sightings == 0, "an older save has none")


func test_the_falling_star_ends_the_era() -> void:
	var s := helper.game([])
	for id in Data.TECHS["falling_star"]["requires"]:
		s.tech_tree.researched[id] = true
	var m := Monitor.new()
	m.watch(s.story, "recorded")
	t.check(not s.story.events.has("star_falling"), "the star has not fallen")
	t.check(s.research("falling_star"), "research The Falling Star")
	t.check(s.story.events.has("star_falling"), "the story records it")
	t.check(m.args_of("recorded")[m.count("recorded") - 1][0] == "star_falling", "as the last moment")
	t.check(Data.STORY_EVENTS.has("star_falling") and Data.STORY_TECHS["falling_star"] == "star_falling", "stable id")
	# The game goes on.
	var wood: int = s.economy.inv["wood"]
	for i in 100:
		s.tick(0.1)
	t.check(s.people.kith.size() > 0, "the Kith are still there")
	t.check(s.economy.inv["wood"] >= 0 and wood >= 0, "and the stockpile goes on")
	t.check(t.place_free(s, "dwelling", helper.spot(s, 3)), "and they can still build")
	t.check(Data.ERA_END_TEXT.contains("It is not a star. It is coming down."), "the ominous line")


func test_the_ending_goes_in_the_profile() -> void:
	var s := helper.game([])
	s.story.record("bronze_dawn")
	s.story.record("star_falling")
	DirAccess.remove_absolute(TEMP_PROFILE)
	t.check(Profile.note_run(s, TEMP_PROFILE), "the ending is written to the profile file")
	var p := Profile.new()
	t.check(p.load_file(TEMP_PROFILE), "the file loads")
	t.check(p.has_story("star_falling") and p.has_story("bronze_dawn"), "with the moments of the run")
	var again := helper.game([])
	again.story.record("first_trip")
	t.check(Profile.note_run(again, TEMP_PROFILE), "a later run adds to it")
	var q := Profile.new()
	q.load_file(TEMP_PROFILE)
	t.check(q.has_story("star_falling") and q.has_story("first_trip"), "and keeps what was there")
	# The profile and the run save stay apart.
	t.check(not RunSave.dump(s).has("chronicle"), "the run save holds no profile")
	t.check(not q.to_dict().has("sky") and not q.to_dict().has("game"), "and the profile no run")
	DirAccess.remove_absolute(TEMP_PROFILE)
	t.check(Profile.note_run(s, "user://no_such_dir/profile.json") == false, "an unwritable path says so")


func test_the_era_card() -> void:
	var card := EraCard.new()
	card.setup()
	var m := Monitor.new()
	m.watch(card, "closed")
	t.check(not card.visible, "the card starts away")
	card.open()
	t.check(card.visible, "it opens")
	card.close()
	t.check(not card.visible and m.count("closed") == 1, "the button puts it away and says so")
	card.close()
	t.check(m.count("closed") == 1, "closing twice says nothing more")
	card.free()


func test_the_cairn_glows() -> void:
	t.check(Art.cairn_glow_alpha(0.0, 1.0) == 0.0, "no glow before the light is named")
	var near := Art.cairn_glow_alpha(1.0, 0.0)
	var far := Art.cairn_glow_alpha(0.2, 0.0)
	t.check(far > 0.0 and near > far, "it glows brighter as the Wanderer nears (%f, %f)" % [far, near])
	t.check(Art.cairn_glow_alpha(1.0, 0.3) != Art.cairn_glow_alpha(1.0, 1.1), "and pulses")
	t.check(Art.cairn_glow_alpha(5.0, 0.0) == near, "and tops out")
