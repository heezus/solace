extends RefCounted
## The AI player's story hands (tests/tools/ai_story.gd): the Glyph Wall's marks are read and guessed, a scene is watched or skipped, the
## ending card opens, and setting out folds the run into a profile and begins the next one with the Chronicle open.
## Registered by AiPlayerTests.run.

const AiStory = preload("res://tests/tools/ai_story.gd")
const Data = preload("res://scripts/data.gd")
const Profile = preload("res://scripts/profile.gd")
const Sim = preload("res://scripts/sim.gd")
const Snapshot = preload("res://tests/tools/ai_snapshot.gd")

const PROFILE := "user://ai_story_test_profile.json"

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_wall_is_on_the_page_and_a_guess_reads_a_set()
	test_a_scene_is_watched_or_skipped()
	test_the_ending_card_opens_and_setting_out_begins_the_next_telling()


func _game() -> Sim:
	AiStory.reset(PROFILE)
	var game := Sim.new()
	game.generate(3)
	return game


func test_the_wall_is_on_the_page_and_a_guess_reads_a_set() -> void:
	var s := _game()
	var f = s.starfall
	var marks: Array = f.glyph_order(1)
	for g in marks:
		f.copied.append(g)
	var page := Snapshot.text(s, 1, [], [])
	t.check("GLYPH WALL" in page and "mark 1.1:" in page and "mark 1.3:" in page, "the marks are on the page")
	t.check(
		not page.contains(Data.GLYPHS[marks[0]]["word"] + " "), "a mark's handle gives no word away (%s)" % marks[0]
	)
	var refused := Snapshot.apply(
		s, [{"do": "guess", "mark": "9.9", "word": "Star"}, {"do": "guess", "mark": "1.1", "word": "Nonsense"}]
	)
	t.check(
		refused.size() == 2, "a mark that is not there and a word that is not listed are refused: %s" % str(refused)
	)
	for i in marks.size():
		var move := {"do": "guess", "mark": "1.%d" % (i + 1), "word": str(Data.GLYPHS[marks[i]]["word"]).to_upper()}
		t.check(Snapshot.apply(s, [move]).is_empty(), "the guess on mark 1.%d is taken" % (i + 1))
	t.check(f.check() and f.locked.has(Data.GLYPH_SETS[1]["id"]), "right words on every mark read the set")
	t.check(
		"%s" % (Data.WALL_SET_LOCKED % Data.GLYPH_SETS[1]["name"]) in Snapshot.text(s, 2, [], []),
		"the page says the set is read"
	)
	t.check(
		Snapshot.apply(s, [{"do": "guess", "mark": "1.1", "word": "Come"}]).size() == 1,
		"a read mark takes no new guess"
	)


func test_a_scene_is_watched_or_skipped() -> void:
	var s := _game()
	var page := Snapshot.text(s, 1, [], [])
	t.check("SCENE WAITING: opening" in page, "the opening waits to be watched")
	t.check(
		Snapshot.apply(s, [{"do": "scene", "id": "nothing", "action": "watch"}]).size() == 1,
		"a scene that is not waiting is refused"
	)
	t.check(
		Snapshot.apply(s, [{"do": "scene", "id": "opening", "action": "watch"}]).is_empty(),
		"watching the opening is taken"
	)
	var after := Snapshot.text(s, 2, [], [])
	t.check(Data.CUTSCENES["opening"]["stills"][0]["line"] in after, "watching tells its lines on the next page")
	t.check(not ("SCENE WAITING: opening" in after), "a watched scene is not offered again")


func test_the_ending_card_opens_and_setting_out_begins_the_next_telling() -> void:
	var s := _game()
	t.check(Snapshot.apply(s, [{"do": "endings"}]).size() == 1, "no ending card before Skyward stands")
	s.story.record(Data.SKYWARD_EVENT)
	t.check("SKYWARD STANDS" in Snapshot.text(s, 1, [], []), "the page says the telling can end")
	t.check(Snapshot.apply(s, [{"do": "endings"}]).is_empty(), "the ending card opens")
	var card := Snapshot.text(s, 2, [], [])
	t.check(
		"ENDING CARD" in card and "exodus: Exodus" in card and "Shut: Needs the Lumen as enemies" in card,
		"the card lists the endings and why one is shut"
	)
	t.check(Snapshot.apply(s, [{"do": "ending_details", "ending": "exodus"}]).is_empty(), "an ending's details open")
	t.check(Data.ENDINGS["exodus"]["end"] in Snapshot.text(s, 3, [], []), "the details are on the card")
	t.check(Snapshot.apply(s, [{"do": "set_out", "ending": "cataclysm"}]).size() == 1, "a shut ending is refused")
	var refused := Snapshot.apply(s, [{"do": "set_out", "ending": "exodus"}, {"do": "chronicle"}])
	t.check(
		refused.size() == 1 and AiStory.next_run != null,
		"setting out is taken and the moves after it wait: %s" % str(refused)
	)
	var fresh = AiStory.take_next()
	t.check(fresh != null and fresh.carry.exodus == 1, "the next telling is run 2 with the carry")
	var page := Snapshot.text(fresh, 4, [], [])
	t.check(
		"THE CHRONICLE opens on the telling that just ended" in page and "A NEW TELLING BEGINS (run 2" in page,
		"the Chronicle opens and the new telling is announced"
	)
	var profile := Profile.new()
	profile.load_file(PROFILE)
	t.check(profile.tellings.size() == 1 and profile.tellings[0]["ending"] == "exodus", "the telling is in the profile")
	t.check(
		(
			Snapshot.apply(fresh, [{"do": "chronicle"}]).is_empty()
			and "THE CHRONICLE: telling 1 of 1" in Snapshot.text(fresh, 5, [], [])
		),
		"the Chronicle can be opened again"
	)
	Profile.forget(PROFILE)
