extends RefCounted
## The sound: every file the game plays is there and every file there is played (scripts/sound_mix.gd's tables), the mix keeps a busy
## settlement calm (repeat gaps, voice caps, distance falloff, a crowd that quietens and then thins the everyday sounds, events that
## always get through), the cue bus holds nothing unless something listens, and the volume and mute switches are kept in a file of
## their own. Run from tests/run_tests.gd, which owns check() and the helpers.

const Data = preload("res://scripts/data.gd")
const Mix = preload("res://scripts/sound_mix.gd")
const SoundCues = preload("res://scripts/sound_cues.gd")
const SoundSettings = preload("res://scripts/sound_settings.gd")
const Sound = preload("res://scripts/sound.gd")

const SETTINGS_PATH := "user://test_sound.cfg"

var t  # the runner, tests/run_tests.gd
var _old_path := ""


func run(runner) -> void:
	t = runner
	test_every_file_is_played_and_every_cue_has_its_files()
	test_falloff_with_distance_and_zoom()
	test_a_cue_waits_out_its_gap()
	test_voices_are_capped_per_group()
	test_a_far_sound_is_dropped_and_a_near_one_is_louder()
	test_variants_take_turns()
	test_a_busy_settlement_stays_calm()
	test_events_always_get_through()
	test_loops_fade_with_their_nearest_source()
	test_the_cue_bus_keeps_nothing_unless_listened_to()
	test_gathering_picks_its_sound()
	test_the_blocks_note_their_cues()
	test_the_switches_are_kept_in_their_own_file()
	test_the_sound_node_plays_what_the_mix_allows()


func _files_in(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at("res://audio/" + dir):
		if f.ends_with(".ogg"):
			out.append(f.trim_suffix(".ogg"))
	out.sort()
	return out


func test_every_file_is_played_and_every_cue_has_its_files() -> void:
	var used := {"sfx": {}, "ambience": {}}
	for id in Mix.CUES:
		for f in Mix.CUES[id]["files"]:
			used["sfx"][f] = true
			t.check(FileAccess.file_exists("res://audio/sfx/%s.ogg" % f), "cue %s: sfx/%s.ogg is there" % [id, f])
		t.check(Mix.GROUP_VOICES.has(Mix.CUES[id]["group"]), "cue %s is in a group with a voice cap" % id)
	for id in Mix.LOOPS:
		var def: Dictionary = Mix.LOOPS[id]
		used[def["dir"]][def["file"]] = true
		t.check(FileAccess.file_exists("res://audio/%s/%s.ogg" % [def["dir"], def["file"]]), "loop %s is there" % id)
	for dir in used:
		var have := _files_in(dir)
		var want: Array = used[dir].keys()
		want.sort()
		t.check(have == want, "audio/%s: every file is played and every played file is there (%s)" % [dir, str(have)])


func test_falloff_with_distance_and_zoom() -> void:
	t.check(Mix.near_gain(-1.0) == 1.0, "a sound with no place is heard in full")
	t.check(Mix.near_gain(Mix.FULL_TILES) == 1.0, "a sound inside the near radius is in full")
	t.check(Mix.near_gain(Mix.FAR_TILES) == 0.0, "a sound at the far edge is silent")
	var last := 1.0
	for d in range(10, 36):
		var g := Mix.near_gain(float(d))
		t.check(g <= last and g >= 0.0, "falloff only goes down (%d tiles: %.3f)" % [d, g])
		last = g
	t.check(Mix.near_gain(20.0, 2.0) > Mix.near_gain(20.0), "zoomed out, a sound carries further")
	t.check(Mix.near_gain(20.0, 0.5) < Mix.near_gain(20.0), "zoomed in, it carries less")


func test_a_cue_waits_out_its_gap() -> void:
	var m := Mix.new()
	t.check(not m.request("craft", 0.0, 10.0).is_empty(), "the first craft plays")
	t.check(m.request("craft", 0.0, 10.2).is_empty(), "a craft 0.2 s later is dropped")
	t.check(not m.request("craft", 0.0, 10.5).is_empty(), "a craft after its gap plays")
	t.check(m.request("not_a_cue", 0.0, 11.0).is_empty(), "an unknown cue plays nothing")


func test_voices_are_capped_per_group() -> void:
	var m := Mix.new()
	var played := 0
	for i in 8:  # eight placements 0.2 s apart, each 5 s long: the build group holds four voices
		if not m.request("place", 0.0, float(i) * 0.2, 5.0).is_empty():
			played += 1
	t.check(
		played == int(Mix.GROUP_VOICES["build"]),
		"no more than %d building sounds at once (%d)" % [Mix.GROUP_VOICES["build"], played]
	)
	t.check(m.sounding(1.0) == played, "the mix counts them as sounding")
	t.check(not m.request("place", 0.0, 6.0, 1.0).is_empty(), "when they have finished, building sounds play again")
	t.check(m.sounding(100.0) == 0, "and nothing is sounding long after")


func test_a_far_sound_is_dropped_and_a_near_one_is_louder() -> void:
	var m := Mix.new()
	t.check(m.request("place", 40.0, 0.0).is_empty(), "a building 40 tiles off is not heard")
	var near := m.request("place", 2.0, 1.0)
	var mid := m.request("craft", 20.0, 1.0)
	var close_craft := Mix.new().request("craft", 2.0, 1.0)
	t.check(not near.is_empty() and not mid.is_empty(), "near and middling sounds play")
	t.check(
		mid["db"] < close_craft["db"],
		"the further craft is quieter (%.1f against %.1f dB)" % [mid["db"], close_craft["db"]]
	)


func test_variants_take_turns() -> void:
	var m := Mix.new()
	var seen: Array = []
	for i in 6:
		seen.append(m.request("gather_wood", 0.0, float(i), 0.1)["file"])
	var repeats := 0
	for i in range(1, seen.size()):
		repeats += 1 if seen[i] == seen[i - 1] else 0
	t.check(repeats == 0, "the same gather sound never plays twice running: " + str(seen))
	t.check(seen.size() - repeats > 2, "and more than two of them are heard")


## Sixty everyday sounds in four seconds, spread over every busy cue. The mix lets some through, quietens them, then drops the rest.
func test_a_busy_settlement_stays_calm() -> void:
	var m := Mix.new()
	m.rng.seed = 7
	var everyday := [
		"place", "demolish", "road", "gather_wood", "gather_stone", "gather_berries", "craft", "delivery", "bloom_take"
	]
	var played: Array = []
	for i in 60:
		var go := m.request(everyday[i % everyday.size()], 3.0, float(i) / 15.0, 0.4)
		if not go.is_empty():
			played.append(go)
	t.check(played.size() >= 5, "a busy town is still heard (%d of 60 played)" % played.size())
	t.check(
		played.size() <= Mix.BUSY_PLAYS,
		"but no more than %d everyday sounds in a window (%d)" % [Mix.BUSY_PLAYS, played.size()]
	)
	t.check(played.size() < 40, "far fewer than were asked for (%d of 60)" % played.size())
	var quietest := 0.0
	for go in played:
		quietest = minf(quietest, go["db"])
	t.check(quietest >= -30.0, "none is lost in the mix: the quietest is %.1f dB" % quietest)
	# a crowd takes decibels off the next everyday sound
	var calm := Mix.new().request("place", 0.0, 100.0)
	var crowded := Mix.new()
	for i in Mix.CALM_PLAYS + 4:
		crowded.request(everyday[i % everyday.size()], 0.0, 200.0 + float(i) * 0.3, 0.01)
	var late := crowded.request("place", 0.0, 203.5, 0.01)
	t.check(not late.is_empty() and late["db"] < calm["db"], "a crowd quietens the next everyday sound")
	var after := Mix.new()
	for i in 20:
		after.request("road", 0.0, float(i) * 0.15, 0.01)
	t.check(
		after.request("road", 0.0, 3.1, 0.01).is_empty(),
		"a long run of roads thins out; it is not one long wall of sound"
	)


func test_events_always_get_through() -> void:
	var m := Mix.new()
	for i in 40:  # a flood of everyday sounds, long ones, so every voice is taken
		m.request(["place", "craft", "gather_wood", "bloom_take"][i % 4], 0.0, float(i) * 0.05, 10.0)
	var now := 3.0
	for id in [
		"research_done", "goal_done", "era_bell", "landfall_warn", "glyph", "ending", "card", "refuse", "ui_click"
	]:
		now += 1.5  # one at a time: a group holds a few voices, and each of these is about a second long
		t.check(not m.request(id, -1.0, now).is_empty(), "%s gets through a crowd" % id)


func test_loops_fade_with_their_nearest_source() -> void:
	t.check(Mix.loop_db(-9.0, -1.0, 0) == -80.0, "no sources, no loop")
	t.check(Mix.loop_db(-9.0, 40.0, 3) == -80.0, "a source out of hearing is silent")
	var near := Mix.loop_db(-9.0, 2.0, 1)
	t.check(near == -9.0, "one source in reach plays at its own level (%.1f)" % near)
	t.check(Mix.loop_db(-9.0, 20.0, 1) < near, "a further one is quieter")
	t.check(Mix.loop_db(-9.0, 2.0, 8) <= near + 3.0 + 0.001, "a crowd of sources adds no more than 3 dB")
	t.check(Mix.loop_db(-9.0, 2.0, 100) <= near + 3.0 + 0.001, "however big the crowd")
	t.check(Mix.loop_db(-9.0, 2.0, 4) > near, "but a few are louder than one")


func test_the_cue_bus_keeps_nothing_unless_listened_to() -> void:
	SoundCues.listening = false
	SoundCues.clear()
	SoundCues.add("craft", Vector2i(3, 4))
	t.check(SoundCues.take().is_empty(), "nothing is kept while nobody listens")
	SoundCues.listening = true
	SoundCues.add("craft", Vector2i(3, 4))
	SoundCues.add("goal_done")
	var got := SoundCues.take()
	t.check(
		got.size() == 2 and got[0]["id"] == "craft" and got[0]["at"] == Vector2i(3, 4),
		"cues come out in order, with their tile"
	)
	t.check(got[1]["at"] == Vector2i(-1, -1), "a cue with no place says so")
	t.check(SoundCues.take().is_empty(), "taking them forgets them")
	for i in SoundCues.CAP + 20:
		SoundCues.add("craft", Vector2i(i, 0))
	var burst := SoundCues.take()
	t.check(
		burst.size() == SoundCues.CAP and burst[-1]["at"].x == SoundCues.CAP + 19,
		"a burst keeps the newest %d" % SoundCues.CAP
	)
	SoundCues.listening = false


func test_gathering_picks_its_sound() -> void:
	SoundCues.listening = true
	SoundCues.clear()
	for item in ["wood", "flint", "copper_ore", "berries", "fiber", "charcoal"]:
		SoundCues.gather(item, Vector2i(1, 1))
	var ids: Array = SoundCues.take().map(func(c): return c["id"])
	t.check(
		ids == ["gather_wood", "gather_stone", "gather_stone", "gather_berries", "gather_berries", "gather_wood"],
		"wood chops, rock knocks, the rest is picked: " + str(ids)
	)
	SoundCues.listening = false


## The blocks say what they do, and name a tile where it has one.
func test_the_blocks_note_their_cues() -> void:
	var s: Object = t.fresh()
	SoundCues.listening = true
	SoundCues.clear()
	s.hauling.log_trip(s, Vector2i(1, 1), Vector2i(2, 2), "wood", 3)
	var got := SoundCues.take()
	t.check(
		got.size() == 1 and got[0]["id"] == "delivery" and got[0]["at"] == Vector2i(2, 2),
		"a delivery is heard where it lands"
	)
	for cue in got:
		t.check(Mix.CUES.has(cue["id"]), "%s is a cue the mix knows" % cue["id"])
	t.check(
		s.tide.fire_tiles() is Array and s.tide.lamp_tiles() is Array,
		"the tide names its Scorchers and Arc Lamps for their sound"
	)
	SoundCues.listening = false
	SoundCues.clear()


func test_the_switches_are_kept_in_their_own_file() -> void:
	_old_path = SoundSettings.path
	SoundSettings.path = SETTINGS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	SoundSettings.reset()
	t.check(
		is_equal_approx(SoundSettings.master(), SoundSettings.DEFAULT_MASTER), "the master volume starts at its default"
	)
	t.check(
		SoundSettings.sfx() == 1.0 and SoundSettings.ambience() == 1.0 and not SoundSettings.muted(),
		"effects and ambience are full, and sound is on"
	)
	SoundSettings.set_master(0.4)
	SoundSettings.set_sfx(7.0)  # past the end: kept at full
	SoundSettings.set_ambience(-1.0)
	SoundSettings.set_muted(true)
	SoundSettings.reset()  # forget what was read: the next read comes from the file
	t.check(is_equal_approx(SoundSettings.master(), 0.4), "the master volume is kept")
	t.check(SoundSettings.sfx() == 1.0 and SoundSettings.ambience() == 0.0, "levels are kept between 0 and 1")
	t.check(SoundSettings.muted(), "mute is kept")
	t.check(FileAccess.file_exists(SETTINGS_PATH), "in a file of their own under user://")
	t.check(
		SoundSettings.db_of(1.0) == 0.0 and SoundSettings.db_of(0.0) == -80.0, "the slider's ends are full and silent"
	)
	t.check(
		is_equal_approx(SoundSettings.db_of(0.5), linear_to_db(0.5)), "and the middle is a straight line in loudness"
	)
	var master := AudioServer.get_bus_index("Master")
	t.check(
		AudioServer.get_bus_index("Sfx") >= 0 and AudioServer.get_bus_index("Ambience") >= 0,
		"the Sfx and Ambience buses exist"
	)
	t.check(AudioServer.is_bus_mute(master), "mute silences the master bus")
	t.check(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")) == -80.0,
		"an ambience level of 0 silences its bus"
	)
	SoundSettings.set_muted(false)
	t.check(not AudioServer.is_bus_mute(master), "and unmuting brings it back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	SoundSettings.path = _old_path
	SoundSettings.reset()
	SoundSettings.apply()


func test_the_sound_node_plays_what_the_mix_allows() -> void:
	var node := Sound.new()  # not in the tree: nothing can sound, but what the mix refuses is refused first
	node.listener = Vector2(10, 10)
	t.check(not node.play("not_a_cue"), "an unknown cue does not play")
	t.check(not node.play("place", Vector2i(90, 90)), "a building far from the view is not heard")
	node.free()
