extends RefCounted
## The AI player's panel hands (design-system/25-playtesting.md, "Fun playtest 3"): the Expedition Post's target, pack, Send and
## Keep sending, the Teardown Bench's pack parts, and a Factory Floor's recipe. Each is a button on a building's card in the real game, so
## each is a move here, and every move goes through the same call the button makes (Expedition.send, Teardown.prioritize/deliver,
## Buildings.cycle_floor). `lines` is the page's part for them, `move` runs one and says why it was refused ("" when it was taken).
## tests/clarity_tests.gd checks that every panel part with a button has a move.

const Data = preload("res://scripts/data.gd")
const Expedition = preload("res://scripts/expedition.gd")
const FloorRecipe = preload("res://scripts/floor_recipe.gd")
const Finds = preload("res://scripts/teardown_finds.gd")
const Picker = preload("res://scripts/expedition_picker.gd")

const MOVES := ["expedition", "bench", "floor"]
## Each part of a building's card that has buttons (scripts/building_panel.gd `parts`, those with a `changed` signal) and the table
## move that presses them. tests/clarity_tests.gd fails when a new part has no entry, so a card cannot ship without a hand for the table.
const PANEL_MOVES := {
	"focus": "focus",
	"trade": "trade",
	"glyphs": "guess",
	"post": "expedition",
	"bench": "bench",
	"floor": "floor",
	"fuel": "fuel",
	"places": "haulers",
	"orders": "order",
}


## The page lines for the Post, the Bench and any Factory Floors ([] while the town has none of them).
static func lines(s) -> Array:
	var out: Array = []
	if Expedition.has_post(s):
		out.append_array(_post_lines(s))
	if s.teardown.has_bench():
		out.append_array(_bench_lines(s))
	for i in s.town.buildings.size():
		var b: Dictionary = s.town.buildings[i]
		if Data.BUILDINGS[b["type"]].has("floor"):
			var names: Array = []
			for t in FloorRecipe.options(s.town, b):
				names.append("%s%s" % [t, " (now)" if t == b["make"] else ""])
			out.append(
				(
					'FACTORY FLOOR at (%d,%d) copies %s; it can copy: %s (move "floor" steps to the next)'
					% [b["pos"].x, b["pos"].y, b["make"], ", ".join(names)]
				)
			)
	return out


static func _post_lines(s) -> Array:
	var o: Dictionary = s.starfall.orders
	var plan := Expedition.plan(s)
	var targets: Array = []
	for id in Data.TARGET_ORDER:
		if Finds.target_listed(s, id):
			targets.append("%s = %s" % [id, Data.TARGETS[id]])
	var packs: Array = []
	for id in Data.PACK_ORDER:
		packs.append("%s = %s (%s)" % [id, Data.PACKS[id]["name"], Expedition.cost_text(id)])
	var out: Array = [
		(
			'EXPEDITION POST (move "expedition"): '
			+ Picker.target_text(s)
			+ ". "
			+ Picker.pack_text(s)
			+ ". "
			+ Picker.keep_text(s)
		)
	]
	var trip := Picker.trip_text(plan, s)
	out.append(
		(
			"  "
			+ (
				"A party can go: " + trip
				if plan["ok"]
				else "No party can go: " + plan["why"] + (" " + trip if trip != "" else "")
			)
		)
	)
	out.append("  targets: " + ", ".join(targets) + "; packs: " + "; ".join(packs))
	out.append("  parties out now: %d; orders are %s" % [Expedition.count(s), str(o)])
	return out


static func _bench_lines(s) -> Array:
	var t = s.teardown
	var out: Array = []
	var queue: Array = []
	for id in t.bench:
		queue.append(Data.PARTS[id]["name"])
	out.append(
		(
			'TEARDOWN BENCH (move "bench"): on the bench (%d of %d): %s'
			% [t.bench.size(), Data.BENCH_SLOTS, ", ".join(queue) if not queue.is_empty() else "nothing"]
		)
	)
	for id in t.pack:
		out.append("  in the pack: %s = %s" % [id, _card(s, id)])
	return out


static func _card(s, id: String) -> String:
	var lesson: Dictionary = Data.LESSONS[id]
	if s.teardown.knows(id):
		return "%s (its Lesson is learned: only scrap)" % Data.PARTS[id]["name"]
	return "%s (holds the Lesson %s: %s)" % [Data.PARTS[id]["name"], lesson["name"], lesson["teaches"]]


## Run one panel move; returns why it was refused, "" when it was taken.
static func move(s, m: Dictionary) -> String:
	match str(m.get("do", "")):
		"expedition":
			return _expedition(s, m)
		"bench":
			return _bench(s, m)
		"floor":
			var i := -1
			for j in s.town.buildings.size():
				if s.town.buildings[j]["pos"] == Vector2i(int(m.get("x", -1)), int(m.get("y", -1))):
					i = j
			if i < 0 or not Data.BUILDINGS[s.town.buildings[i]["type"]].has("floor"):
				return "no Factory Floor stands there"
			return "" if s.town.cycle_floor(i) else "the Floor has only one workshop it can copy yet"
	return "not a panel move"


static func _expedition(s, m: Dictionary) -> String:
	if not Expedition.has_post(s):
		return "no Expedition Post stands yet"
	var o: Dictionary = s.starfall.orders
	if m.has("target"):
		var target := str(m["target"])
		if not target in Data.TARGET_ORDER or not Finds.target_listed(s, target):
			return "no such target to go to (see EXPEDITION POST for the listed ones)"
		o["target"] = target
	if m.has("pack"):
		if not str(m["pack"]) in Data.PACK_ORDER:
			return "no such pack (light, standard or heavy)"
		o["pack"] = str(m["pack"])
	if m.has("keep"):
		o["keep"] = bool(m["keep"])
	if bool(m.get("send", false)):
		var plan := Expedition.plan(s)
		if not plan["ok"]:
			return plan["why"]
		s.events.append(Expedition.send(s))  # the Send button's own call
	return ""


static func _bench(s, m: Dictionary) -> String:
	if not s.teardown.has_bench():
		return "no Teardown Bench stands yet"
	var id := str(m.get("part", ""))
	if not id in s.teardown.pack:
		return "no such part in the pack (see TEARDOWN BENCH)"
	s.teardown.prioritize(id)  # a click on the part's card
	if bool(m.get("carry", false)):
		s.teardown.deliver(id)  # the Carry it by hand button
	return ""
