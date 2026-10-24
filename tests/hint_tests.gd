extends RefCounted
## The first-time hints (scripts/hints.gd): each shows once on its moment, is kept in the profile so no later run or load shows it
## again, stays until clicked away, waits behind the one on screen, obeys the Hints switch, and is not made for the scripted tools.
## Run from tests/run_tests.gd, which owns check() and the helpers.

const CutscenePlayer = preload("res://scripts/cutscene_player.gd")
const Data = preload("res://scripts/data.gd")
const HintSettings = preload("res://scripts/hint_settings.gd")
const Hints = preload("res://scripts/hints.gd")
const Messages = preload("res://scripts/messages.gd")
const Profile = preload("res://scripts/profile.gd")
const Sim = preload("res://scripts/sim.gd")

const PROFILE_PATH := "user://test_hint_profile.json"
const SETTINGS_PATH := "user://test_hints.cfg"

var t  # the runner, tests/run_tests.gd
var _old_settings := ""
var _old_profile := ""


func run(runner) -> void:
	t = runner
	_begin()
	test_the_data_is_well_formed()
	test_the_first_hut_says_what_huts_do()
	test_a_hint_shows_once_and_is_kept_in_the_profile()
	test_a_new_run_and_a_dismissal_do_not_bring_it_back()
	test_one_hint_at_a_time()
	test_the_switch_turns_them_off()
	test_hands_short_and_gaps_must_last()
	test_the_store_the_season_and_births_have_their_moments()
	test_the_bronze_dawn_hints()
	test_the_tools_make_none()
	test_the_old_profile_still_loads()
	_end()


func _begin() -> void:
	_old_settings = HintSettings.path
	_old_profile = Hints.profile_path
	HintSettings.path = SETTINGS_PATH
	Hints.profile_path = PROFILE_PATH
	HintSettings.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	_forget()


func _end() -> void:
	_forget()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	HintSettings.path = _old_settings
	Hints.profile_path = _old_profile
	HintSettings.reset()


func _forget() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))


## A hints maker over fresh toasts, and the game it watches.
func _setup() -> Array:
	var queue := Messages.new()
	return [Hints.attach(queue), queue, t.fresh()]


func _hints_up(queue: Messages) -> Array:
	return queue.active.filter(func(m): return m["kind"] == Data.HINT_KIND)


func test_the_data_is_well_formed() -> void:
	t.check(Data.HINT_ORDER.size() == 9, "nine hints for the stone age and Bronze Dawn")
	for id in Data.HINT_ORDER:
		t.check(Data.HINTS.has(id), "%s has its words" % id)
		t.check(id == "births_wait" or Data.HINTS[id].length() > 20, "%s is a sentence" % id)
	t.check(Data.HINTS["hut"].begins_with("Huts gather what's in reach."), "the hut hint is the director's line")


func test_the_first_hut_says_what_huts_do() -> void:
	var made := _setup()
	var hints: Hints = made[0]
	var queue: Messages = made[1]
	var s: Sim = made[2]
	hints.update(s, 1.0)
	t.check(_hints_up(queue).is_empty(), "nothing built, nothing said")
	t.place_free(s, "gatherers_hut", s.world.camp_pos + Vector2i(-2, 0))
	hints.update(s, 1.0)
	var up := _hints_up(queue)
	t.check(up.size() == 1 and up[0]["text"] == Data.HINTS["hut"], "the first hut brings its hint")
	t.check(up[0]["sticky"], "and it stays until it is clicked away")


func test_a_hint_shows_once_and_is_kept_in_the_profile() -> void:
	_forget()
	var made := _setup()
	var hints: Hints = made[0]
	var queue: Messages = made[1]
	var s: Sim = made[2]
	t.place_free(s, "gatherers_hut", s.world.camp_pos + Vector2i(-2, 0))
	hints.update(s, 1.0)
	t.check(hints.has_shown("hut"), "shown")
	var profile := Profile.new()
	profile.load_file(PROFILE_PATH)
	t.check(profile.has_hint("hut"), "and written to the profile, not to the run")
	queue.dismiss(_hints_up(queue)[0]["id"])
	hints.update(s, 1.0)
	hints.update(s, 1.0)
	t.check(_hints_up(queue).is_empty(), "dismissed, it does not come back while the hut still stands")


func test_a_new_run_and_a_dismissal_do_not_bring_it_back() -> void:
	_forget()
	var first := _setup()
	var s1: Sim = first[2]
	t.place_free(s1, "gatherers_hut", s1.world.camp_pos + Vector2i(-2, 0))
	first[0].update(s1, 1.0)
	var second := _setup()
	var s2: Sim = second[2]
	t.place_free(s2, "gatherers_hut", s2.world.camp_pos + Vector2i(-2, 0))
	second[0].update(s2, 1.0)
	t.check(
		_hints_up(second[1]).is_empty(),
		"a new run, with the profile as it stands, says nothing of a hint already shown"
	)
	var again := Profile.new()
	again.load_file(PROFILE_PATH)
	t.check(again.hints == ["hut"], "and the profile holds it once")


func test_one_hint_at_a_time() -> void:
	_forget()
	var made := _setup()
	var hints: Hints = made[0]
	var queue: Messages = made[1]
	var s: Sim = made[2]
	t.place_free(s, "gatherers_hut", s.world.camp_pos + Vector2i(-2, 0))
	t.place_free(s, "storehouse", s.world.camp_pos + Vector2i(2, 2))
	hints.update(s, 1.0)
	hints.update(s, 1.0)
	t.check(_hints_up(queue).size() == 1 and not hints.has_shown("storehouse"), "the next waits for the one on screen")
	queue.dismiss(_hints_up(queue)[0]["id"])
	hints.update(s, 1.0)
	t.check(
		hints.has_shown("storehouse") and _hints_up(queue)[0]["text"] == Data.HINTS["storehouse"],
		"and comes when it is gone"
	)


func test_the_switch_turns_them_off() -> void:
	_forget()
	HintSettings.set_on(false)
	var made := _setup()
	var s: Sim = made[2]
	t.place_free(s, "gatherers_hut", s.world.camp_pos + Vector2i(-2, 0))
	made[0].update(s, 1.0)
	t.check(
		_hints_up(made[1]).is_empty() and not made[0].has_shown("hut"),
		"with the switch off nothing shows and nothing is marked shown"
	)
	HintSettings.reset()
	t.check(not HintSettings.on(), "the choice is kept in its own file")
	HintSettings.set_on(true)
	made[0].update(s, 1.0)
	t.check(made[0].has_shown("hut"), "turned on again, the hint that waited shows")


func test_hands_short_and_gaps_must_last() -> void:
	_forget()
	var made := _setup()
	var hints: Hints = made[0]
	var s: Sim = made[2]
	t.employ(s, 6)  # six huts and three Kith: jobs stand empty with nobody idle
	for i in 3:  # the Kith take the jobs
		s.tick(1.0)
	hints.update(s, 1.0)  # the first hut's own hint comes first
	made[1].dismiss(_hints_up(made[1])[0]["id"])
	hints.update(s, Data.HINT_SHORT_FOR - 2.0)
	t.check(not hints.has_shown("short_hands"), "59 seconds short of hands is not yet 60")
	for m in _hints_up(made[1]):  # the empty huts have been a red gap a while too: that hint came first
		made[1].dismiss(m["id"])
	hints.update(s, 3.0)
	t.check(hints.has_shown("short_hands"), "60 seconds is: " + str(hints._held))
	t.check(_hints_up(made[1])[0]["text"] == Data.HINTS["short_hands"], "with the director's words")


func test_the_store_the_season_and_births_have_their_moments() -> void:
	_forget()
	var made := _setup()
	var hints: Hints = made[0]
	var queue: Messages = made[1]
	var s: Sim = made[2]
	s.economy.refresh_caps(s.town.buildings)
	s.economy.inv["wood"] = int(s.economy.caps["wood"])
	hints.update(s, 1.0)
	t.check(hints.has_shown("store_full"), "a good at its cap")
	queue.dismiss(_hints_up(queue)[0]["id"])
	s.seasons.phase = "active"
	hints.update(s, 1.0)
	t.check(hints.has_shown("strain"), "a season of strain under way")
	queue.dismiss(_hints_up(queue)[0]["id"])
	s.seasons.phase = "idle"
	t.place_free(s, "dwelling", s.world.camp_pos + Vector2i(0, 2))
	t.employ(s, 1)  # a workplace for the line to point at
	hints.update(s, 1.0)  # the first hut's own hint comes first
	queue.dismiss(_hints_up(queue)[0]["id"])
	s.people.idle_now = s.people.kith.size()
	hints.update(s, 1.0)
	t.check(hints.has_shown("births_wait"), "births waiting for work")
	var line := (
		"Births wait: %d %s have no work. Build workshops to use them." % [s.people.idle_now, Data.PEOPLE["many"]]
	)
	t.check(_hints_up(queue)[0]["text"] == line, "it says the line the top bar says")


func test_the_bronze_dawn_hints() -> void:
	_forget()
	var made := _setup()
	var hints: Hints = made[0]
	var queue: Messages = made[1]
	var s: Sim = made[2]
	t.check(t.place_free(s, "storehouse", s.world.camp_pos + Vector2i(3, 0)), "a Storehouse is placed")
	hints.update(s, 1.0)
	t.check(_hints_up(queue)[0]["text"] == Data.HINTS["storehouse"], "the first Storehouse brings the Storehouse hint")
	queue.dismiss(_hints_up(queue)[0]["id"])
	var mine_spot := s.world.camp_pos + Vector2i(-3, 3)
	t.place_free(s, "mine", mine_spot)
	hints.update(s, 1.0)
	t.check(
		s.town.buildings.any(func(b): return b["type"] == "mine") == hints.has_shown("mine"),
		"and the first Mine its own, when a Mine stands"
	)


func test_the_tools_make_none() -> void:
	var was := CutscenePlayer.suppress
	CutscenePlayer.suppress = true
	t.check(Hints.attach(Messages.new()) == null, "with suppress set (the scripted tools) there is none")
	CutscenePlayer.suppress = false
	t.check(Hints.attach(Messages.new()) != null, "and without it there is one")
	CutscenePlayer.suppress = was


func test_the_old_profile_still_loads() -> void:
	var p := Profile.new()
	var ok := p.from_json('{"version": 1, "chronicle": ["a"], "knowledge": ["wood"]}')
	t.check(
		ok and p.chronicle == ["a"] and p.hints.is_empty(),
		"a profile written before hints existed loads, with none shown"
	)
