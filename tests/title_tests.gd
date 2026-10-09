extends RefCounted
## The title screen, the pause menu, the game menu and the Launch flag. Run from tests/run_tests.gd, which owns check().
## What needs a running scene (zoom, Esc, Save then Load) is in tests/tools/menu_pass.gd. The slots themselves are in
## tests/dev_tests.gd.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const RunSave = preload("res://scripts/run_save.gd")
const Launch = preload("res://scripts/launch.gd")
const TitleScreen = preload("res://scripts/title_screen.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const GameMenu = preload("res://scripts/game_menu.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")

const TEMP_SAVE := "user://test_title_run.json"
const TEMP_DIR := "user://test_title_slots/"  # the slots the title and menu tests use, apart from the player's

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_the_words_are_there()
	test_the_title_offers_continue_only_with_a_save()
	test_the_title_picks_a_painting()
	test_the_pause_menu_has_its_buttons()
	test_saving_and_loading_a_run()
	test_the_game_menu_saves_and_pauses()
	_remove_dir()


func test_the_title_picks_a_painting() -> void:
	t.check(TitleScreen.art_choice([], 0.5) == "", "no painting, the drawn stand-in")
	t.check(
		TitleScreen.art_choice([TitleScreen.ART_PATH], 0.99) == TitleScreen.ART_PATH, "one painting is the one shown"
	)
	var both := [TitleScreen.ART_PATH, TitleScreen.ALT_ART_PATH]
	t.check(TitleScreen.art_choice(both, 0.1) == TitleScreen.ART_PATH, "a low roll shows the first")
	t.check(TitleScreen.art_choice(both, 0.9) == TitleScreen.ALT_ART_PATH, "a high roll shows the second")
	t.check(TitleScreen.art_choice(both, 1.0) == TitleScreen.ALT_ART_PATH, "a roll of 1 does not run off the end")


func _clean() -> void:
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(TEMP_SAVE)
	_remove_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_DIR))


func _remove_dir() -> void:
	if DirAccess.dir_exists_absolute(TEMP_DIR):
		for f in DirAccess.get_files_at(TEMP_DIR):
			DirAccess.remove_absolute(TEMP_DIR + f)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_DIR))


func _buttons(node: Node) -> Array:
	var out := []
	for c in node.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_buttons(c))
	return out


func test_the_words_are_there() -> void:
	for text in [
		Data.TITLE_NAME, Data.TITLE_NEW, Data.TITLE_CONTINUE, Data.TITLE_QUIT, Data.PAUSE_RESUME, Data.PAUSE_SAVE
	]:
		t.check(text != "", "the menu says %s" % text)
	t.check(
		ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/title.tscn",
		"the game opens on the title"
	)
	t.check(ResourceLoader.exists("res://scenes/main.tscn"), "and the game scene is still there")


func test_the_title_offers_continue_only_with_a_save() -> void:
	_clean()
	var title := TitleScreen.new()
	title.slot_dir = TEMP_DIR
	title._ready()
	var buttons := _buttons(title)
	t.check(buttons.size() >= 4, "Continue, New game, Load game and Quit are there")
	t.check(buttons[0].disabled and buttons[0].text == Data.TITLE_NO_SAVE, "with no save, Continue is off and says why")
	t.check(not buttons[1].disabled and buttons[1].text == Data.TITLE_NEW, "New game is on")
	t.check(
		not buttons[2].disabled and buttons[2].text == Data.TITLE_LOAD,
		"Load game is on: the stage starts are always there"
	)
	t.check(not title.slots.visible, "and the Load screen is put away")
	buttons[2].pressed.emit()
	t.check(title.slots.visible and title.slots.mode == "load", "Load game opens the Load screen")
	title.free()
	var s := Sim.new()
	s.generate(3)
	t.check(SaveSlots.save(s, 3, TEMP_DIR), "a run saves")
	var again := TitleScreen.new()
	again.slot_dir = TEMP_DIR
	again._ready()
	var buttons2 := _buttons(again)
	t.check(not buttons2[0].disabled and buttons2[0].text == Data.TITLE_CONTINUE, "with a save, Continue is on")
	again.free()
	_clean()


func test_the_pause_menu_has_its_buttons() -> void:
	_clean()
	var menu := PauseMenu.new()
	menu.setup()
	t.check(not menu.visible, "it starts closed")
	menu.open()
	t.check(menu.visible and not menu.load_button.disabled, "open, Load is on: the stage starts are always there")
	t.check(not menu.debug_toggle.button_pressed, "and the debug keys are off")
	t.check(menu.cutscene_toggle.button_pressed, "and the cutscenes are on")
	var got := []
	menu.resumed.connect(func(): got.append("resume"))
	menu.save_pressed.connect(func(): got.append("save"))
	menu.load_pressed.connect(func(): got.append("load"))
	menu.quit_pressed.connect(func(): got.append("quit"))
	var buttons := _buttons(menu)
	t.check(buttons.size() == 6, "Resume, Save, Load, Quit and the Cutscenes and debug keys switches")
	t.check(menu.cutscene_toggle.text == Data.CUTSCENES_LABEL, "the Cutscenes switch is named")
	for b in buttons:
		if b != menu.debug_toggle and b != menu.cutscene_toggle:
			b.pressed.emit()
	t.check(got == ["resume", "save", "load", "quit"], "each button says what was pressed: %s" % [got])
	t.check(not menu.visible, "Resume puts it away")
	menu.open()
	menu.say("Game saved.")
	t.check(menu.status.text == "Game saved.", "the menu can say what happened")
	menu.free()
	_clean()


func test_saving_and_loading_a_run() -> void:
	_clean()
	var s := Sim.new()
	s.generate(11)
	for i in 400:
		s.tick(0.5)
	t.check(RunSave.exists(TEMP_SAVE) == false, "no file before saving")
	t.check(RunSave.save(s, TEMP_SAVE) and RunSave.exists(TEMP_SAVE), "the run is written")
	var s2 := Sim.new()
	t.check(RunSave.load_into(s2, TEMP_SAVE), "and read back")
	for i in 40:
		s.tick(0.5)
		s2.tick(0.5)
	var a := RunSave.dump(s)
	var b := RunSave.dump(s2)
	for section in ["world", "fog", "research", "buildings", "kith", "story"]:
		t.check(
			RunSave.to_json({"x": a[section]}) == RunSave.to_json({"x": b[section]}),
			"the loaded game goes on as the saved one: %s" % section
		)
	t.check(a["economy"]["inv"] == b["economy"]["inv"], "and so does the stockpile")
	var bad := FileAccess.open(TEMP_SAVE, FileAccess.WRITE)
	bad.store_string("not a save")
	bad.close()
	t.check(not RunSave.load_into(Sim.new(), TEMP_SAVE), "a damaged file is refused")
	_clean()


func test_the_game_menu_saves_and_pauses() -> void:
	_clean()
	var s := Sim.new()
	s.generate(5)
	var menu := GameMenu.new()
	menu.slot_dir = TEMP_DIR
	menu.setup(s)
	var pauses := []
	menu.paused_changed.connect(func(on): pauses.append(on))
	t.check(not menu.is_open(), "closed to begin with")
	menu.open()
	t.check(menu.is_open() and pauses == [true], "opening pauses the game")
	t.check(not menu.load_game(1), "Loading an empty slot does nothing")
	t.check(menu.menu.status.text == Data.LOAD_BAD_SLOT, "and says so")
	menu.menu.save_pressed.emit()
	t.check(menu.slots.visible and menu.slots.mode == "save", "Save opens the slots to pick from")
	menu.close()
	t.check(
		not menu.slots.visible and menu.is_open() and pauses == [true], "Esc puts the slots away first, not the menu"
	)
	t.check(menu.save_game(2) and not SaveSlots.read(2, TEMP_DIR).is_empty(), "Save writes the run into the slot")
	t.check(menu.menu.status.text == Data.SAVE_SLOT_DONE % 2, "and says which")
	t.check(SaveSlots.filled(TEMP_DIR) == [2], "and into that one only")
	menu.menu.load_pressed.emit()
	t.check(menu.slots.visible and menu.slots.mode == "load", "Load opens the Load screen")
	menu.close()
	menu.close()
	t.check(not menu.is_open() and pauses == [true, false], "closing lets the game go on")
	menu.free()
	_clean()
