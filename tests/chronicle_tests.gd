extends RefCounted
## Step 7G, the Chronicle (scripts/chronicle.gd, scripts/chronicle_book.gd, design-system/18-roadmap.md "The Chronicle as built"): a
## fresh profile shows an empty sky; every road not taken on a played star has a whisper; the Bloom's fragments start with the third
## telling; Embers light once; a telling keeps its numbers, small map and Embers; and every page can play its scenes again.
## Run from tests/telling_tests.gd.

const Chronicle = preload("res://scripts/chronicle.gd")
const ChronicleBook = preload("res://scripts/chronicle_book.gd")
const Data = preload("res://scripts/data.gd")
const Endings = preload("res://scripts/endings.gd")
const GameMenu = preload("res://scripts/game_menu.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const Profile = preload("res://scripts/profile.gd")
const Sim = preload("res://scripts/sim.gd")
const Words = preload("res://scripts/chronicle_words.gd")

const SEED := 5
const TEMP_PROFILE := "user://solace_test_chronicle_profile.json"
const PAGES := ["tellings", "lore", "people", "endings"]

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	_clean()
	test_a_fresh_profile_shows_an_empty_sky()
	test_every_road_not_taken_has_a_whisper()
	test_a_telling_makes_its_stars()
	test_the_bloom_speaks_from_the_third_telling()
	test_embers_light_once()
	test_a_telling_keeps_its_numbers_map_and_embers()
	test_an_older_profile_still_reads()
	test_every_page_plays_its_scenes_again()
	test_the_book_opens_from_the_menus_and_between_tellings()
	test_a_scene_replays_in_the_variant_of_its_telling()
	_clean()


func _clean() -> void:
	if FileAccess.file_exists(TEMP_PROFILE):
		DirAccess.remove_absolute(TEMP_PROFILE)


## A telling record as Endings.telling makes one: the small choices it recorded, its lean and its ending.
func _telling(run_number: int, choices: Array, lean: String, ending: String) -> Dictionary:
	return {"run": run_number, "choices": choices, "lean": lean, "trust": 30.0, "ending": ending}


## A profile holding two tellings (an Exodus after neighbours, a Cataclysm after enemies) and the story ids they recorded.
func _profile() -> Profile:
	var p := Profile.new()
	p.tellings = [
		_telling(1, ["cairn_raised", "hunger_shared", "shards_given", "dark_kept"], "neighbours", "exodus"),
		_telling(2, ["hunger_held", "shards_refused", "dark_refused"], "enemies", "cataclysm"),
	]
	p.runs = 2
	p.chronicle = ["lumen_arrived", "bloom_seen", "name_read", "ship_read", "ending_exodus", "ending_cataclysm"]
	p.marks = ["g_star", "g_come", "g_kin", "g_ship", "g_kin_old", "g_home_old"]
	return p


func test_a_fresh_profile_shows_an_empty_sky() -> void:
	t.check(Chronicle.sky([]).is_empty(), "no ended telling, no constellation")
	var book := ChronicleBook.new()
	book.setup()
	book.open(Profile.new())
	t.check(book.visible and book.star_buttons.is_empty(), "the book opens on an empty sky")
	t.check(book.watch_buttons.is_empty(), "with nothing to watch again")
	for page in PAGES:
		book.show_page(page)
		t.check(book.page == page, "the %s page opens on a fresh profile" % page)
	book.free()
	t.check(Chronicle.scenes([], 0).is_empty(), "no scene is open before a telling")
	t.check(Chronicle.layers([]).all(func(l): return not l["open"]), "and every layer of lore is shut")


func test_every_road_not_taken_has_a_whisper() -> void:
	t.check(Words.STAR_ORDER.size() == Words.STARS.size(), "every star is asked in some order")
	for kind in Words.STAR_ORDER:
		var options: Dictionary = Words.STARS[kind]["options"]
		t.check(options.size() >= 2, "%s has a road to take and one to wonder about" % kind)
		t.check(Words.STARS[kind]["bloom"] != "", "%s has the Bloom's fragment" % kind)
		for id in options:
			var o: Dictionary = options[id]
			t.check(
				o["event"] == "" or Data.STORY_EVENTS.has(o["event"]), "%s/%s: its event is a story id" % [kind, id]
			)
			for key in ["entry", "whisper"]:
				t.check(
					Words.VOICES.has(o[key]["voice"]) and o[key]["text"].length() > 20,
					"%s/%s has a %s" % [kind, id, key]
				)
				t.check(o[key]["text"].length() <= 140, "%s/%s: the %s is short" % [kind, id, key])
			var telling := _telling(1, [], "", "")
			match kind:
				"lean":
					telling["lean"] = id
				"ending":
					telling["ending"] = id
				_:
					telling["choices"] = [o["event"]] if o["event"] != "" else []
			var stars := Chronicle.stars_of(telling).filter(func(s): return s["kind"] == kind)
			t.check(
				stars.size() == 1 and stars[0]["option"] == id, "%s/%s is read from a telling that took it" % [kind, id]
			)
			t.check(
				stars[0]["whispers"].size() == options.size() - 1,
				"%s/%s: one whisper for each road not taken" % [kind, id]
			)
			for w in stars[0]["whispers"]:
				t.check(w["text"] != "" and w["voice"] != "", "%s/%s: the whisper has a voice" % [kind, id])
	t.check(
		Words.TRUE_ENDINGS.size() == 3 and Words.TRUE_ENDINGS.all(func(e): return e["needs"] != ""),
		"three true endings, each with its need"
	)


func test_a_telling_makes_its_stars() -> void:
	var stars := Chronicle.stars_of(
		_telling(2, ["cairn_raised", "hunger_shared", "shards_traded", "dark_kept"], "allies", "loop")
	)
	t.check(
		stars.map(func(s): return s["kind"]) == Words.STAR_ORDER,
		"a full telling has all six stars, in the order they were asked"
	)
	t.check(
		stars[2]["option"] == "traded" and stars[2]["whispers"].size() == 2,
		"the shards were traded; two other roads are wondered about"
	)
	t.check(stars[0]["bloom"] == "", "the Bloom says nothing in the second telling")
	var thin := Chronicle.stars_of(_telling(1, ["hunger_held"], "", "exodus"))
	t.check(thin.map(func(s): return s["kind"]) == ["cairn", "hunger", "ending"], "only what happened is drawn")
	t.check(thin[0]["option"] == "unraised", "no cairn is a choice too")
	var sky := Chronicle.sky([_telling(1, [], "neighbours", "exodus"), _telling(2, [], "enemies", "cataclysm")])
	t.check(
		sky.size() == 2 and sky[1]["run"] == 2 and sky[1]["ending"] == "cataclysm", "a constellation for each telling"
	)
	t.check(Chronicle.times_reached(_profile().tellings, "cataclysm") == 1, "and the endings are counted")


func test_the_bloom_speaks_from_the_third_telling() -> void:
	var third := Chronicle.stars_of(_telling(Words.BLOOM_FROM, ["cairn_raised"], "enemies", "cataclysm"))
	t.check(
		third.all(func(s): return s["bloom"] != ""), "every star of the third telling holds a fragment of the Bloom"
	)
	t.check(
		Chronicle.voice_name("bloom") == "The Bloom" and Chronicle.voice_name("sela") == "Sela",
		"and the voices have names"
	)


func test_embers_light_once() -> void:
	var s := Sim.new()
	s.generate(SEED)
	t.check(Chronicle.embers_of(s).is_empty(), "a new run shows no Ember")
	for id in ["hunger_shared", "shards_given", "dark_kept", "old_ship_found", "lean_allies"]:
		s.story.events.append(id)
	s.story.cairn_before_landing = true
	var found := Chronicle.embers_of(s)
	t.check(
		found == ["open_hands", "cairn_first", "lone_fire", "ship_found"],
		"four hidden moments, in their order: %s" % [found]
	)
	s.story.events.append("cairn_raised")
	t.check(not "lone_fire" in Chronicle.embers_of(s), "friends with a cairn are not a rare thing")
	s.carry.dug = ["forge", "lantern", "cart"]
	t.check("three_gifts" in Chronicle.embers_of(s), "all three relics dug out in one telling")
	for id in [
		"name_read",
		"light_read",
		"body_read",
		"growth_read",
		"craft_read",
		"warning_read",
		"ship_read",
		"broke_read",
		"way_read"
	]:
		s.story.events.append(id)
	t.check("whole_word" in Chronicle.embers_of(s), "every set of marks read")
	for id in Chronicle.embers_of(s):
		t.check(
			Words.EMBERS[id]["text"] != "" and Words.VOICES.has(Words.EMBERS[id]["voice"]),
			"%s has a name and a voice" % id
		)
	var p := Profile.new()
	p.bank(s, "exodus")
	t.check(p.embers == Chronicle.embers_of(s), "the profile keeps what was lit")
	var first: Array = p.tellings[0]["embers"]
	t.check(first == p.embers, "the first telling holds them all")
	p.bank(s, "exodus")
	t.check(p.tellings[1]["embers"].is_empty() and p.embers.size() == first.size(), "and no Ember is lit twice")


func test_a_telling_keeps_its_numbers_map_and_embers() -> void:
	var s := Sim.new()
	s.generate(SEED)
	s.seasons.time = 3000.0
	s.tide.lost = 4
	var record := Endings.telling(s, "exodus")
	t.check(record["minutes"] == 50.0 and record["kin"] == s.people.kith.size(), "the numbers: minutes, Kith")
	t.check(
		record["buildings"] == s.town.buildings.size() and record["lost"] == 4, "buildings, and those the Bloom took"
	)
	var map: Dictionary = record["map"]
	var cols := ceili(s.world.width / float(Chronicle.MAP_STRIDE))
	t.check(
		map["rows"].size() == ceili(s.world.height / float(Chronicle.MAP_STRIDE)),
		"the small map has a row for every few tiles"
	)
	t.check(map["rows"].all(func(r): return r.length() == cols), "of the same width")
	var hearth := s.world.camp_pos
	var row: String = map["rows"][int(hearth.y / float(Chronicle.MAP_STRIDE))]
	t.check(row[int(hearth.x / float(Chronicle.MAP_STRIDE))] == "#", "the Hearth shows as a building")
	t.check(Chronicle.numbers_line(record).begins_with("50 minutes"), "the numbers read in one line")
	var saved = Profile.set_out(s, TEMP_PROFILE, "exodus")
	t.check(saved.saved, "the telling is written with the profile")
	var back := Profile.new()
	t.check(back.load_file(TEMP_PROFILE), "and read back")
	t.check(back.tellings[0].has("map") and back.tellings[0]["minutes"] == 50.0, "with its numbers and map")
	t.check(back.embers == saved.embers, "and the Embers lit")


func test_an_older_profile_still_reads() -> void:
	var old := Profile.new()
	(
		t
		. check(
			(
				old
				. from_json(
					'{"version": 3, "chronicle": ["name_read"], "knowledge": [], "runs": 1, "tellings": [{"run": 1, "ending": "exodus"}]}'
				)
			),
			"a profile from before the Chronicle loads"
		)
	)
	t.check(old.embers.is_empty() and Chronicle.numbers_line(old.tellings[0]) == "", "with no Embers and no numbers")
	var sky := Chronicle.sky(old.tellings)
	t.check(sky.size() == 1 and sky[0]["map"].is_empty(), "its sky has the one constellation and no map")
	var book := ChronicleBook.new()
	book.setup()
	book.open(old)
	t.check(book.visible, "and the book opens on it")
	book.free()


func test_every_page_plays_its_scenes_again() -> void:
	var book := ChronicleBook.new()
	book.setup()
	book.open(_profile())
	t.check(book.star_buttons.size() >= 10, "two tellings light their stars")
	for page in PAGES:
		book.show_page(page)
		var mine := book.watch_buttons.filter(func(w): return w["page"] == page)
		t.check(not mine.is_empty(), "the %s page can play a scene again" % page)
		for w in mine:
			t.check(not book.player.active, "nothing plays before the press")
			w["button"].pressed.emit()
			t.check(book.player.active and book.player.current == w["scene"], "%s plays %s" % [page, w["scene"]])
			t.check(Data.CUTSCENES.has(w["scene"]) and not book.player.stills.is_empty(), "with its stills")
			book.player.skip()
	t.check(
		Chronicle.scenes(_profile().chronicle, 2).map(func(s): return s["id"]).has("fireside"),
		"the fireside is among them"
	)
	book.free()


func test_the_book_opens_from_the_menus_and_between_tellings() -> void:
	var book := ChronicleBook.new()
	book.setup()
	var profile := _profile()
	book.open(profile)
	var got := []
	book.closed.connect(func(): got.append("closed"))
	var first_telling = book.star_buttons.filter(func(b): return b["run"] == 1 and b["kind"] == "shards")[0]
	first_telling["button"].pressed.emit()
	t.check(book._selected == {"run": 1, "kind": "shards"}, "a star read")
	var words: Array = book._detail.find_children("*", "Label", true, false).map(func(l): return l.text)
	t.check(
		words.any(func(w): return w.contains("handed us the shards") == false and w.contains("trade")),
		"its road not taken is wondered about"
	)
	book.close()
	t.check(got == ["closed"] and not book.visible, "Close puts it away")
	book.open(profile, "tellings", true)
	t.check(book._close.text == Words.BEGIN, "between tellings the button begins the next one")
	t.check(book._selected["run"] == 2, "on the telling that just ended")
	book.free()
	var menu := PauseMenu.new()
	menu.setup()
	var pressed := []
	menu.chronicle_pressed.connect(func(): pressed.append(1))
	var found := menu.find_children("*", "Button", true, false).filter(func(b): return b.text == Words.TITLE)
	t.check(found.size() == 1, "the pause menu has the Chronicle")
	found[0].pressed.emit()
	t.check(pressed.size() == 1, "and says so")
	menu.free()
	var gm := GameMenu.new()
	var s := Sim.new()
	s.generate(SEED)
	gm.setup(s)
	gm.profile_path = TEMP_PROFILE
	gm.open_chronicle()
	t.check(gm.book.visible and gm.is_open(), "the game menu opens it over the game")
	gm.close()
	t.check(not gm.book.visible, "and Esc puts it away")
	gm.free()


func test_a_scene_replays_in_the_variant_of_its_telling() -> void:
	var book := ChronicleBook.new()
	book.setup()
	book.open(_profile())
	var p = book.player
	p.play("fireside", "exodus", "cataclysm", "enemies")
	t.check(
		p.current == "fireside" and p.stills[0]["art"] == "ending_cataclysm_1",
		"the fireside shows the ending that telling had"
	)
	p.skip()
	p.play("next_telling", "cataclysm", "", "")
	t.check(p.stills[0]["art"] == "next_ruins_1", "and the next land the ending before it led to")
	p.skip()
	p.play("nothing_at_all")
	t.check(not p.active, "an id that is no scene plays nothing")
	t.check(
		book.player.state.story.events.size() <= 1 and book._sim.story.events.size() <= 1, "and nothing is recorded"
	)
	book.free()
