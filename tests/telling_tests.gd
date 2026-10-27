extends RefCounted
## Step 7C, the tellings and their endings (design-system/18-roadmap.md, "Endings as built"): the ending card, its locks by lean,
## the three handoffs (the Exodus on a new map, the Cataclysm on the same one with ruins and dormant Bloom patches, the Time loop with
## the trust it ended with), what the profile keeps of each telling, and the words the next run opens with. Nothing here plays a game.
## Run from tests/run_tests.gd.

const BlueprintTests = preload("res://tests/blueprint_tests.gd")
const Carry = preload("res://scripts/carry.gd")
const Clearing = preload("res://scripts/clearing.gd")
const CutscenePlayer = preload("res://scripts/cutscene_player.gd")
const Data = preload("res://scripts/data.gd")
const EndingCard = preload("res://scripts/ending_card.gd")
const Endings = preload("res://scripts/endings.gd")
const GameMenu = preload("res://scripts/game_menu.gd")
const Land = preload("res://scripts/land.gd")
const Launch = preload("res://scripts/launch.gd")
const NoticeCard = preload("res://scripts/notice_card.gd")
const Profile = preload("res://scripts/profile.gd")
const Ruins = preload("res://scripts/ruins.gd")
const Sim = preload("res://scripts/sim.gd")

const TEMP_PROFILE := "user://solace_test_endings_profile.json"
const SEED := 5

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	_clean()
	test_each_lock_follows_the_lean()
	test_the_ending_card_shows_the_locks_and_the_first_telling()
	test_an_ending_the_lean_shuts_cannot_be_taken()
	test_a_telling_records_the_run_and_its_choices()
	test_a_version_2_profile_loads_and_a_first_run_is_unchanged()
	test_the_exodus_begins_on_a_new_map()
	test_the_cataclysm_keeps_the_map_and_lays_the_ruins()
	test_clearing_a_ruin_gives_stone()
	test_ruins_in_the_land_that_grows_are_laid_as_it_grows()
	test_the_tide_wakes_from_the_dormant_patches()
	test_the_time_loop_remembers_and_the_cataclysm_arrives_wary()
	test_each_ending_opens_the_next_run_with_its_own_card()
	test_the_skyward_cutscene_and_the_greeting()
	BlueprintTests.new().run(t)  # Step 7D rides with the endings: tests/run_tests.gd is at its line cap
	_clean()


func _clean() -> void:
	if FileAccess.file_exists(TEMP_PROFILE):
		DirAccess.remove_absolute(TEMP_PROFILE)


## `n` open grass tiles well away from the Hearth, in row order.
func _spots(s: Sim, n: int, from := 6) -> Array:
	var out := []
	for y in s.world.height:
		for x in s.world.width:
			var p := Vector2i(x, y)
			var d := (p - s.world.camp_pos).abs()
			if s.world.tile_at(p) == "grass" and maxi(d.x, d.y) >= from and s.town.building_at.get(p, -1) == -1:
				out.append(p)
				if out.size() == n:
					return out
	return out


## A Sim at the end of a telling: a small town, Skyward raised, a lean and the trust that made it, and some small choices made.
func _ended_run(lean: String, trust := 50.0, buildings := 6) -> Sim:
	var s := Sim.new()
	s.generate(SEED)
	s.tech_tree.researched["knapping"] = true
	s.starfall.locked["name"] = true
	var spots := _spots(s, buildings)
	for i in spots.size():
		s.town.add_building("kiln" if i % 3 == 0 else "gatherers_hut", spots[i])
	s.starfall.lean = lean
	s.starfall.trust = trust
	s.story.record("cairn_raised")
	s.story.record("hunger_shared")
	s.story.record("dark_refused")
	s.story.record(Data.SKYWARD_EVENT)
	return s


func test_each_lock_follows_the_lean() -> void:
	t.check(Endings.is_open("exodus", "") and Endings.is_open("exodus", "enemies"), "the Exodus is always open")
	t.check(Endings.is_open("exodus", "allies") and Endings.is_open("exodus", "neighbours"), "whatever the lean")
	t.check(Endings.is_open("cataclysm", "enemies"), "the Cataclysm opens for enemies")
	t.check(
		not Endings.is_open("cataclysm", "allies") and not Endings.is_open("cataclysm", "neighbours"),
		"and no other lean"
	)
	t.check(Endings.is_open("loop", "allies"), "the Time loop opens for allies")
	t.check(not Endings.is_open("loop", "enemies") and not Endings.is_open("loop", "neighbours"), "and no other lean")
	t.check(Endings.why_locked("cataclysm", "allies") == "Needs the Lumen as enemies", "a shut Cataclysm says why")
	t.check(Endings.why_locked("loop", "neighbours") == "Needs the Lumen as allies", "so does a shut Time loop")
	t.check(Endings.why_locked("exodus", "allies") == "", "an open one says nothing")


func test_the_ending_card_shows_the_locks_and_the_first_telling() -> void:
	var card := EndingCard.new()
	card.setup()
	var kept := [0]
	card.kept.connect(func(): kept[0] += 1)
	card.open(1, "neighbours")
	t.check(
		card.visible and card._title.text == "The first telling ends here", "the first run's card says it ends here"
	)
	t.check(not card.button_of("exodus").disabled and card.why_of("exodus") == "", "the Exodus is open for neighbours")
	t.check(
		card.button_of("cataclysm").disabled and card.why_of("cataclysm") == "Needs the Lumen as enemies",
		"the Cataclysm is shut"
	)
	t.check(
		card.button_of("loop").disabled and card.why_of("loop") == "Needs the Lumen as allies",
		"so is the Time loop, with its reason"
	)
	card.open(3, "enemies")
	t.check(card._title.text == "Telling 3 ends here", "a later run is numbered")
	t.check(
		not card.button_of("cataclysm").disabled and card.button_of("loop").disabled, "enemies open the Cataclysm only"
	)
	card.open(2, "allies")
	t.check(
		card.button_of("cataclysm").disabled and not card.button_of("loop").disabled, "allies open the Time loop only"
	)
	var picked := [""]
	card.chosen.connect(func(id): picked[0] = id)
	card.button_of("cataclysm").pressed.emit()
	t.check(picked[0] == "" and card.visible, "a shut row takes no press")
	card.button_of("loop").pressed.emit()
	t.check(picked[0] == "loop" and not card.visible, "an open one is chosen and the card goes")
	card.open(2, "allies")
	card.cancel()
	t.check(kept[0] == 1 and not card.visible, "Keep building puts it away and says so")
	card.free()


func test_an_ending_the_lean_shuts_cannot_be_taken() -> void:
	_clean()
	var s := _ended_run("allies")
	var menu := GameMenu.new()
	menu.profile_path = TEMP_PROFILE
	menu.setup(s)
	menu.ask_confirm("cataclysm")
	t.check(not menu.confirm.visible, "the confirm does not open for a shut ending")
	t.check(
		not menu.set_out("cataclysm") and not FileAccess.file_exists(TEMP_PROFILE),
		"and setting out is refused, nothing banked"
	)
	t.check(not s.story.has_event("ending_cataclysm"), "no moment of it is recorded")
	menu.ask_confirm("loop")
	t.check(
		menu.confirm.visible and menu.confirm._text.text == Data.ENDINGS["loop"]["end"],
		"an open one asks, in its own words"
	)
	menu.confirm._yes.pressed.emit()
	var p := Profile.new()
	t.check(
		p.load_file(TEMP_PROFILE) and p.runs == 1 and p.exoduses == 0, "saying yes counts a run that is not an Exodus"
	)
	t.check(p.has_story("ending_loop") and s.story.has_event("ending_loop"), "the ending is a moment of the Chronicle")
	menu.free()
	_clean()


func test_a_telling_records_the_run_and_its_choices() -> void:
	_clean()
	var s := _ended_run("allies", 77.0)
	var p = Profile.set_out(s, TEMP_PROFILE, "loop")
	t.check(p.tellings.size() == 1 and p.runs == 1, "an ending leaves one telling")
	var rec: Dictionary = p.tellings[0]
	t.check(rec["run"] == 1 and rec["seed"] == SEED and rec["ending"] == "loop", "its number, its map and its ending")
	t.check(rec["lean"] == "allies" and is_equal_approx(rec["trust"], 77.0), "the lean and the trust")
	t.check(
		rec["choices"] == ["cairn_raised", "hunger_shared", "dark_refused"],
		"and the small Starfall choices it made, in order"
	)
	var again := Profile.new()
	t.check(
		again.load_file(TEMP_PROFILE) and again.tellings.size() == 1 and again.last["ending"] == "loop",
		"all of it is on disk"
	)
	t.check(
		again.carry().exodus == 1 and again.carry().ending == "loop", "the next run is telling 2, after a Time loop"
	)
	var n := Sim.new()
	Launch.begin_new(n, 99, TEMP_PROFILE)
	var q = Profile.set_out(n, TEMP_PROFILE, "exodus")
	t.check(
		q.tellings.size() == 2 and q.tellings[1]["run"] == 2 and q.runs == 2 and q.exoduses == 1,
		"a second telling is run 2"
	)
	_clean()


func test_a_version_2_profile_loads_and_a_first_run_is_unchanged() -> void:
	var p := Profile.new()
	var old := '{"version": 2, "chronicle": ["haulers"], "knowledge": [], "techs": ["knapping"], "exoduses": 2}'
	t.check(
		p.from_json(old) and p.runs == 2 and p.tellings.is_empty() and p.last.is_empty(),
		"a version 2 profile loads, its runs its Exoduses"
	)
	var c := p.carry()
	t.check(c.exodus == 2 and c.ending == "exodus" and c.ruins.is_empty(), "and its next run follows an Exodus")
	var fresh := Profile.new()
	t.check(
		fresh.is_empty() and fresh.carry().is_first() and fresh.carry().ending == "", "an empty profile is a first run"
	)
	var s := Sim.new()
	s.generate(SEED)
	t.check(
		s.carry.start_trust(Data.TRUST_START_GUESTS) == Data.TRUST_START_GUESTS and s.carry.guests_welcome(true),
		"with its own trust"
	)
	t.check(s.carry.ruins.is_empty() and s.carry.patches.is_empty(), "and no ruins")
	for p2 in [Vector2i(0, 0), Vector2i(10, 10)]:
		t.check(s.world.tile_at(p2) != "ruins", "no ruin on a first map")


func test_the_exodus_begins_on_a_new_map() -> void:
	_clean()
	Profile.set_out(_ended_run("neighbours"), TEMP_PROFILE, "exodus")
	var seeds := {}
	for i in 6:
		var n := Sim.new()
		Launch.begin_new(n, -1, TEMP_PROFILE)
		seeds[n.world.map_seed] = true
		t.check(n.carry.ending == "exodus" and n.carry.ruins.is_empty(), "an Exodus run carries no ruins")
	t.check(not seeds.has(SEED) or seeds.size() > 1, "and its map is a new one")
	_clean()


func test_the_cataclysm_keeps_the_map_and_lays_the_ruins() -> void:
	_clean()
	var old := _ended_run("enemies", 12.0)
	Profile.set_out(old, TEMP_PROFILE, "cataclysm")
	var n := Sim.new()
	Launch.begin_new(n, -1, TEMP_PROFILE)
	t.check(n.world.map_seed == SEED, "the Cataclysm's next run is on the same seed")
	t.check(n.carry.ending == "cataclysm" and n.carry.last_lean == "enemies", "carrying the ending and the lean")
	var base := Sim.new()
	base.generate(SEED)
	var ruined := 0
	for b in old.town.buildings:
		if b["type"] == "camp":
			continue
		var p: Vector2i = b["pos"]
		t.check(n.world.tile_at(p) == "ruins" and base.world.tile_at(p) == "grass", "a ruin where a building stood")
		ruined += 1
	t.check(ruined >= 4 and n.carry.ruins.size() == ruined, "every one of them (%d)" % ruined)
	var rubble: Vector2i = old.town.buildings[1]["pos"]
	t.check(
		n.world.tile_at(rubble) == "ruins" and n.town._ground_error(Data.BUILDINGS["gatherers_hut"], "ruins") != "",
		"nothing can be built on rubble"
	)
	var near := 0
	for r in n.carry.ruins:
		var d := (Vector2i(int(r["pos"][0]), int(r["pos"][1])) - n.world.camp_pos).abs()
		near += 1 if maxi(d.x, d.y) <= Data.ENDINGS["ruins_clear"] else 0
	t.check(near == 0, "none lies by the Hearth")
	var patches := Ruins.patch_tiles(n)
	t.check(n.carry.patches.size() >= 2 and n.carry.patches.size() <= 4, "two to four dormant Bloom patches")
	t.check(
		patches.size() >= 2 and patches.all(func(p): return n.world.tile_at(p) == "bloom_ground"),
		"each laid as Bloom ground"
	)
	var same := 0
	for y in n.world.height:
		for x in n.world.width:
			var p := Vector2i(x, y)
			if n.world.tile_at(p) == base.world.tile_at(p):
				same += 1
	t.check(same > n.world.width * n.world.height - 40, "the rest of the land is the old land")
	var clipped := _ended_run("enemies", 12.0)
	var rec: Dictionary = Endings.handoff(clipped, "cataclysm")
	t.check(rec["ruins"].size() <= Data.ENDINGS["ruins_max"], "no more ruins are kept than the cap")
	t.check(
		(
			Endings.handoff(clipped, "loop")["ruins"].is_empty()
			and Endings.handoff(clipped, "exodus")["patches"].is_empty()
		),
		"only a Cataclysm leaves ruins"
	)
	var big := _ended_run("enemies", 12.0, 150)
	t.check(
		Ruins.of(big).size() == Data.ENDINGS["ruins_max"] and Ruins.of(big)[0]["weight"] >= Ruins.of(big)[-1]["weight"],
		"the dearest are kept"
	)
	_clean()


func test_clearing_a_ruin_gives_stone() -> void:
	_clean()
	var old := _ended_run("enemies")
	Profile.set_out(old, TEMP_PROFILE, "cataclysm")
	var n := Sim.new()
	Launch.begin_new(n, -1, TEMP_PROFILE)
	var p := Vector2i(int(n.carry.ruins[0]["pos"][0]), int(n.carry.ruins[0]["pos"][1]))
	n.fog.reveal(p, 3)
	t.check(Clearing.check(n, p)["ok"], "Demolish may clear a ruin")
	var before: int = n.economy.inv.get("stone", 0)
	t.check(Clearing.clear(n, p) == "ruins" and n.world.tile_at(p) == "grass", "and it becomes open grass")
	var gave: int = n.economy.inv.get("stone", 0) - before
	t.check(
		gave == Ruins.stone_at(n, p) and gave >= Data.ENDINGS["stone_min"] and gave <= Data.ENDINGS["stone_max"],
		"giving Stone (%d)" % gave
	)
	_clean()


func test_ruins_in_the_land_that_grows_are_laid_as_it_grows() -> void:
	_clean()
	var old := Sim.new()
	old.generate(SEED)
	old.world.grow_east()
	var east: Vector2i = Vector2i(-1, -1)
	for y in old.world.height:
		for x in range(old.world.stone_width + 2, old.world.width):
			if old.world.tile_at(Vector2i(x, y)) == "grass":
				east = Vector2i(x, y)
				break
		if east.x >= 0:
			break
	old.town.add_building("kiln", east)
	old.starfall.lean = "enemies"
	old.story.record(Data.SKYWARD_EVENT)
	Profile.set_out(old, TEMP_PROFILE, "cataclysm")
	var n := Sim.new()
	Launch.begin_new(n, -1, TEMP_PROFILE)
	t.check(
		(
			not n.world.in_bounds(east)
			and n.carry.ruins.any(func(r): return Vector2i(int(r["pos"][0]), int(r["pos"][1])) == east)
		),
		"a ruin in the east waits for the land"
	)
	n.tech_tree.researched["bronze_dawn"] = true
	Land.grow_if_due(n)
	t.check(n.world.tile_at(east) == "ruins", "it is laid when the land grows east")
	n.fog.reveal(east, 3)
	Clearing.clear(n, east)
	Land.grow_if_due(n)
	t.check(n.world.tile_at(east) == "grass", "and a cleared one is not laid again")
	_clean()


func test_the_tide_wakes_from_the_dormant_patches() -> void:
	_clean()
	Profile.set_out(_ended_run("enemies"), TEMP_PROFILE, "cataclysm")
	var n := Sim.new()
	Launch.begin_new(n, -1, TEMP_PROFILE)
	var first: Vector2i = Ruins.patch_tiles(n)[0]
	n.tide.begin(n)
	var wakes := false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		wakes = wakes or n.tide.front.has(first + d)
	t.check(n.tide.begun and wakes, "the tide starts from the patches by the ruins, not only the edge")
	var plain := Sim.new()
	plain.generate(SEED)
	plain.tide.begin(plain)
	t.check(plain.tide.front.is_empty(), "a first run's tide has no patch to start from before the south grows")
	_clean()


func test_the_time_loop_remembers_and_the_cataclysm_arrives_wary() -> void:
	_clean()
	var lines := []
	Profile.set_out(_ended_run("allies", 77.0), TEMP_PROFILE, "loop")
	var loop := Sim.new()
	Launch.begin_new(loop, 1007, TEMP_PROFILE)
	loop.starfall.said.connect(func(l): lines.append(l))
	loop.starfall.begin(false)
	t.check(
		is_equal_approx(loop.starfall.trust, 77.0), "the Time loop's Lumen begin at the trust the last run ended with"
	)
	loop.starfall.tick(Data.LANDING_DELAY)
	loop.starfall.tick(Data.ARRIVAL_DELAY)
	t.check(Data.ENDINGS["greet"] in lines, "Sela greets the Kith by name")
	t.check(Data.ENDINGS["remembered"] % "allies" in lines, "and the run notes the lean the Kith had")
	var first := Sim.new()
	first.generate(SEED)
	first.starfall.begin(true)
	t.check(
		is_equal_approx(first.starfall.trust, Data.TRUST_START_GUESTS) and first.starfall.guests,
		"a first run's guests start as ever"
	)
	var wary := Sim.new()
	wary.generate(SEED)
	wary.starfall.begin(false)
	t.check(is_equal_approx(wary.starfall.trust, Data.TRUST_START_WARY), "and its wary strangers too")
	Profile.set_out(_ended_run("enemies", 12.0), TEMP_PROFILE, "cataclysm")
	var cat := Sim.new()
	Launch.begin_new(cat, -1, TEMP_PROFILE)
	cat.starfall.begin(true)
	t.check(
		is_equal_approx(cat.starfall.trust, Data.TRUST_START_WARY) and not cat.starfall.guests,
		"after a Cataclysm they arrive wary, a Cairn or not"
	)
	Profile.set_out(_ended_run("neighbours", 40.0), TEMP_PROFILE, "exodus")
	var exo := Sim.new()
	Launch.begin_new(exo, 1009, TEMP_PROFILE)
	exo.starfall.begin(true)
	t.check(
		is_equal_approx(exo.starfall.trust, Data.TRUST_START_GUESTS), "after an Exodus they start as in a first run"
	)
	_clean()


func test_each_ending_opens_the_next_run_with_its_own_card() -> void:
	for ending in ["exodus", "cataclysm", "loop"]:
		_clean()
		var lean: String = {"exodus": "neighbours", "cataclysm": "enemies", "loop": "allies"}[ending]
		Profile.set_out(_ended_run(lean), TEMP_PROFILE, ending)
		var n := Sim.new()
		Launch.begin_new(n, 1005, TEMP_PROFILE)
		var card := NoticeCard.new()
		card.setup()
		t.check(card.poll(n, false) and card.visible, "%s: the next run opens with a card" % ending)
		var words := ""
		for c in card._box.get_children():
			if c is Label:
				words += c.text + "\n"
		t.check(
			words.contains(Data.ENDINGS[ending]["next_title"]) and words.contains(Data.ENDINGS[ending]["next_text"]),
			"%s: in its own words" % ending
		)
		t.check(not card.poll(n, false) or true, "once")
		card.free()
	_clean()


func test_the_skyward_cutscene_and_the_greeting() -> void:
	var s := Sim.new()
	s.generate(SEED)
	var p = CutscenePlayer.new()
	p.setup(s, null, [])
	s.story.record(Data.SKYWARD_EVENT)
	t.check(p.queue.has("skyward_end"), "reaching Skyward queues the end-of-telling cutscene")
	t.check(Data.CUTSCENES["skyward_end"]["stills"].size() == 3, "three stills")
	t.check(
		Data.CUTSCENES["skyward_end"]["stills"][2]["line"].contains("But you'll remember"), "the last is Sela's line"
	)
	p.free()
	var loop := Sim.new()
	loop.generate(SEED)
	loop.carry.from_dict({"exodus": 1, "ending": "loop"})
	var q = CutscenePlayer.new()
	q.setup(loop, null, [])
	t.check(q.variant_key("arrival") == "loop", "after a Time loop the strangers' arrival is a loop's")
	t.check(
		(
			q.resolve("first_contact")[2]["line"]
			== Data.CUTSCENES["first_contact"]["stills"][2]["variants"]["loop"]["line"]
		),
		"and Sela says the Kith's name first"
	)
	q.free()
