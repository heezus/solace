extends RefCounted
## The fixes from Jon's playtest notes (2026-10-19): era starts handed over tidy, buildings beside buildings linked, the side panel
## never opening by itself, one key for every build tab, the Wanderer whole once it has fallen. Run from tests/run_tests.gd.

const Data = preload("res://scripts/data.gd")
const OldShip = preload("res://scripts/old_ship.gd")
const Roads = preload("res://scripts/roads.gd")
const Sim = preload("res://scripts/sim.gd")
const StartTidy = preload("res://scripts/start_tidy.gd")
const HudFold = preload("res://scripts/hud_fold.gd")
const Hotkeys = preload("res://scripts/hotkeys.gd")
const BuildBar = preload("res://scripts/build_bar.gd")
const SkyView = preload("res://scripts/sky_view.gd")

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_a_start_is_handed_over_working()
	test_a_building_beside_a_linked_building_is_linked()
	test_the_side_panel_is_only_the_players_choice()
	test_every_build_tab_has_its_own_key()
	test_the_wanderer_is_whole_once_it_has_fallen()
	test_every_glyph_clue_points_at_its_word()


func test_a_start_is_handed_over_working() -> void:
	var s: Sim = t.fresh()
	t.give(s, 200)
	var hut := s.world.camp_pos + Vector2i(3, 0)
	t.place_free(s, "gatherers_hut", hut)
	var i: int = s.town.building_at[hut]
	s.set_paused(i, true)
	StartTidy.tidy(s)
	t.check(not s.town.buildings[i]["paused"], "a building the bot paused is working when a start is handed over")


func test_a_building_beside_a_linked_building_is_linked() -> void:
	var s: Sim = t.fresh()
	t.give(s, 200)
	for id in ["storehouse", "fire", "haulers"]:
		s.tech_tree.researched[id] = true
	var camp := s.world.camp_pos
	var far := camp + Vector2i(8 if camp.x < 14 else -8, 0)
	for dy in range(-2, 3):
		for dx in range(-4, 5):
			s.world.set_tile(far + Vector2i(dx, dy), "grass")
	s.pathing.build()
	var step := Vector2i(1 if camp.x < 14 else -1, 0)
	t.check(s.place("storehouse", far), "a Storehouse far from the Hearth")
	t.check(s.place("charcoal_pit", far + step), "a pit beside it")
	t.check(s.place("charcoal_pit", far + step * 2), "and a second pit beside the first, a tile from the Storehouse")
	var second: Dictionary = s.town.buildings[s.town.building_at[far + step * 2]]
	t.check(Roads.linked(s, second), "the second pit is linked through the first, with no road at all")


func test_the_side_panel_is_only_the_players_choice() -> void:
	var hud := HudFold.new()
	hud.folded = true
	t.check(not hud.is_open(true), "a folded panel stays folded while a building's card is up")
	hud.folded = false
	t.check(hud.is_open(false), "and an open one stays open with none")


func test_every_build_tab_has_its_own_key() -> void:
	var taken := {}
	for tab_name in Data.BUILD_TABS.keys() + [BuildBar.CRAFT_TAB]:
		t.check(Hotkeys.TAB_KEYS.has(tab_name), "%s has a key" % tab_name)
		var key: int = Hotkeys.TAB_KEYS.get(tab_name, KEY_NONE)
		t.check(not taken.has(key), "%s's key is its own" % tab_name)
		taken[key] = true
	for key in [KEY_T, KEY_X, KEY_G, KEY_B, KEY_R, KEY_P, KEY_SPACE, KEY_TAB, KEY_1, KEY_2, KEY_3, KEY_HOME]:
		t.check(not taken.has(key), "no tab takes %s, which does something else" % OS.get_keycode_string(key))


func test_the_wanderer_is_whole_once_it_has_fallen() -> void:
	var s: Sim = t.fresh()
	s.tech_tree.researched["sky_watch"] = true
	t.check(s.sky.approach() < 1.0 and not s.sky.fallen(), "before the star falls the light is still on its way")
	s.tech_tree.researched["falling_star"] = true
	t.check(s.sky.fallen() and is_equal_approx(s.sky.approach(), 1.0), "once it falls the Wanderer is all the way")
	t.check(
		SkyView.line_text(2, s.sky.approach(), true).contains("100%"),
		"and the old line, if it were shown, would say so"
	)


## Every mark's word is one of the words the player can try, every mark has its three clues, and the first clue (the one every player
## sees) hints without giving the word away: it holds none of the words on the list.
func test_every_glyph_clue_points_at_its_word() -> void:
	for id in Data.GLYPHS:
		var g: Dictionary = Data.GLYPHS[id]
		var every: Array = OldShip.words_for(id)  # the old marks add three words, to their own lists only
		var words: Array = every.map(func(w): return w.to_lower())
		t.check(g["word"] in every, "%s: its word is on the list of words to try" % id)
		t.check(g["found"].size() == 3 and g["found"].all(func(l): return l != ""), "%s has three clues" % id)
		var first_words := RegEx.create_from_string("[a-z]+").search_all(String(g["found"][0]).to_lower())
		for m in first_words:
			t.check(
				not words.has(m.get_string()), "%s: the first clue says '%s', a word on the list" % [id, m.get_string()]
			)
	for n in Data.GLYPH_SETS:
		var seen := {}
		for g in Data.GLYPH_SETS[n]["glyphs"]:
			seen[Data.GLYPHS[g]["word"]] = true
		t.check(seen.size() == 3, "set %d: three different words" % n)
