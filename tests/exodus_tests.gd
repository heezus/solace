extends RefCounted
## Step 7 part A, the first reset (design-system/12-knowledge-is-progress.md, "Exodus as built"): the profile's carry (version 2), banked
## only when the Kith set out, the run that begins with it and keeps it through a save, the Skyward card's "Set out" and the game
## menu's two entries, each with a confirm that can be said no to. Nothing here plays a game. Run from tests/run_tests.gd.

const Carry = preload("res://scripts/carry.gd")
const Data = preload("res://scripts/data.gd")
const EraCard = preload("res://scripts/era_card.gd")
const GameMenu = preload("res://scripts/game_menu.gd")
const Launch = preload("res://scripts/launch.gd")
const Profile = preload("res://scripts/profile.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Sim = preload("res://scripts/sim.gd")

const TEMP_PROFILE := "user://solace_test_exodus_profile.json"

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	_clean()
	test_a_version_1_profile_loads_with_an_empty_carry()
	test_the_carry_is_banked_only_on_set_out()
	test_banking_again_adds_and_counts()
	test_a_new_run_begins_with_the_profile_as_its_carry()
	test_a_run_save_keeps_the_carry_it_began_with()
	test_forget_past_runs_gives_a_true_first_run()
	test_set_out_waits_for_skyward_and_the_confirm_can_be_cancelled()
	test_forget_asks_first()
	test_the_skyward_card_offers_set_out()
	_clean()


func _clean() -> void:
	if FileAccess.file_exists(TEMP_PROFILE):
		DirAccess.remove_absolute(TEMP_PROFILE)


## A Sim at the end of a run: the Light and Name sets read, the Growth set not, and a few techs.
func _ended_run() -> Sim:
	var s := Sim.new()
	s.generate(5)
	s.tech_tree.researched["knapping"] = true
	s.tech_tree.researched["bronze_dawn"] = true
	s.starfall.locked["name"] = true
	s.starfall.locked["light"] = true
	s.people.learn("wood", "Aro")
	s.story.record(Data.SKYWARD_EVENT)
	return s


func test_a_version_1_profile_loads_with_an_empty_carry() -> void:
	var p := Profile.new()
	var old := '{"version": 1, "chronicle": ["haulers"], "knowledge": ["wood"], "hints": ["hut"]}'
	t.check(p.from_json(old), "a version 1 profile loads")
	t.check(p.chronicle == ["haulers"] and p.knowledge == ["wood"] and p.hints == ["hut"], "with what it held")
	t.check(p.techs.is_empty() and p.marks.is_empty() and p.echoes.is_empty() and p.exoduses == 0, "and an empty carry")
	t.check(p.carry().is_first(), "which is a first run's")
	t.check(not p.from_json('{"version": 3, "chronicle": [], "knowledge": []}'), "a version from the future is refused")
	t.check(not p.from_json('{"version": 0, "chronicle": [], "knowledge": []}'), "and so is one before the first")
	var d := p.to_dict()
	t.check(d["version"] == 2 and d.has("techs") and d.has("exoduses"), "saved again it is version 2")
	p.from_dict({"version": 2, "chronicle": [], "knowledge": [], "techs": ["a", 3, "a"], "marks": null, "exoduses": -4})
	t.check(p.techs == ["a"] and p.marks.is_empty() and p.exoduses == 0, "stray carry entries are dropped")


func test_the_carry_is_banked_only_on_set_out() -> void:
	var s := _ended_run()
	t.check(Profile.note_run(s, TEMP_PROFILE), "a run's end is written to the profile")
	var p := Profile.new()
	p.load_file(TEMP_PROFILE)
	t.check(p.chronicle.has(Data.SKYWARD_EVENT) and p.knowledge == ["wood"], "its story and what the people learned")
	t.check(p.techs.is_empty() and p.marks.is_empty() and p.echoes.is_empty() and p.exoduses == 0, "but no carry")
	var q = Profile.set_out(s, TEMP_PROFILE)
	t.check(q.saved, "setting out writes the profile")
	p.load_file(TEMP_PROFILE)
	t.check(p.techs.has("knapping") and p.techs.has("bronze_dawn"), "the techs the run learned are banked")
	t.check(not p.techs.has("skyward"), "and not the ones it did not")
	var light: Array = Data.GLYPH_SETS[2]["glyphs"]
	var name_marks: Array = Data.GLYPH_SETS[1]["glyphs"]
	t.check(p.marks == name_marks + light, "the marks of every set it read, in the order of the sets")
	t.check(p.echoes == ["light"], "an echo for the set with a Lumen card, and none for the Name")
	t.check(p.exoduses == 1, "and one Exodus counted")
	t.check(p.chronicle.has(Data.SKYWARD_EVENT), "the run is folded in as note_run does")
	var fresh := Sim.new()
	fresh.generate(5)
	var before := RunSave.to_json(RunSave.dump(fresh))
	Profile.set_out(fresh, TEMP_PROFILE)
	t.check(RunSave.to_json(RunSave.dump(fresh)) == before, "setting out never changes the run it leaves")
	t.check(
		not Profile.set_out(s, "user://no_such_folder/profile.json").saved, "a profile that cannot be written says so"
	)


func test_banking_again_adds_and_counts() -> void:
	_clean()
	var first := _ended_run()
	Profile.set_out(first, TEMP_PROFILE)
	var second := Sim.new()
	second.generate(1005)
	second.tech_tree.researched["bronze_dawn"] = true
	second.tech_tree.researched["tally_sticks"] = true
	second.starfall.locked["light"] = true
	second.starfall.locked["body"] = true
	var p = Profile.set_out(second, TEMP_PROFILE)
	t.check(
		p.techs.count("bronze_dawn") == 1 and p.techs.has("tally_sticks") and p.techs.has("knapping"),
		"techs are kept once"
	)
	t.check(p.echoes == ["light", "body"] and p.exoduses == 2, "echoes add and the Exodus count goes up")
	_clean()


func test_a_new_run_begins_with_the_profile_as_its_carry() -> void:
	_clean()
	var s := Sim.new()
	Launch.begin_new(s, 7, TEMP_PROFILE)
	t.check(s.carry.is_first() and s.carry.techs.is_empty(), "with no profile it is a first run")
	t.check(s.world.map_seed == 7, "on the map asked for")
	Profile.set_out(_ended_run(), TEMP_PROFILE)
	var n := Sim.new()
	Launch.begin_new(n, 1005, TEMP_PROFILE)
	t.check(n.carry.exodus == 1 and n.carry.knows_tech("knapping"), "after setting out it begins with the carry")
	t.check(n.carry.has_echo("light") and not n.carry.has_echo("body"), "echoes only for the sets that were read")
	t.check(n.carry.knows_mark("g_light") and not n.carry.knows_mark("g_hurt"), "and marks")
	var base := Sim.new()
	base.generate(1005)
	t.check(
		n.tech_tree.researched == base.tech_tree.researched and n.economy.inv == base.economy.inv,
		"but no tech, no stock"
	)
	t.check(n.town.buildings.size() == base.town.buildings.size(), "and no buildings")
	_clean()


func test_a_run_save_keeps_the_carry_it_began_with() -> void:
	_clean()
	Profile.set_out(_ended_run(), TEMP_PROFILE)
	var s := Sim.new()
	Launch.begin_new(s, 1005, TEMP_PROFILE)
	var dump := RunSave.dump(s)
	t.check(dump["game"].has("carry") and dump["game"]["carry"]["exodus"] == 1, "the run save records the carry")
	Profile.forget(TEMP_PROFILE)  # the profile changes after the save
	var loaded := Sim.new()
	t.check(RunSave.restore(loaded, JSON.parse_string(RunSave.to_json(dump))), "it loads")
	t.check(loaded.carry.to_dict() == s.carry.to_dict() and loaded.carry.exodus == 1, "with the carry it began with")
	var old: Dictionary = JSON.parse_string(RunSave.to_json(dump))
	old["game"].erase("carry")
	var plain := Sim.new()
	t.check(RunSave.restore(plain, old) and plain.carry.is_first(), "a save from before the Exodus is a first run's")
	_clean()


func test_forget_past_runs_gives_a_true_first_run() -> void:
	_clean()
	Profile.set_out(_ended_run(), TEMP_PROFILE)
	t.check(FileAccess.file_exists(TEMP_PROFILE), "the profile is on disk")
	t.check(Profile.forget(TEMP_PROFILE) and not FileAccess.file_exists(TEMP_PROFILE), "forgetting removes it")
	t.check(Profile.forget(TEMP_PROFILE), "and forgetting nothing is fine")
	var s := Sim.new()
	Launch.begin_new(s, 1005, TEMP_PROFILE)
	t.check(s.carry.is_first() and s.carry.to_dict() == Carry.new().to_dict(), "the next run carries nothing")


func test_set_out_waits_for_skyward_and_the_confirm_can_be_cancelled() -> void:
	_clean()
	var s := Sim.new()
	s.generate(5)
	s.tech_tree.researched["knapping"] = true
	var menu := GameMenu.new()
	menu.profile_path = TEMP_PROFILE
	menu.setup(s)
	menu.open()
	t.check(menu.menu.set_out_button.disabled, "the menu's Set out is greyed until Skyward stands")
	menu.ask_set_out()
	t.check(not menu.confirm.visible and not menu.set_out(), "and asking before then does nothing")
	t.check(not FileAccess.file_exists(TEMP_PROFILE), "nothing banked")
	s.story.record(Data.SKYWARD_EVENT)
	menu.open()
	t.check(not menu.menu.set_out_button.disabled, "it opens once Skyward stands")
	menu.menu.set_out_pressed.emit()
	t.check(menu.confirm.visible, "pressing it asks first")
	t.check(menu.confirm._text.text == Data.EXODUS["confirm"], "in the words of the design")
	menu.close()
	t.check(not menu.confirm.visible and menu.is_open(), "Esc puts the question away and leaves the menu")
	t.check(not FileAccess.file_exists(TEMP_PROFILE), "with nothing banked")
	menu.ask_set_out()
	menu.confirm._no.pressed.emit()
	t.check(not menu.confirm.visible and not FileAccess.file_exists(TEMP_PROFILE), "saying no changes nothing")
	menu.ask_set_out()
	menu.confirm._yes.pressed.emit()
	var p := Profile.new()
	t.check(p.load_file(TEMP_PROFILE) and p.exoduses == 1 and p.techs.has("knapping"), "saying yes banks the carry")
	menu.free()
	_clean()


func test_forget_asks_first() -> void:
	_clean()
	Profile.set_out(_ended_run(), TEMP_PROFILE)
	var s := Sim.new()
	s.generate(5)
	var menu := GameMenu.new()
	menu.profile_path = TEMP_PROFILE
	menu.setup(s)
	menu.open()
	menu.menu.forget_pressed.emit()
	t.check(menu.confirm.visible and menu.confirm._text.text == Data.EXODUS["forget_confirm"], "Forget past runs asks")
	menu.confirm._no.pressed.emit()
	t.check(FileAccess.file_exists(TEMP_PROFILE), "no leaves the profile alone")
	menu.menu.forget_pressed.emit()
	menu.confirm._yes.pressed.emit()
	t.check(not FileAccess.file_exists(TEMP_PROFILE), "yes clears it")
	t.check(menu.menu.status.text == Data.EXODUS["forget_done"], "and says so")
	menu.free()
	_clean()


func test_the_skyward_card_offers_set_out() -> void:
	var card := EraCard.new()
	card.setup()
	var presses := [0]
	card.set_out_pressed.connect(func(): presses[0] += 1)
	card.open(Data.SKYWARD_EVENT)
	var button: Button = card._words["set_out"]
	t.check(button.visible and button.text == Data.EXODUS["set_out"], "the end of Livewire has a Set out button")
	t.check(card._words["button"].text == Data.SKYWARD_BUTTON, "beside Keep building")
	button.pressed.emit()
	t.check(presses[0] == 1 and card.visible, "it asks, and the card stays up")
	card.close()
	card.open("star_falling")
	t.check(not button.visible, "no other end of an era has it")
	card.open(Data.LIVEWIRE_EVENT)
	t.check(not button.visible, "not Ironfall's either")
	card.free()
