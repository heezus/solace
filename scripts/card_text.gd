extends RefCounted
## What a build card says, in plain words short enough for the card: its one-line state ("Ready", "Need 4 Wood",
## "Locked"), why a locked card is locked ("Discover Gatherer's Hut"), and which cards show at all.
## Static, and works on the Sim passed in. The wording is in Data (scripts/data/words.gd).

const Data = preload("res://scripts/data.gd")

const FONT_SIZE := 14  # the state line's size on the card


## Whether the card for `type` is on the build bar. A building with no tech, or whose tech is learned, always shows.
## Any other card stays off the bar until the tech tree has revealed its tech (`Research.visible_set()`), so a Cart
## Shed or a Trading Post doesn't appear before the Kith have found what it needs. A `story` building waits longer:
## until its tech is also reachable (its parents are done), so the Lore tab doesn't give the reveal away.
static func shown(s, type: String) -> bool:
	var def: Dictionary = Data.BUILDINGS[type]
	if def["tech"] == "" or s.town.unlocked(type):
		return true
	if not def.get("story", false):
		return s.tech_tree.tech_visible(def["tech"])
	return s.tech_tree.requirements_met(def["tech"])


## "4 Wood" for each item of `cost` the stockpile `inv` is short of, in cost order (empty when it is enough).
static func shortfall(inv: Dictionary, cost: Dictionary) -> Array:
	var out: Array = []
	for id in cost:
		var short: int = cost[id] - inv.get(id, 0)
		if short > 0:
			out.append("%d %s" % [short, Data.ITEMS[id]["name"]])
	return out


## The names of the items of `cost` the stockpile `inv` is short of, in cost order.
static func short_names(inv: Dictionary, cost: Dictionary) -> Array:
	var out: Array = []
	for id in cost:
		if cost[id] > inv.get(id, 0):
			out.append(Data.ITEMS[id]["name"])
	return out


## Why a locked card is locked: the tech to discover. With `max_w` it is shortened to fit two lines of that width at
## FONT_SIZE (just the tech's name when "Discover ..." would need three); the card's tooltip has the whole sentence.
static func locked_reason(type: String, max_w := 0.0) -> String:
	var tech_name: String = Data.TECHS[Data.BUILDINGS[type]["tech"]]["name"]
	if repeats_name(type, tech_name):
		return Data.CARD_DISCOVER_IT  # the title above already says which
	var full: String = Data.CARD_DISCOVER % tech_name
	return full if max_w <= 0.0 or lines(full, max_w) <= 2 else tech_name


## Whether `tech_name` says the card's own title again ("Discover Gatherer's Hut" under "Gatherer's Hut").
static func repeats_name(type: String, tech_name: String) -> bool:
	var title: String = Data.BUILDINGS[type]["name"]
	return title.contains(tech_name) or tech_name.contains(title)


## How many lines `text` takes wrapped to `max_w` px at FONT_SIZE.
static func lines(text: String, max_w: float) -> int:
	var font := ThemeDB.fallback_font
	var one := font.get_height(FONT_SIZE)
	var box := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, max_w, FONT_SIZE)
	return maxi(1, roundi(box.y / one))


## The card's one line: "Locked", "Placing", "Ready" (or "Drag to lay") or what is missing ("Need 4 Wood").
## It always fits `max_w` px at FONT_SIZE: with several items short it says "Need Wood, Stone" (the amounts are in
## the price), then "Need 3 items", then "Need more".
static func state_line(s, type: String, placing: String, max_w: float) -> String:
	var def: Dictionary = Data.BUILDINGS[type]
	if not s.town.unlocked(type):
		return Data.CARD_LOCKED
	if placing == type:
		return Data.CARD_PLACING
	var short := shortfall(s.economy.inv, def["cost"])
	if short.is_empty():
		return Data.CARD_DRAG if def["kind"] in ["road", "bridge", "field"] else Data.CARD_READY
	var options: Array = [Data.CARD_NEED % ", ".join(short)]
	if short.size() > 1:
		options.append(Data.CARD_NEED_NAMES % ", ".join(short_names(s.economy.inv, def["cost"])))
		options.append(Data.CARD_NEED_COUNT % short.size())
	for line in options:
		if width(line) <= max_w:
			return line
	return Data.CARD_NEED_ITEMS


static func width(text: String) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
