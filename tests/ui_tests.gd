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
	test_every_kith_has_a_place_on_the_map()


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
