extends RefCounted
## Step 7, the Kin (scripts/kin_name.gd): the people are "Kith" until the first ship's marks are read, then "Kin" everywhere they are
## shown; the Hearthkeeper says why in the last still of the reveal; one card says so once; the profile keeps it for every later run.
## The controls' own text (they shape it through a Translation) is checked by tests/tools/kin_pass.gd, which needs the running tree.
## Run from tests/telling_tests.gd.

const CutscenePlayer = preload("res://scripts/cutscene_player.gd")
const Data = preload("res://scripts/data.gd")
const KinName = preload("res://scripts/kin_name.gd")
const NoticeCard = preload("res://scripts/notice_card.gd")
const Profile = preload("res://scripts/profile.gd")
const Sim = preload("res://scripts/sim.gd")
const Words = preload("res://scripts/chronicle_words.gd")

const SEED := 5
const TEMP_PROFILE := "user://solace_test_kin_profile.json"

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	_clean()
	test_before_the_marks_are_read_the_text_says_kith()
	test_after_it_says_kin_and_keeps_the_reveal()
	test_the_profile_keeps_the_name()
	test_the_hearthkeeper_says_it()
	test_the_card_comes_once_after_the_telling()
	test_the_lore_page_tells_it_as_history()
	_clean()


func _clean() -> void:
	KinName.known = false
	Profile.forget(TEMP_PROFILE)


func test_before_the_marks_are_read_the_text_says_kith() -> void:
	var line: String = Data.BORN_POPUP % Data.PEOPLE["one"]
	t.check(not KinName.known and KinName.say(line) == line, "a first run reads exactly as written")
	t.check(KinName.say("The Kith's first fire") == "The Kith's first fire", "'Kith's' too")
	t.check(
		Data.PEOPLE["many"] == "Kith" and Data.BUILDINGS["camp"]["desc"].contains("Kith"),
		"and the Data words are still Kith"
	)


func test_after_it_says_kin_and_keeps_the_reveal() -> void:
	KinName.known = true
	t.check(
		KinName.say("The Kith's home fire. Kith are born here.") == "The Kin's home fire. Kin are born here.",
		"every Kith is Kin"
	)
	t.check(
		(
			KinName.say(Data.BUILDINGS["camp"]["desc"]).contains("Kin")
			and not KinName.say(Data.BUILDINGS["camp"]["desc"]).contains("Kith")
		),
		"a building card too"
	)
	t.check(KinName.say("Wood and stone") == "Wood and stone", "other words are left alone")
	for line in KinName.KEPT:
		t.check(KinName.say(line) == line, "'%s' is kept as written" % line)
	t.check(
		(
			KinName.say("The Kith heard it: We were never only Kith. We are Kin.")
			== "The Kin heard it: We were never only Kith. We are Kin."
		),
		"and only that line"
	)
	KinName.known = false


func test_the_profile_keeps_the_name() -> void:
	var fresh := Profile.new()
	t.check(not fresh.kin_known and not fresh.kin_told and fresh.is_empty(), "a new profile has no Kin yet")
	t.check(not Profile.kin_known_at(TEMP_PROFILE), "a missing file says no")
	t.check(
		Profile.note_kin(false, TEMP_PROFILE) and Profile.kin_known_at(TEMP_PROFILE), "set 7 read: the flag is kept"
	)
	var back := Profile.new()
	back.load_file(TEMP_PROFILE)
	t.check(back.kin_known and not back.kin_told and not back.is_empty(), "known, not yet told")
	Profile.note_kin(true, TEMP_PROFILE)
	back.load_file(TEMP_PROFILE)
	t.check(back.kin_known and back.kin_told, "told")
	Profile.note_kin(false, TEMP_PROFILE)
	back.load_file(TEMP_PROFILE)
	t.check(back.kin_told, "and a later note does not take it back")
	var ended := Sim.new()
	ended.generate(SEED)
	Profile.forget(TEMP_PROFILE)
	Profile.set_out(ended, TEMP_PROFILE)
	t.check(not Profile.kin_known_at(TEMP_PROFILE), "a run that never read the first ship does not make the Kin")
	ended.story.record(Profile.KIN_EVENT)
	Profile.set_out(ended, TEMP_PROFILE)
	t.check(Profile.kin_known_at(TEMP_PROFILE), "a run that did, and ended, does")
	var older := Profile.new()
	older.from_dict({"version": 3, "chronicle": [Profile.KIN_EVENT], "knowledge": []})
	t.check(
		older.kin_known and not older.kin_told, "a profile from before it has the Kin once its story holds the moment"
	)
	Profile.forget(TEMP_PROFILE)


func test_the_hearthkeeper_says_it() -> void:
	var stills: Array = Data.CUTSCENES["kin_reveal"]["stills"]
	var last: Dictionary = stills[stills.size() - 1]
	t.check(stills.size() == 3 and last["line"].contains(KinName.KEPT[0]), "the reveal ends on the Hearthkeeper's line")
	t.check(
		last.get("portrait", "") == "portrait_kin_elder" and last["art"] == "fireside_1",
		"over the fireside, with the elder"
	)
	var s := Sim.new()
	s.generate(SEED)
	var p = CutscenePlayer.new()
	p.setup(s, null, [])
	s.story.record(Profile.KIN_EVENT)
	t.check(p.pending("kin_reveal") and not p.pending("fireside"), "reading set 7 queues it")
	KinName.known = true
	t.check(
		KinName.say(p.resolve("kin_reveal")[2]["line"]).contains(KinName.KEPT[0]),
		"and it still says Kith when played as Kin"
	)
	KinName.known = false
	p.free()


func test_the_card_comes_once_after_the_telling() -> void:
	var s := Sim.new()
	s.generate(SEED)
	var card := NoticeCard.new()
	card.profile_path = TEMP_PROFILE
	card.setup()
	var looks: Array = []
	card.closed.connect(func(look: bool): looks.append(look))
	t.check(not card.poll(s, false) and not KinName.known, "nothing happens before set 7 is read")
	s.story.record(Profile.KIN_EVENT)
	t.check(not card.poll(s, true), "the card waits behind another card")
	t.check(card.poll(s, false) and card.visible and KinName.known, "set 7 read: the card is up and the people are Kin")
	var words := ""
	for c in card._box.get_children():
		if c is Label:
			words += c.text + "\n"
	t.check(
		words.contains(KinName.CARD_TEXT) and not words.contains("Kith"), "it says so: %s" % words.replace("\n", " | ")
	)
	t.check(Profile.kin_known_at(TEMP_PROFILE), "and the profile keeps it for every later run")
	var back := Profile.new()
	back.load_file(TEMP_PROFILE)
	t.check(back.kin_told, "with the card marked as shown")
	card._pick(0)
	t.check(looks == [false] and not card.visible, "the button puts it away and does not send the camera home")
	t.check(not card.poll(s, false), "once")
	var again := NoticeCard.new()
	again.profile_path = TEMP_PROFILE
	again.setup()
	t.check(KinName.known and not again.poll(s, false), "a later run is Kin from its first screen and tells nothing")
	card.free()
	again.free()
	KinName.known = false


func test_the_lore_page_tells_it_as_history() -> void:
	var layer := {}
	for row in Words.LAYERS:
		layer[row["event"]] = row["text"]
	var text: String = layer[Profile.KIN_EVENT]
	t.check(text.contains(KinName.KEPT[1]), "the Lore page reads: The Kith learned they were Kin")
	KinName.known = true
	t.check(KinName.say(text).contains(KinName.KEPT[1]), "and still does once they are")
	KinName.known = false
