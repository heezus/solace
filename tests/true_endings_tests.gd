extends RefCounted
## Step 8B, the true endings (design-system/18-roadmap.md): Seal Solace, Heal the Bloom and Leave together show on the ending card once
## the marks of The Way Out are read while the Lumen are allies; Heal needs a Cataclysm in an earlier telling and Leave a Time loop.
## A true ending banks the telling, plays its three stills and the fireside, and asks Another telling or the title. Run from
## tests/telling_tests.gd, which owns the helpers.

const Carry = preload("res://scripts/carry.gd")
const Chronicle = preload("res://scripts/chronicle.gd")
const Data = preload("res://scripts/data.gd")
const EndingCard = preload("res://scripts/ending_card.gd")
const Endings = preload("res://scripts/endings.gd")
const GameMenu = preload("res://scripts/game_menu.gd")
const Profile = preload("res://scripts/profile.gd")
const Sim = preload("res://scripts/sim.gd")

const TEMP_PROFILE := "user://solace_test_true_endings_profile.json"

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_way_opens_them_for_allies_only()
	test_each_one_has_its_own_lock()
	test_the_card_shows_them_above_the_three()
	test_a_true_ending_banks_the_telling()
	test_a_shut_one_cannot_be_taken()
	test_the_carry_counts_the_cycle()
	test_the_scenes_and_stars_exist()
	test_the_words_say_kin()
	DirAccess.remove_absolute(TEMP_PROFILE)


## The true endings play after the Kin reveal (set 7 comes before set 9), so no line of theirs says "Kith".
func test_the_words_say_kin() -> void:
	var words: Array = [Data.ENDINGS["true_text"]]
	for key in ["seal", "heal", "leave"]:
		words.append(Data.ENDINGS[key]["end"])
		words.append(Data.ENDINGS[key]["next_text"])
		for still in Data.CUTSCENES[key + "_end"]["stills"]:
			words.append(still["line"])
	for line in words:
		t.check(not String(line).contains("Kith"), "a true-ending line says Kin, not Kith: %s" % line)


## A run in the second telling or later, the Skyreach standing, the Lumen as `lean`, with the Way Out read when `way` is true and the
## endings of the tellings before in `before`.
func _run(lean: String, way: bool, before := []) -> Sim:
	var s := Sim.new()
	s.generate(5)
	s.carry.exodus = 1 + before.size()
	s.carry.reached = before.duplicate()
	s.starfall.lean = lean
	s.starfall.trust = 80.0
	s.story.record(Data.SKYWARD_EVENT)
	s.story.record(Data.SKYREACH["done"])
	if way:
		s.starfall.locked["way"] = true
		s.story.record("way_read")
	return s


func test_the_way_opens_them_for_allies_only() -> void:
	t.check(not Endings.way_open(_run("allies", false)), "nothing shows before the Way Out is read")
	t.check(not Endings.way_open(_run("neighbours", true)), "and not for neighbours")
	t.check(not Endings.way_open(_run("enemies", true)), "nor for enemies")
	t.check(Endings.way_open(_run("allies", true)), "the Way Out read with allies opens them")
	t.check(
		Endings.true_why("seal", _run("allies", false)) == Data.ENDINGS["needs_way"], "a shut one names the Way Out"
	)


func test_each_one_has_its_own_lock() -> void:
	var first := _run("allies", true)
	t.check(Endings.true_open("seal", first), "Seal Solace is open with the Way Out")
	t.check(
		Endings.true_why("heal", first) == Data.ENDINGS["needs_cataclysm"], "Heal the Bloom needs an earlier Cataclysm"
	)
	t.check(Endings.true_why("leave", first) == Data.ENDINGS["needs_loop"], "Leave together needs an earlier Time loop")
	var cataclysm := _run("allies", true, ["cataclysm"])
	t.check(
		Endings.true_open("heal", cataclysm) and not Endings.true_open("leave", cataclysm),
		"a Cataclysm opens Heal only"
	)
	var loop := _run("allies", true, ["exodus", "loop"])
	t.check(Endings.true_open("leave", loop) and not Endings.true_open("heal", loop), "a Time loop opens Leave only")
	var both := _run("allies", true, ["cataclysm", "loop"])
	t.check(
		Endings.true_open("seal", both) and Endings.true_open("heal", both) and Endings.true_open("leave", both),
		"both opens all three"
	)


func test_the_card_shows_them_above_the_three() -> void:
	var card := EndingCard.new()
	card.setup()
	card.open(2, "allies")
	t.check(not card._true_box.visible, "without the Way Out the true endings do not show")
	var s := _run("allies", true, ["cataclysm"])
	card.open(3, "allies", {"seal": "", "heal": "", "leave": Endings.true_why("leave", s)})
	t.check(card._true_box.visible, "once it is read they do")
	t.check(not card.button_of("seal").disabled and not card.button_of("heal").disabled, "the open ones can be pressed")
	t.check(
		card.button_of("leave").disabled and card.why_of("leave") == Data.ENDINGS["needs_loop"],
		"a shut one shows its need"
	)
	var picked := [""]
	card.chosen.connect(func(id): picked[0] = id)
	card.button_of("heal").pressed.emit()
	t.check(picked[0] == "heal" and not card.visible, "pressing a true ending chooses it")
	card.free()


func test_a_true_ending_banks_the_telling() -> void:
	DirAccess.remove_absolute(TEMP_PROFILE)
	var s := _run("allies", true, ["cataclysm"])
	var menu := GameMenu.new()
	menu.profile_path = TEMP_PROFILE
	menu.setup(s)
	menu.ask_set_out()
	t.check(
		menu.endings._true_box.visible and menu.endings.button_of("heal").disabled == false,
		"the menu shows Heal as open"
	)
	menu.endings.button_of("heal").pressed.emit()
	t.check(menu.confirm.visible and menu.confirm._text.text == Data.ENDINGS["heal"]["end"], "it asks in its own words")
	t.check(menu.set_out("heal"), "and a yes sets out")
	t.check(s.story.has_event("ending_heal"), "the ending is a moment of the Chronicle")
	var p := Profile.new()
	t.check(p.load_file(TEMP_PROFILE) and p.runs == 1, "the telling is in the profile")
	t.check(
		p.tellings[0]["ending"] == "heal" and Chronicle.times_reached(p.tellings, "heal") == 1,
		"ended in Heal the Bloom"
	)
	t.check(menu._ended_whole(), "the menu knows the telling ended whole")
	menu.free()


func test_a_shut_one_cannot_be_taken() -> void:
	DirAccess.remove_absolute(TEMP_PROFILE)
	var s := _run("allies", true)  # no earlier Cataclysm
	var menu := GameMenu.new()
	menu.profile_path = TEMP_PROFILE
	menu.setup(s)
	menu.ask_confirm("heal")
	t.check(not menu.confirm.visible, "the confirm does not open for a shut true ending")
	t.check(not menu.set_out("heal") and not s.story.has_event("ending_heal"), "and it cannot be taken")
	t.check(not FileAccess.file_exists(TEMP_PROFILE), "nothing is banked")
	var no_way := _run("allies", false)
	var menu2 := GameMenu.new()
	menu2.profile_path = TEMP_PROFILE
	menu2.setup(no_way)
	t.check(not menu2.set_out("seal"), "Seal Solace needs the Way Out too")
	menu.free()
	menu2.free()


func test_the_carry_counts_the_cycle() -> void:
	DirAccess.remove_absolute(TEMP_PROFILE)
	var s := _run("allies", true, ["cataclysm"])
	Profile.set_out(s, TEMP_PROFILE, "heal")
	var p := Profile.new()
	p.load_file(TEMP_PROFILE)
	var carry: Carry = p.carry()
	t.check(carry.reached == ["heal"] and carry.has_reached("heal"), "the next run knows how the last telling ended")
	t.check(carry.cycle() == 1, "one true ending is the first cycle")
	var back := Carry.new()
	back.from_dict(carry.to_dict())
	t.check(back.reached == carry.reached and back.cycle() == 1, "the carry keeps it through a save")
	t.check(Carry.new().cycle() == 0, "a first run is in no cycle")


func test_the_scenes_and_stars_exist() -> void:
	for id in Data.ENDINGS["true_order"]:
		var def: Dictionary = Data.ENDINGS[id]
		t.check(Data.STORY_EVENTS.has(def["id"]), "%s is a story moment" % id)
		t.check(
			Data.CUTSCENES.has(id + "_end") and Data.CUTSCENES[id + "_end"]["triggers"] == [def["id"]],
			"%s has its scene" % id
		)
		var stills: Array = Data.CUTSCENES[id + "_end"]["stills"]
		t.check(
			stills.size() == 3 and stills[2]["line"].contains("the telling became whole"),
			"three stills ending on the fireside"
		)
	var star := Chronicle.stars_of(
		{"run": 3, "seed": 1, "choices": [], "lean": "allies", "ending": "heal", "trust": 80.0}
	)
	t.check(
		star.any(func(x): return x["kind"] == "ending" and x["option"] == "heal"), "the Chronicle draws the ending star"
	)
