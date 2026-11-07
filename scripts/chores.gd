extends RefCounted
## Teach the machine (fun-2, design-system/25-playtesting.md "No silent gates"): when the hand does the same chore over and over, the
## goal line names the building that would do it. A chore is one harvest by hand, or one click on a workshop or hut that no road
## serves yet. The log is the last CHORE_WINDOW seconds, kept on the Sim and never saved. Pure functions of the game state.

const Data = preload("res://scripts/data.gd")

const CHORE_WINDOW := 60.0  # seconds of game time the count looks back over
const CHORE_REPEATS := 5  # the same good this many times in the window is a chore
const CHORE_CAP := 64  # the log keeps no more entries than this (a hold gives one harvest every ~second at best)


## Note that the hand made `good` just now.
static func record(s, good: String) -> void:
	var entries: Array = s.economy.chore_log
	entries.append([s.seasons.time, good])
	while entries.size() > CHORE_CAP or (entries.size() > 1 and s.seasons.time - entries[0][0] > CHORE_WINDOW):
		entries.remove_at(0)


## The goods the hand has made CHORE_REPEATS or more times in the window, the most often first.
static func repeated(s) -> Array:
	var counts := {}
	for e in s.economy.chore_log:
		if s.seasons.time - e[0] <= CHORE_WINDOW:
			counts[e[1]] = counts.get(e[1], 0) + 1
	var out: Array = counts.keys().filter(func(g): return counts[g] >= CHORE_REPEATS)
	out.sort_custom(func(a, b): return counts[a] > counts[b])
	return out


## The line for the goal: what makes `good` without a hand ("" when nothing is a chore, or after the first two eras, which the
## player has learned by then).
static func note(s) -> String:
	if not (s.story.goal_list() == Data.GOALS or s.story.goal_list() == Data.GOALS_ERA2):
		return ""
	for good in repeated(s):
		var line := _machine_line(s, good)
		if line != "":
			return line
	return ""


## "A staffed Twine Post on a road makes Rope." for a made good, "A Gatherer's Hut beside the Clay, on a road, gathers it for you."
## for a raw one; if the building isn't unlocked yet the line names its tech first.
static func _machine_line(s, good: String) -> String:
	var name: String = Data.ITEMS[good]["name"]
	var type := _maker_of(good)
	if type == "":
		return ""
	var def: Dictionary = Data.BUILDINGS[type]
	var line := (
		"A staffed %s on a road makes %s." % [def["name"], name]
		if def["kind"] == "processor"
		else "A %s beside the %s, on a road, gathers it for you." % [def["name"], name]
	)
	if not s.town.unlocked(type):
		var tech: String = def["tech"]
		line = "%s: %s" % [Data.TECHS[tech]["name"] if tech != "" else def["name"], line] if tech != "" else line
		line = "Discover " + line
	return line


## The building type that makes `good` on its own: a plain processor whose recipe gives it, else the Gatherer's Hut for a raw good.
static func _maker_of(good: String) -> String:
	for type in Data.BUILDINGS:
		var def: Dictionary = Data.BUILDINGS[type]
		if def["kind"] == "processor" and def.get("out", {}).has(good) and not def.has("makes"):
			return type
	if _is_raw(good):
		return "gatherers_hut"
	return ""


static func _is_raw(good: String) -> bool:
	for tile in Data.TILES:
		if Data.TILES[tile].get("yields", "") == good:
			return true
	return false
