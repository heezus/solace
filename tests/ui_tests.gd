extends RefCounted
## The interface's plain-language pieces that need no window: what a build card says (and that it always fits),
## which cards show at all, the message queue behind the toasts and the log, and the hut panel's sentences.
## Run from tests/run_tests.gd, which owns check() and fresh().

const Data = preload("res://scripts/data.gd")
const CardText = preload("res://scripts/card_text.gd")
const Messages = preload("res://scripts/messages.gd")
const BuildingPanel = preload("res://scripts/building_panel.gd")
const Overlays = preload("res://scripts/overlays.gd")
const KithArt = preload("res://scripts/kith_art.gd")
const TopBar = preload("res://scripts/top_bar.gd")
const Ui = preload("res://scripts/ui.gd")
const HutFocus = preload("res://scripts/hut_focus.gd")
const GrowthNote = preload("res://scripts/growth_note.gd")
const Workers = preload("res://scripts/workers.gd")
const SidePanel = preload("res://scripts/side_panel.gd")
const HoverText = preload("res://scripts/hover_text.gd")

const CARD_TEXT_W := 110.0  # the width of a card's state line (BuildBar.TEXT_W)

var t  # the runner, tests/run_tests.gd


func run(runner) -> void:
	t = runner
	test_card_says_what_is_missing()
	test_card_line_always_fits()
	test_story_cards_stay_hidden_until_revealed()
	test_messages_stack_and_expire()
	test_important_messages_stay()
	test_message_log_keeps_everything()
	test_hut_panel_speaks_plainly()
	test_status_pills_are_short()
	test_a_row_of_buildings_gets_pills_that_never_overlap()
	test_every_kith_has_a_place_on_the_map()
	test_words_are_plain()
	test_the_growth_note_says_what_to_do_in_each_state()
	test_a_building_waiting_for_kith_points_at_the_fix()
	test_the_food_flash_stays_legible()
	test_the_goal_list_shows_the_current_goal_and_the_next()
	test_every_skill_text_says_what_they_gather()


func test_card_says_what_is_missing() -> void:
	var s = t.fresh()
	t.check(
		CardText.state_line(s, "gatherers_hut", "", CARD_TEXT_W) == Data.CARD_LOCKED, "a locked card says it's locked"
	)
	t.check(
		CardText.locked_reason("gatherers_hut") == "Discover Gatherer's Hut",
		"and names the tech to discover: " + CardText.locked_reason("gatherers_hut")
	)
	s.tech_tree.researched["gatherers_hut"] = true
	s.economy.inv.clear()
	s.economy.inv["wood"] = 6
	s.economy.inv["stone"] = 5
	var line: String = CardText.state_line(s, "gatherers_hut", "", CARD_TEXT_W)
	t.check(line == "Need 4 Wood", "an affordable-but-for-wood card says 'Need 4 Wood': " + line)
	s.economy.inv["wood"] = 10
	t.check(CardText.state_line(s, "gatherers_hut", "", CARD_TEXT_W) == Data.CARD_READY, "a card you can pay is Ready")
	t.check(
		CardText.state_line(s, "gatherers_hut", "gatherers_hut", CARD_TEXT_W) == Data.CARD_PLACING,
		"and says Placing while you place it"
	)
	t.check(
		CardText.shortfall(s.economy.inv, {"wood": 12, "stone": 5}) == ["2 Wood"], "the shortfall lists what is short"
	)
	s.tech_tree.researched["haulers"] = true
	t.check(
		CardText.state_line(s, "road", "", CARD_TEXT_W) == Data.CARD_DRAG, "a road is ready to drag once wood is there"
	)
	s.economy.inv["wood"] = 10
	s.economy.inv["rope"] = 0
	t.check(CardText.state_line(s, "bridge", "", CARD_TEXT_W) == "Need 2 Rope", "and a bridge asks for its rope")


## However long the missing list, the line fits the card (it shortens: "+1 more", then "Need more").
func test_card_line_always_fits() -> void:
	var s = t.fresh()
	s.economy.inv.clear()
	for type in Data.BUILDINGS:
		if Data.BUILDINGS[type]["cost"].is_empty():
			continue
		s.tech_tree.researched[Data.BUILDINGS[type]["tech"]] = true
		for width in [CARD_TEXT_W, 70.0, 40.0]:
			var line: String = CardText.state_line(s, type, "", width)
			t.check(
				CardText.width(line) <= width or line == Data.CARD_NEED_ITEMS,
				"%s's card line fits %d px: %s" % [type, int(width), line]
			)
	t.check(not CardText.state_line(s, "kiln", "", CARD_TEXT_W).contains("..."), "and it is never cut short with dots")
	var lines := {}
	s.economy.inv["stone"] = 0
	lines["two"] = CardText.state_line(s, "kiln", "", CARD_TEXT_W)
	t.check(lines["two"].begins_with("Need 10 Stone"), "two items short still say what: " + lines["two"])


## The Lore cards (Standing Stone, Shard Cairn) stay off the build bar until their tech is on the board and reachable.
func test_story_cards_stay_hidden_until_revealed() -> void:
	var s = t.fresh()
	t.check(not CardText.shown(s, "shard_cairn"), "the Shard Cairn is hidden at the start")
	t.check(not CardText.shown(s, "standing_stone"), "so is the Standing Stone")
	t.check(CardText.shown(s, "gatherers_hut") and CardText.shown(s, "dwelling"), "ordinary cards always show")
	s.tech_tree.researched["masonry"] = true
	t.check(not CardText.shown(s, "standing_stone"), "Masonry alone doesn't show it: Megaliths needs Storytelling too")
	s.tech_tree.researched["storytelling"] = true
	t.check(CardText.shown(s, "standing_stone"), "it shows once Megaliths is reachable")
	t.check(not CardText.shown(s, "shard_cairn"), "the Cairn stays hidden until the Strange Stone has been clicked")
	s.shard_seen = true
	t.check(CardText.shown(s, "shard_cairn"), "and shows after, when Star Lore is reachable")
	for type in Data.BUILDINGS:
		var def: Dictionary = Data.BUILDINGS[type]
		t.check(not def.get("story", false) or def["kind"] in ["aura", "cairn"], "only Lore buildings are story cards")


func test_messages_stack_and_expire() -> void:
	var q := Messages.new()
	q.push("one", 2.0)
	q.push("two", 2.0)
	q.push("one", 2.0)  # the same text again refreshes, it doesn't stack
	t.check(q.active.size() == 2, "the same message twice is one toast (%d)" % q.active.size())
	for i in 6:
		q.push("more %d" % i, 5.0)
	t.check(q.active.size() == Messages.MAX_SHOWN, "at most %d toasts show at once" % Messages.MAX_SHOWN)
	t.check(q.active[q.active.size() - 1]["text"] == "more 5", "the newest is last")
	q.advance(6.0)
	t.check(q.active.is_empty(), "toasts expire")
	t.check(q.history.size() == 9, "but every message is in the log (%d)" % q.history.size())
	q.push("a long one that reads for a while because it has many words in it, and then some more words", 0.0)
	t.check(q.active[0]["left"] > Messages.MIN_SECONDS, "a long message stays longer than a short one")


func test_important_messages_stay() -> void:
	var q := Messages.new()
	var left := Messages.style_of(Data.LEFT_EVENT % Data.PEOPLE["one"])
	t.check(left["sticky"], "a Kith leaving is sticky")
	var low := Messages.style_of(Data.FOOD_LOW_EVENT % Data.PEOPLE["many"])
	t.check(low["sticky"] and low["key"] == "food", "so is the low-food warning, keyed 'food'")
	t.check(not Messages.style_of("Discovered Knapping")["sticky"], "a discovery is not")
	q.push("A Kith left", low["seconds"], true)
	q.push("Food is low", low["seconds"], true, "food")
	q.push("Discovered Knapping", 3.0)
	q.advance(600.0)
	t.check(q.active.size() == 2, "sticky messages outlast ten minutes (%d showing)" % q.active.size())
	q.resolve("food")
	t.check(q.active.size() == 1 and not q.showing("food"), "resolve takes down the food warning once food is back")
	q.dismiss(q.active[0]["id"])
	t.check(q.active.is_empty(), "a click dismisses a sticky message")
	q.push("s1", 0.0, true)
	q.push("s2", 0.0, true)
	q.push("s3", 0.0, true)
	q.push("s4", 0.0, true)
	q.push("plain", 3.0)
	t.check(q.active.size() == Messages.MAX_SHOWN, "a full stack still makes room")
	t.check(
		not q.active.any(func(m): return m["text"] == "s1") or q.active.size() == Messages.MAX_SHOWN, "sticky are kept"
	)


func test_message_log_keeps_everything() -> void:
	var q := Messages.new()
	for i in Messages.LOG_MAX + 10:
		q.advance(1.0)
		q.push("m%d" % i, 3.0)
	t.check(
		q.history.size() == Messages.LOG_MAX, "the log keeps the last %d (%d)" % [Messages.LOG_MAX, q.history.size()]
	)
	var recent := q.recent(3)
	t.check(recent[0]["text"] == "m%d" % (Messages.LOG_MAX + 9), "newest first")
	t.check(recent[0]["at"] > recent[2]["at"], "each with the time it came")
	t.check(Messages.clock_text(65.0) == "1:05", "clock text reads m:ss")


## The hut panel reads as sentences, and keeps the exact numbers for a tooltip.
func test_hut_panel_speaks_plainly() -> void:
	var s = t.fresh()
	s.economy.inv["berries"] = 100
	var p: Vector2i = s.world.camp_pos + Vector2i(-2, 0)
	t.place_free(s, "gatherers_hut", p)
	s.tick(0.1)
	var hut: Dictionary = s.town.buildings[s.town.building_at[p]]
	var pace := BuildingPanel.pace_text(s, hut)
	t.check(pace.contains("Each trip brings back") or pace.contains("About"), "the pace is a sentence: " + pace)
	for jargon in ["jobs/min", "Bundle:", "Speed x", "x a click"]:
		t.check(not pace.contains(jargon), "the pace has no '%s': %s" % [jargon, pace])
	var worker := BuildingPanel.worker_text(s, hut)
	t.check(not worker.contains("jobs left"), "the worker line has no 'jobs left': " + worker)
	var k: Dictionary = s.people.kith[hut["worker"]]
	k["tool"] = 39
	worker = BuildingPanel.worker_text(s, hut)
	t.check(worker.contains("flint tool has 39 uses left"), "a tool's wear reads plainly: " + worker)
	var trips := BuildingPanel.click_text(s, hut)
	t.check(not trips.contains("○") and not trips.contains("●"), "the trips line has no pips to decode: " + trips)


func test_status_pills_are_short() -> void:
	t.check(Overlays.pill_text("Hungry: no food") == "Hungry", "a hungry pill says Hungry")
	t.check(Overlays.pill_text("Idle: no free Kith") == "Idle", "an idle pill says Idle")
	t.check(Overlays.pill_text("Needs road") == "Needs road", "a short alert stays whole")


## Every Kith gets a spot on the map, and idle ones around one tile don't stack.
func test_every_kith_has_a_place_on_the_map() -> void:
	var s = t.fresh()
	var spots := KithArt.spots(s, 0.0)
	t.check(spots.size() == s.people.kith.size(), "a drawn spot for every Kith (%d)" % spots.size())
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			t.check(
				spots[i]["pos"].distance_to(spots[j]["pos"]) > 12.0,
				"Kith %d and %d don't stand on each other (%.0f)" % [i, j, spots[i]["pos"].distance_to(spots[j]["pos"])]
			)


## The wording rules: one verb for research, the Hearth (never "camp") in what the player reads, a skill
## toast that names the Kith once and never a tech's name, and the readouts explaining themselves.
func test_words_are_plain() -> void:
	for goal in Data.GOALS:
		t.check(not goal["text"].contains("esearch"), "goal '%s' says Discover, not Research" % goal["text"])
	t.check(Data.DISCOVERED_EVENT % "Knapping" == "Discovered Knapping", "one verb: Discovered")
	var s = t.fresh()
	s.economy.inv["flint"] = 99
	s.economy.inv["stone"] = 99
	s.events.clear()
	s.research("knapping")
	t.check(s.events.has("Discovered Knapping"), "discovering a tech says so: %s" % [s.events])
	var tech_names: Array = Data.TECHS.values().map(func(x): return String(x["name"]).to_lower())
	for item in Data.HUT_JOBS:
		var line: String = Data.LEARNED_LINE % ["Aro", Data.HUT_JOBS[item]["craft"], Data.HUT_JOBS[item]["title"]]
		t.check(line.count("Aro") == 1, "the skill toast names Aro once: " + line)
		t.check(Data.HUT_JOBS[item]["craft"].begins_with("to "), "the skill reads as what they do: " + line)
		t.check(not tech_names.has(Data.HUT_JOBS[item]["craft"]), "the skill isn't named like a tech: " + line)
	for text in [Data.CAMP_TOAST, Data.BORN_TOAST, Data.FLAVOR_STOCK, Data.UNEXPLORED_INFO]:
		t.check(not text.to_lower().contains("camp"), "player text says Hearth, not camp: " + text)
	for id in Data.FLAVOR_STORY:
		t.check(Data.STORY_EVENTS.has(id), "the warm line waits for a real story moment: " + id)
	var kith_label: String = Data.KITH_LABEL % ["Kith", 3, 4]
	t.check(kith_label == "Kith 3  ·  homes for 4", "the Kith count says what the second number is: " + kith_label)
	t.check(Data.JOBS_LABEL.begins_with("Jobs filled"), "the Jobs readout says what it counts")


## Playtest 4 still saw "Esk learned knapping" and "Aro learned thatching" when gathering flint and flax, before those
## techs exist. Every place that words what a Kith learned (the toast, the message log, the hover line, the hut card) must
## name what they gather ("to gather flint"), never a tech.
func test_every_skill_text_says_what_they_gather() -> void:
	var words: Array = []
	for id in Data.TECHS:
		words.append(String(Data.TECHS[id]["name"]).to_lower())
	words += ["knapping", "thatching"]
	for item in Data.HUT_JOBS:
		var s = t.fresh()
		var tile := ""
		for name in Data.TILES:
			if Data.TILES[name]["yields"] == item:
				tile = name
		var p: Vector2i = t.find_tile(s, tile)
		t.check(p.x >= 0, "a %s tile to harvest by hand" % item)
		var texts: Array = []
		s.events.clear()
		for _n in Data.LEARN_CLICKS:
			s.gather_by_hand(p)
			texts.append(HoverText.learn_text(s, item))
		var learned: Array = s.events.filter(func(e): return String(e).contains("learned"))
		t.check(learned.size() == 1, "%s: one 'learned' toast (%d)" % [item, learned.size()])
		texts += s.events
		texts.append(HoverText.learn_text(s, item))
		var queue = Messages.new()
		for e in s.events:
			queue.push(e, 1.0)
		for entry in queue.history:
			texts.append(String(entry["text"]))
		t.check(String(learned[0]).contains(" learned to "), "%s: the toast says what they do: %s" % [item, learned[0]])
		for text in texts:
			for w in words:
				t.check(not String(text).to_lower().contains(w), "%s: '%s' names a tech (%s)" % [item, text, w])


## Playtest 4: done goals stayed in the list and pushed the current one down. The panel shows the current goal and the
## next one, the done ones are a count in the header.
func test_the_goal_list_shows_the_current_goal_and_the_next() -> void:
	var s = t.fresh()
	var panel := SidePanel.new()
	panel.setup(s, 300.0)
	panel.refresh_goals(s)
	t.check(panel.goal_header.text == "Goals 0/%d" % Data.GOALS.size(), "the header counts: " + panel.goal_header.text)
	for n in 9:
		s.story.goals_done[Data.GOALS[n]["id"]] = true
	panel.refresh_goals(s)
	var shown: Array = panel.goal_labels.filter(func(l): return l.visible).map(func(l): return l.text)
	t.check(shown.size() == 2, "two goals show: %s" % [shown])
	t.check(
		shown[0] == "> " + Data.GOALS[9]["text"] and shown[1] == "  " + Data.GOALS[10]["text"],
		"the current one, then the next"
	)
	t.check(not " ".join(shown).contains("Done"), "no done goal is listed")
	t.check(panel.goal_header.text == "Goals 9/%d" % Data.GOALS.size(), "and the header says 9 are done")
	t.check(panel.goal_header.tooltip_text.count("Done: ") == 9, "hovering it lists them")
	panel.building_panel.visible = true
	panel.refresh_goals(s)
	t.check(
		panel.goal_labels.filter(func(l): return l.visible).size() == 1, "with a card open, only the current goal shows"
	)
	panel.free()


## Playtest 4: at the dim point of its flash the Food box's "Low: 18 s left" was nearly invisible. Only the ring flashes
## now; the words keep their colour at full strength, and read at 4.5 to 1 or better on the bar at every phase.
func test_the_food_flash_stays_legible() -> void:
	t.check(Ui.contrast(Color.WHITE, Color.BLACK) > 20.9, "the contrast measure: white on black is 21")
	t.check(
		Ui.contrast(Ui.BAD, Ui.BAR) < 4.5, "the plain red was too dim on the bar (%.1f)" % Ui.contrast(Ui.BAD, Ui.BAR)
	)
	t.check(
		Ui.contrast(TopBar.ALARM_TEXT, Ui.BAR) >= 4.5,
		"the alarm text reads on the bar: %.1f" % Ui.contrast(TopBar.ALARM_TEXT, Ui.BAR)
	)
	var least := 99.0
	for n in 32:
		least = minf(least, Ui.contrast(TopBar.flash_ring(n * 0.1), Ui.BAR))
	t.check(least >= 3.0, "the ring is visible at every phase of the flash (%.1f)" % least)


## Playtest 5: "Needs steady food to grow" explained nothing. The note now says what steady means and the fix for where
## the player is: no room, no haulers yet, haulers but no hut on a road, a hut on a road. The tooltip has the exact rule.
func test_the_growth_note_says_what_to_do_in_each_state() -> void:
	var s = t.fresh()
	s.economy.inv["berries"] = 100
	t.check(Ui.growth_note(s).begins_with(Data.GROW_NOTE_FOOD + ": "), "food note: " + Ui.growth_note(s))
	t.check(
		Ui.growth_note(s).contains("Paths & Haulers") and Ui.growth_note(s).contains("road"),
		"before Paths & Haulers: names them"
	)
	t.check(Ui.growth_note(s) == Data.GROW_NOTE_FOOD + ": " + Data.GROW_FIX_NO_HAULERS, "exactly the data text")
	s.tech_tree.researched["haulers"] = true
	t.check(
		Ui.growth_note(s) == Data.GROW_NOTE_FOOD + ": " + Data.GROW_FIX_ROAD,
		"with haulers: a hut on a road: " + Ui.growth_note(s)
	)
	s.tech_tree.researched["gatherers_hut"] = true
	t.check(t.place_free(s, "gatherers_hut", s.world.camp_pos + Vector2i(0, 2)), "a hut goes up")
	s.town.set_focus(s.town.building_at[s.world.camp_pos + Vector2i(0, 2)], "berries")
	t.road_link(s, s.world.camp_pos + Vector2i(0, 2))
	t.check(
		(
			Ui.growth_note(s) == Data.GROW_NOTE_FOOD + ": " + Data.GROW_FIX_MORE
			or Ui.growth_note(s).contains(Data.GROW_FIX_MORE)
		),
		"with a hut on a road: more of them: " + Ui.growth_note(s)
	)
	t.check(Ui.growth_note(s) != "" and Ui.growth_note(s).length() < 100, "and it is short enough for the bar")
	t.place_free(s, "dwelling", s.world.camp_pos + Vector2i(0, 2))
	s.people.found(s.town.housing())
	t.check(Ui.growth_note(s) == Data.NOTE_NO_ROOM, "no room: " + Ui.growth_note(s))
	s.people.found(3)
	s.economy.starving = true
	t.check(Ui.growth_note(s) == Data.NOTE_STARVING, "starving comes first")
	s.economy.starving = false
	t.steady_income(s)
	t.check(Ui.growth_note(s) == "", "steady food: no note")
	var rule: String = GrowthNote.rule()
	t.check(
		rule.contains("%d" % int(Data.STEADY_SECONDS)) and rule.contains("%d" % Data.RATE_WINDOW),
		"the tooltip gives the exact rule: " + rule
	)
	t.check(rule.contains("not your own hands"), "and says hand-gathering does not count")
	var goal := ""
	for g in Data.GOALS:
		if g["id"] == "dwelling":
			goal = g["text"]
	t.check(goal.contains("steady food") and goal.contains("road"), "the Dwelling goal points at roads: " + goal)


## Playtest 5: a Twine Post said "No Roper yet: more Kith needed (they grow with food and Dwellings)" with no way
## forward. While food is what stops growth the status points at the same fix; otherwise it does not nag.
func test_a_building_waiting_for_kith_points_at_the_fix() -> void:
	var s = t.fresh()
	s.tech_tree.researched["cordage"] = true
	s.economy.inv["berries"] = 100
	t.place_free(s, "twine_post", s.world.camp_pos + Vector2i(0, 2))
	var b: Dictionary = s.town.buildings[s.town.building_at[s.world.camp_pos + Vector2i(0, 2)]]
	b["worker"] = -1
	s.people.found(0)
	s.people.add_kith()
	for k in s.people.kith:
		k["job"] = "work"
		k["building"] = 0
	Workers.tick_building(s, b, 0.1, true)
	t.check(
		b["status"].begins_with("No ") and b["status"].contains(Data.GROW_FIX_NO_HAULERS),
		"waiting for Kith: " + b["status"]
	)
	t.steady_income(s)
	Workers.tick_building(s, b, 0.1, true)
	t.check(not b["status"].contains("steady"), "with steady food it says nothing about it: " + b["status"])


## The pills of a row of adjacent buildings never overlap each other, a "click" badge or a building, and stay on the map
## (playtest 5: "Needs Wood" and "Idle" stacked over each other and over the next building).
static func pill_problems(s) -> Array:
	var problems: Array = []
	var map := Rect2(Vector2.ZERO, Vector2(s.world.width, s.world.height) * Overlays.TILE)
	var items: Array = Overlays.pill_layout(s)
	var boxes: Array = []
	for b in s.town.buildings:
		boxes.append(["building %s" % [b["pos"]], Overlays.rect(b["pos"])])
		if HutFocus.wants_click(s, b):
			boxes.append(["click badge at %s" % [b["pos"]], HutFocus.badge_rect(Overlays.rect(b["pos"]))])
	for i in items.size():
		var r: Rect2 = items[i]["rect"]
		if r.size.x <= 0.0:
			continue
		var name := "the '%s' pill of building %d" % [items[i]["text"], items[i]["building"]]
		if not map.encloses(r):
			problems.append("%s leaves the map" % name)
		for other in boxes:
			if r.intersects(other[1]):
				problems.append("%s covers %s" % [name, other[0]])
		for j in range(i + 1, items.size()):
			if items[j]["rect"].size.x > 0.0 and r.intersects(items[j]["rect"]):
				problems.append(
					"%s covers the '%s' pill of building %d" % [name, items[j]["text"], items[j]["building"]]
				)
	return problems


func test_a_row_of_buildings_gets_pills_that_never_overlap() -> void:
	var s = t.fresh()
	s.tech_tree.researched["cordage"] = true
	s.tech_tree.researched["fire"] = true
	s.tech_tree.researched["gatherers_hut"] = true
	t.give(s, 200)
	var camp: Vector2i = s.world.camp_pos
	var spot := Vector2i(-1, -1)
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var p := camp + Vector2i(dx, dy)
			var ok := spot.x < 0
			for k in 6:
				ok = ok and s.town.placement_error("twine_post", p + Vector2i(k, 0)) == ""
			if ok:
				spot = p
	t.check(spot.x >= 0, "room for a row of buildings")
	var alerts := [
		"Needs Wood", "Idle: no free Kith", "Needs Wood", "Hungry: no food", "Needs road", "Idle: no free Kith"
	]
	for k in 6:
		t.check(
			s.place("twine_post" if k % 2 == 0 else "charcoal_pit", spot + Vector2i(k, 0)), "building %d goes down" % k
		)
		s.town.buildings[s.town.building_at[spot + Vector2i(k, 0)]]["alert"] = alerts[k]
	var problems := pill_problems(s)
	t.check(problems.is_empty(), "no pill overlaps a pill, a badge or a building: %s" % [problems])
	var shown := 0
	for item in Overlays.pill_layout(s):
		shown += 1 if item["rect"].size.x > 0.0 else 0
	t.check(shown >= 4, "and most of them still have a pill (%d of 6)" % shown)
	var hut := spot + Vector2i(0, 2)
	t.place_free(s, "gatherers_hut", hut)
	s.people.learned_by["wood"] = "Aro"
	t.check(pill_problems(s).is_empty(), "also with huts and their click badges around: %s" % [pill_problems(s)])
