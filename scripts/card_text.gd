extends RefCounted
## What a build card says, in plain words short enough for the card: its one-line state ("Ready", "Need 4 Wood",
## "Locked"), why a locked card is locked ("Discover Gatherer's Hut"), and which cards show at all.
## Static, and works on the Sim passed in. The wording is in Data (scripts/data/words.gd).

const Data = preload("res://scripts/data.gd")

const FONT_SIZE := 10  # the state line's size on the card


## Whether the card for `type` is on the build bar. A `story` building stays off it until its tech is on the
## research board and its parents are done (or it is built), so the Lore tab doesn't give the reveal away.
static func shown(s, type: String) -> bool:
	var def: Dictionary = Data.BUILDINGS[type]
	if not def.get("story", false):
		return true
	return s.town.unlocked(type) or s.tech_tree.requirements_met(def["tech"])


## "4 Wood" for each item of `cost` the stockpile `inv` is short of, in cost order (empty when it is enough).
static func shortfall(inv: Dictionary, cost: Dictionary) -> Array:
	var out: Array = []
	for id in cost:
		var short: int = cost[id] - inv.get(id, 0)
		if short > 0:
			out.append("%d %s" % [short, Data.ITEMS[id]["name"]])
	return out


## Why a locked card is locked: the tech to discover.
static func locked_reason(type: String) -> String:
	return Data.CARD_DISCOVER % Data.TECHS[Data.BUILDINGS[type]["tech"]]["name"]


## The card's one line: "Locked", "Placing", "Ready" (or "Drag to lay") or what is missing ("Need 4 Wood").
## It always fits `max_w` px at FONT_SIZE: two short items become "Need 4 Wood +1 more", then "Need more".
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
		options.append(Data.CARD_NEED_MORE % [short[0], short.size() - 1])
	for line in options:
		if width(line) <= max_w:
			return line
	return Data.CARD_NEED_ITEMS


static func width(text: String) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
