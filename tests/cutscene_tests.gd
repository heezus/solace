extends RefCounted
## The cutscene player (design-system/20-cutscenes.md): the data of Data.CUTSCENES, the triggers that queue a sequence, the order
## they play in, pausing the game, skipping, the lines-over-dark fallback for a still not painted yet, the variants by how the
## strangers came and how the era ended, the echo lines and memory overlays an earlier run earns, and the on/off setting.
## It drives the player's logic without drawing. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Sim = preload("res://scripts/sim.gd")
const CutscenePlayer = preload("res://scripts/cutscene_player.gd")
const CutsceneSettings = preload("res://scripts/cutscene_settings.gd")

const PHASE_A := ["opening", "bronze_dawn", "falling_star", "first_contact", "starfall_end"]
const PAINTED := PHASE_A  # the sequences whose stills exist in art/rendered/cutscenes
const SETTINGS_PATH := "user://test_cutscenes.cfg"

var t  # the runner, tests/run_tests.gd


class FakeHost:
	extends RefCounted
	var paused := false


func run(runner) -> void:
	t = runner
	test_the_data_is_well_formed()
	test_every_phase_a_still_is_painted()
	test_the_setting_is_kept_apart()
	test_a_fresh_run_opens_and_a_loaded_one_does_not()
	test_story_moments_queue_their_sequence()
	test_sequences_play_in_order_and_the_bloom_waits()
	test_a_sequence_pauses_the_game_and_gives_it_back()
	test_a_sequence_runs_its_stills_and_ends()
	test_skipping_leaves_the_story_as_it_was()
	test_a_still_without_a_painting_shows_its_line()
	test_variants_follow_the_story()
	test_an_earlier_run_is_echoed_by_one_line_and_some_overlays()
	test_cutscenes_off_plays_nothing()
	test_keys_and_clicks_skip()
	test_the_last_still_ending_in_a_frame_lays_nothing_out()
	test_tools_can_switch_the_player_off()


## A player over a fresh game, with `prior` standing in for the profile; the player is in the tree when `in_tree`.
func player_for(s: Sim, host, prior := [], in_tree := false) -> Node:
	var p = CutscenePlayer.new()
	if in_tree:
		t.root.add_child(p)
	p.setup(s, host, prior)
	return p


func finish(p: Node) -> void:
	p.free()


func test_the_data_is_well_formed() -> void:
	t.check(
		Data.CUTSCENES.keys() == PHASE_A + ["ironfall", "bloom_sign"], "the seven sequences, in the order they play"
	)
	var triggers := {}
	for id in Data.CUTSCENES:
		var def: Dictionary = Data.CUTSCENES[id]
		t.check(def["stills"].size() >= 2 and def["stills"].size() <= 4, "%s has 2 to 4 stills" % id)
		for trigger in def["triggers"]:
			t.check(trigger == "start" or Data.STORY_EVENTS.has(trigger), "%s: %s is a story id" % [id, trigger])
			t.check(not triggers.has(trigger), "%s: %s starts one sequence only" % [id, trigger])
			triggers[trigger] = id
		t.check(def.get("after", "") == "" or Data.STORY_EVENTS.has(def["after"]), "%s waits for a real moment" % id)
		for still in def["stills"]:
			t.check(still["line"] != "" and still["line"].length() <= 70, "%s: a short line: %s" % [id, still["line"]])
			t.check(still["art"].begins_with(id + "_"), "%s: its art is named for it (%s)" % [id, still["art"]])
			for key in still.get("variants", {}):
				t.check(def.has("by"), "%s: a variant needs something to pick it" % id)
	for row in Data.CUTSCENE_VARIANT_LINES:
		t.check(Data.CUTSCENES.has(row["seq"]), "a variant line is for a sequence that exists (%s)" % row["seq"])
		t.check(row["still"] < Data.CUTSCENES[row["seq"]]["stills"].size(), "and for a still it has")
		t.check(row["needs"] != "" and row["line"].length() <= 70, "and is short")
	t.check(Data.CUTSCENE_MEMORY.size() == 5, "five memory overlays")


func test_every_phase_a_still_is_painted() -> void:
	for id in PAINTED:
		for still in Data.CUTSCENES[id]["stills"]:
			var arts: Array = [still["art"]]
			for v in still.get("variants", {}).values():
				arts.append(v.get("art", still["art"]))
			for art in arts:
				t.check(ResourceLoader.exists(Data.CUTSCENE_ART_DIR + art + ".png"), "%s is painted" % art)
	for m in Data.CUTSCENE_MEMORY:
		t.check(ResourceLoader.exists(Data.CUTSCENE_ART_DIR + m["overlay"] + ".png"), "%s is painted" % m["overlay"])


func test_the_setting_is_kept_apart() -> void:
	var old_path := CutsceneSettings.path
	CutsceneSettings.path = SETTINGS_PATH
	DirAccess.remove_absolute(SETTINGS_PATH)
	CutsceneSettings.reset()
	t.check(CutsceneSettings.on(), "cutscenes are on until the player says otherwise")
	CutsceneSettings.set_on(false)
	CutsceneSettings.reset()
	t.check(not CutsceneSettings.on(), "and a choice to turn them off is kept in its file")
	CutsceneSettings.set_on(true)
	CutsceneSettings.reset()
	t.check(CutsceneSettings.on(), "and turned on again")
	t.check(
		CutsceneSettings.path != "user://profile.json" and not CutsceneSettings.path.contains("run"),
		"it is no part of a save"
	)
	DirAccess.remove_absolute(SETTINGS_PATH)
	CutsceneSettings.path = old_path
	CutsceneSettings.reset()


func test_a_fresh_run_opens_and_a_loaded_one_does_not() -> void:
	var s: Sim = t.fresh()
	t.check(CutscenePlayer.is_fresh_run(s), "a new camp is a fresh run")
	var p := player_for(s, FakeHost.new())
	t.check(p.queue == ["opening"], "and its opening is waiting")
	finish(p)
	var mid: Sim = t.fresh()
	mid.story.record("first_lesson")
	t.check(not CutscenePlayer.is_fresh_run(mid), "a run with something told is not fresh")
	p = player_for(mid, FakeHost.new())
	t.check(p.queue.is_empty(), "so a loaded game does not play its opening again")
	finish(p)
	var learned: Sim = t.fresh()
	learned.tech_tree.researched["fire"] = true
	t.check(not CutscenePlayer.is_fresh_run(learned), "nor does a run that has learned something")


func test_story_moments_queue_their_sequence() -> void:
	var s: Sim = t.fresh()
	s.story.record("first_lesson")
	var p := player_for(s, FakeHost.new())
	var expect := {
		"bronze_dawn": "bronze_dawn",
		"star_falling": "falling_star",
		"lumen_arrived": "first_contact",
		"lean_neighbours": "starfall_end",
		"ironfall_begun": "ironfall",
	}
	for id in expect:
		p.queue.clear()
		s.story.record(id)
		t.check(p.queue == [expect[id]], "%s starts %s" % [id, expect[id]])
	p.queue.clear()
	s.story.record("bloom_seen")
	t.check(p.queue == ["bloom_sign"], "bloom_seen queues the Bloom sign")
	finish(p)


func test_sequences_play_in_order_and_the_bloom_waits() -> void:
	var s: Sim = t.fresh()
	s.story.record("first_lesson")
	var p := player_for(s, FakeHost.new())
	s.story.record("bloom_seen")
	s.story.record("lean_allies")
	t.check(p.queue == ["starfall_end", "bloom_sign"], "the ending comes before the Bloom sign (%s)" % [p.queue])
	t.check(p.start_next() and p.current == "starfall_end", "the ending plays first")
	p.skip()
	t.check(not p.start_next() and p.queue == ["bloom_sign"], "the Bloom sign waits for Ironfall")
	s.story.record("ironfall_begun")
	t.check(p.queue == ["ironfall", "bloom_sign"], "Ironfall joins ahead of it (%s)" % [p.queue])
	t.check(p.start_next() and p.current == "ironfall", "and plays first")
	p.skip()
	t.check(p.start_next() and p.current == "bloom_sign", "then the Bloom sign plays")
	p.skip()
	t.check(p.played == ["starfall_end", "ironfall", "bloom_sign"], "each played once, in order")
	s.story.record("lean_enemies")
	p.enqueue("starfall_end")
	t.check(p.queue.is_empty(), "and none plays twice in a run")
	finish(p)


func test_a_sequence_pauses_the_game_and_gives_it_back() -> void:
	for was in [false, true]:
		var s: Sim = t.fresh()
		s.story.record("first_lesson")
		var host := FakeHost.new()
		host.paused = was
		var p := player_for(s, host)
		p.enqueue("bronze_dawn")
		t.check(not p.active, "nothing plays until the player gets a frame")
		p._process(0.1)
		t.check(p.active and host.paused, "a sequence holds the game paused")
		host.paused = false  # something unpaused it (a card closing): the player pauses again
		p.advance(0.1)
		t.check(host.paused, "and keeps holding it")
		p.skip()
		t.check(not p.active and host.paused == was, "the game is back as it was (paused: %s)" % was)
		finish(p)


func test_a_sequence_runs_its_stills_and_ends() -> void:
	var s: Sim = t.fresh()
	s.story.record("first_lesson")
	var host := FakeHost.new()
	var p := player_for(s, host)
	var ended := []
	p.finished.connect(func(id, skipped): ended.append([id, skipped]))
	p.enqueue("falling_star")
	p.start_next()
	var seen := []
	var elapsed := 0.0
	while p.active and elapsed < 100.0:
		if p.index >= seen.size():
			seen.append(p._caption.text)
		p.advance(0.5)
		elapsed += 0.5
	t.check(seen.size() == 4, "the four stills showed in turn (%d)" % seen.size())
	t.check(seen[0] == "A star came down." and seen[3] == "In the morning, the silence began.", "with their lines")
	t.check(is_equal_approx(elapsed, 4.0 * Data.CUTSCENE_STILL_SECONDS), "each for its time (%.1f s)" % elapsed)
	t.check(ended == [["falling_star", false]] and not host.paused, "then it ends, not skipped, and the game goes on")
	p.enqueue("falling_star")
	p.start_next()
	p.still_time = 0.0
	t.check(p.envelope() == 0.0, "a still fades in from black")
	p.still_time = Data.CUTSCENE_STILL_SECONDS * 0.5
	t.check(p.envelope() == 1.0, "holds")
	p.still_time = Data.CUTSCENE_STILL_SECONDS - 0.01
	t.check(p.envelope() < 0.1, "and fades out to black")
	finish(p)


func test_skipping_leaves_the_story_as_it_was() -> void:
	var s: Sim = t.fresh()
	s.story.record("first_lesson")
	var p := player_for(s, FakeHost.new())
	var ended := []
	p.finished.connect(func(id, skipped): ended.append([id, skipped]))
	s.story.record("bronze_dawn")
	var events_before: Array = s.story.events.duplicate()
	p.start_next()
	p.skip()
	t.check(ended == [["bronze_dawn", true]], "a skip says it was skipped")
	t.check(
		s.story.events == events_before and s.story.has_event("bronze_dawn"),
		"and the story id is recorded all the same"
	)
	t.check("bronze_dawn" in p.played, "the sequence counts as seen")
	p.skip()
	t.check(ended.size() == 1, "skipping with nothing playing does nothing")
	finish(p)


func test_a_still_without_a_painting_shows_its_line() -> void:
	var s: Sim = t.fresh()
	s.story.record("first_lesson")
	var p := player_for(s, FakeHost.new())
	t.check(
		p.texture("ironfall_1") == null and p.texture("bloom_sign_2") == null, "the Ironfall stills are not painted yet"
	)
	t.check(p.texture("opening_1") != null, "the opening's is")
	s.story.record("ironfall_begun")
	p.start_next()
	t.check(p.active and p.current == "ironfall", "the sequence plays all the same")
	t.check(p._caption.text == "Iron, and a way to open things.", "with its line")
	p._process(0.1)
	t.check(p._caption.modulate.a >= 0.0 and p.active, "and lays its caption out with no picture")
	for i in 3:
		p.advance(Data.CUTSCENE_STILL_SECONDS)
	t.check(not p.active, "and ends on time")
	finish(p)


func test_variants_follow_the_story() -> void:
	var s: Sim = t.fresh()
	s.story.record("first_lesson")
	var p := player_for(s, FakeHost.new())
	var wary: Array = p.resolve("first_contact")
	t.check(
		wary[0]["art"] == "first_contact_1" and wary[0]["line"].begins_with("Three strangers came out of the fog"),
		"wary"
	)
	s.starfall.guests = true
	var guests: Array = p.resolve("first_contact")
	t.check(
		guests[0]["art"] == "first_contact_1_guests" and guests[0]["line"].contains("as guests"),
		"guests, the first still"
	)
	t.check(guests[1] == wary[1] and guests[2] == wary[2], "and only the first still changes")
	for lean in ["neighbours", "allies", "enemies"]:
		s.starfall.lean = lean
		var end: Array = p.resolve("starfall_end")
		t.check(end[2]["art"] == "starfall_end_3_%s" % lean, "the last still of the ending is the %s one" % lean)
		t.check(end[0]["art"] == "starfall_end_1" and end.size() == 3, "after the same two")
	s.starfall.lean = "allies"
	t.check(p.resolve("starfall_end")[2]["line"] == "They stopped counting whose fire it was.", "and its line")
	t.check(
		(
			p.resolve("opening")
			== Data.CUTSCENES["opening"]["stills"].map(func(x): return {"art": x["art"], "line": x["line"]})
		),
		"a sequence with no variants plays as written"
	)
	finish(p)


func test_an_earlier_run_is_echoed_by_one_line_and_some_overlays() -> void:
	var s: Sim = t.fresh()
	s.story.record("first_lesson")
	var plain := player_for(s, FakeHost.new())
	t.check(plain.memory_overlays().is_empty(), "a first run draws no memory overlays")
	var base: Array = plain.resolve("first_contact")
	finish(plain)
	var p := player_for(s, FakeHost.new(), ["name_read", "bloom_seen"])
	var echoed: Array = p.resolve("first_contact")
	t.check(
		echoed[2]["line"] == "She said a word. This time a few of the Kith knew it.",
		"a read glyph set changes the third line"
	)
	t.check(echoed[0] == base[0] and echoed[1] == base[1] and echoed[2]["art"] == base[2]["art"], "and nothing else")
	t.check(
		p.resolve("bloom_sign")[0]["line"].ends_with("had seen it before."),
		"a Bloom echo changes the Bloom sign's first line"
	)
	t.check(
		p.memory_overlays() == ["memory_glyph", "memory_bloom"],
		"and each echo adds its overlay (%s)" % [p.memory_overlays()]
	)
	t.check(p.resolve("opening")[1]["line"] == base_line("opening", 1), "the opening is untouched: no reset yet")
	finish(p)
	# What this run has already told is not an echo of an earlier one.
	var told: Sim = t.fresh()
	told.story.record("name_read")
	var again := player_for(told, FakeHost.new(), ["name_read"])
	t.check(again.prior.is_empty() and again.memory_overlays().is_empty(), "a run does not echo itself")
	finish(again)
	# The reset hook: the ids no run records yet. Never more than one line of a sequence is swapped.
	var reset := player_for(s, FakeHost.new(), ["reset_exodus", "reset_loop"])
	var opening: Array = reset.resolve("opening")
	var swapped := 0
	for i in opening.size():
		if opening[i]["line"] != base_line("opening", i):
			swapped += 1
	t.check(
		swapped == 1 and opening[1]["line"] == "They raised a fire, the way they remembered.", "a reset swaps one line"
	)
	t.check(reset.memory_overlays() == ["memory_exodus", "memory_loop"], "and brings its overlays")
	finish(reset)


func base_line(id: String, still: int) -> String:
	return Data.CUTSCENES[id]["stills"][still]["line"]


func test_cutscenes_off_plays_nothing() -> void:
	var old_path := CutsceneSettings.path
	CutsceneSettings.path = SETTINGS_PATH
	DirAccess.remove_absolute(SETTINGS_PATH)
	CutsceneSettings.reset()
	CutsceneSettings.set_on(false)
	var s: Sim = t.fresh()
	var host := FakeHost.new()
	var p := player_for(s, host)
	t.check(p.queue.is_empty(), "with cutscenes off a fresh run queues no opening")
	s.story.record("bronze_dawn")
	t.check(p.queue.is_empty() and not p.start_next(), "nor does a story moment")
	t.check(
		s.story.has_event("bronze_dawn") and not host.paused, "the story is told all the same and the game never waits"
	)
	CutsceneSettings.set_on(true)
	p.enqueue("ironfall")
	CutsceneSettings.set_on(false)
	t.check(not p.start_next() and p.queue.is_empty(), "a sequence waiting when they are switched off is dropped")
	finish(p)
	DirAccess.remove_absolute(SETTINGS_PATH)
	CutsceneSettings.path = old_path
	CutsceneSettings.reset()


func test_keys_and_clicks_skip() -> void:
	var s: Sim = t.fresh()
	s.story.record("first_lesson")
	var host := FakeHost.new()
	var p := player_for(s, host, [], true)
	for key in [KEY_ESCAPE, KEY_SPACE]:
		p.enqueue("bronze_dawn" if key == KEY_ESCAPE else "ironfall")
		p.start_next()
		var press := InputEventKey.new()
		press.keycode = key
		press.pressed = true
		p._input(press)
		t.check(not p.active and not host.paused, "key %s skips" % OS.get_keycode_string(key))
	p.enqueue("falling_star")
	p.start_next()
	var other := InputEventKey.new()
	other.keycode = KEY_A
	other.pressed = true
	p._input(other)
	t.check(p.active, "another key does not")
	var echo := InputEventKey.new()
	echo.keycode = KEY_ESCAPE
	echo.pressed = true
	echo.echo = true
	p._input(echo)
	t.check(p.active, "nor does a held key repeating")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	p._input(click)
	t.check(p.active, "a click right at the start is ignored (it began the moment)")
	p.advance(Data.CUTSCENE_SKIP_GRACE + 0.1)
	p._input(click)
	t.check(not p.active and "falling_star" in p.played, "a click after that skips")
	p._input(click)
	t.check(not p.active, "and with nothing playing it is no business of the player's")
	finish(p)


func test_the_last_still_ending_in_a_frame_lays_nothing_out() -> void:
	var s: Sim = t.fresh()
	s.story.record("first_lesson")
	var p := player_for(s, FakeHost.new())
	s.story.record("ironfall_begun")
	p.start_next()
	var stills: int = p.stills.size()
	for i in stills:
		p._process(Data.CUTSCENE_STILL_SECONDS + 0.1)  # the frame that ends the sequence must not index past its stills
	t.check(not p.active and "ironfall" in p.played, "a sequence ended by a frame's own clock ends cleanly")
	finish(p)


func test_tools_can_switch_the_player_off() -> void:
	var s: Sim = t.fresh()
	var layer := Node.new()
	var made = CutscenePlayer.attach(layer, s, FakeHost.new(), [])
	t.check(made != null and made.get_parent() == layer, "attach puts a player on the layer")
	CutscenePlayer.suppress = true
	t.check(CutscenePlayer.attach(layer, s, FakeHost.new(), []) == null, "and with suppress set it makes none")
	CutscenePlayer.suppress = false
	layer.free()
