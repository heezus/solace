extends RefCounted
## Why a workshop that lacks an input is still waiting for it: the one reason, from the roads, the haulers and the orders, in plain
## words for its status line (Workers.idle_reason) and a short label for the AI player's page. The reasons, first match wins:
## "out" (the stockpile has none), "no_road", "cut" (a hauler found the road torn up), "on_the_way" (a hauler is bringing it),
## "no_hauler" (none has a place at a depot its roads reach), "kept_back" (a Bring first keeps the good for other buildings),
## "order_first" (a Bring first serves other buildings ahead of it), "free_hauler" (one stands at a depot and has not set out
## yet), "walking" (they are walking back to their depot) and "busy" (every hauler at its depots is on another trip).
## Static, and works on the Sim passed in.

const Data = preload("res://scripts/data.gd")
const Roads = preload("res://scripts/roads.gd")

const SHORT := {
	"out": "stockpile out",
	"no_road": "no road",
	"cut": "road cut",
	"on_the_way": "hauler on the way",
	"no_hauler": "no hauler",
	"kept_back": "kept for an order",
	"order_first": "order serves others first",
	"free_hauler": "free hauler waiting",
	"walking": "haulers walking back",
	"busy": "haulers busy",
}


## The input of `b`'s next cycle to explain: one the stockpile has none of, else the first it is short of (an item id), "" when
## it has them all.
static func missing(s, b: Dictionary, recipe: Dictionary) -> String:
	var first := ""
	for id in recipe:
		if b["inbuf"].get(id, 0) < recipe[id]:
			if s.economy.inv.get(id, 0) == 0 and b["incoming"].get(id, 0) == 0:
				return id
			if first == "":
				first = id
	return first


## Why building `b` still lacks `item`: {code, text}. Meant for a workshop that is short of it (see `missing`).
static func of(s, b: Dictionary, item: String) -> Dictionary:
	var name: String = Data.ITEMS[item]["name"]
	var coming: int = b["incoming"].get(item, 0)
	if s.economy.inv.get(item, 0) == 0 and coming == 0:
		return _reason("out", Data.WHY_OUT % name)
	if not Roads.automated(s, b):
		return _reason("no_road", Data.WHY_NO_ROAD)
	if b["unreachable"] > 0.0:
		return _reason("cut", Data.WHY_CUT)
	if coming > 0:
		return _reason("on_the_way", Data.WHY_ON_THE_WAY % [coming, name])
	var net := Roads.net_of(s, b)
	var census: Dictionary = s.hauling.census(s)
	var free := 0
	var walking := 0
	var busy := 0
	var trips := {}
	var depot_name := ""
	for depot in Roads.depots(s):
		if not net in Roads.depot_nets(s, depot) or not census.has(depot):
			continue
		var row: Dictionary = census[depot]
		free += row["free"]
		walking += row["walking"]
		busy += row["busy"]
		for what in row["trips"]:
			trips[what] = trips.get(what, 0) + row["trips"][what]
		if depot_name == "":
			depot_name = s.hauling.names.get(depot, Data.HEARTH_NAME)
	if free + walking + busy == 0:
		return _reason("no_hauler", Data.WHY_NO_HAULER % s.hauling.names.get(Roads.depot_of(s, b), "its depot"))
	if s.livewire.kept_back(b, item):
		return _reason("kept_back", Data.WHY_KEPT % [name, s.livewire.kept_for(item)])
	var ahead: String = s.livewire.ahead_of(b)
	if ahead != "":
		return _reason("order_first", Data.WHY_AHEAD % ahead)
	if free > 0:
		return _reason("free_hauler", Data.WHY_FREE % depot_name)
	if busy == 0:
		return _reason("walking", Data.WHY_WALKING % depot_name)
	var commonest := ""
	for what in trips:
		if commonest == "" or trips[what] > trips[commonest]:
			commonest = what
	return _reason("busy", Data.WHY_BUSY % [busy, depot_name, "most " + commonest if trips.size() > 1 else commonest])


static func _reason(code: String, text: String) -> Dictionary:
	return {"code": code, "text": text}
