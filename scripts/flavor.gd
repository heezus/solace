extends RefCounted
## The warm lines the game says once each (Data.FLAVOR_STORY, Data.FLAVOR_STOCK): what has been said is kept in a `told` dictionary
## by the screen that shows them (scripts/main.gd).

const Data = preload("res://scripts/data.gd")


## Mark what a loaded run, or a run started at a stage, has already had, so none of it is said again.
static func mark_told(s, told: Dictionary) -> void:
	for id in Data.FLAVOR_STORY:
		if s.story.events.has(id):
			told[id] = true
	if s.economy.inv.get(Data.FLAVOR_STOCK_ITEM, 0) >= Data.FLAVOR_STOCK_AMOUNT:
		told["stock"] = true


## The lines whose moment has come and that have not been said yet (each is marked told as it is returned).
static func due(s, told: Dictionary) -> Array:
	var lines: Array = []
	for id in Data.FLAVOR_STORY:
		if s.story.events.has(id) and not told.has(id):
			told[id] = true
			lines.append(Data.FLAVOR_STORY[id])
	if not told.has("stock") and s.economy.inv.get(Data.FLAVOR_STOCK_ITEM, 0) >= Data.FLAVOR_STOCK_AMOUNT:
		told["stock"] = true
		lines.append(Data.FLAVOR_STOCK)
	return lines
