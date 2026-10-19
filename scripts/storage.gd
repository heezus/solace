extends RefCounted
## How much of each good the stockpile holds (design-system/24-balance.md, pick 3). Pure functions: Sim asks once a second
## and hands the answer to the Economy, which spills what comes in over it.

const Data = preload("res://scripts/data.gd")
const Ranks = preload("res://scripts/ranks.gd")

static var _price_cap := {}  # good -> the biggest single price asked of it, worked out once


## The cap on `item` with `storehouses` standing and `researched` techs learned.
static func capacity(item: String, storehouses: int, researched: Dictionary) -> int:
	var cap := Data.STORAGE_BASE + Data.STORAGE_PER_STOREHOUSE * mini(storehouses, Data.STORAGE_STOREHOUSE_MAX)
	for tech in Data.STORAGE_TECHS:
		if researched.has(tech):
			cap += Data.STORAGE_TECHS[tech]
	return maxi(cap, biggest_price(item))


## The biggest single price of `item` in any tech (a rank's price included) or building.
static func biggest_price(item: String) -> int:
	if _price_cap.is_empty():
		for id in Data.TECHS:
			var ranks: int = 3 if Ranks.has_ranks(id) else 1
			for r in range(1, ranks + 1):
				_note(Ranks.cost(id, r) if r > 1 else Data.TECHS[id].get("cost", {}))
		for id in Data.BUILDINGS:
			_note(Data.BUILDINGS[id].get("cost", {}))
	return _price_cap.get(item, 0)


static func _note(cost: Dictionary) -> void:
	for item in cost:
		_price_cap[item] = maxi(_price_cap.get(item, 0), int(cost[item]))
