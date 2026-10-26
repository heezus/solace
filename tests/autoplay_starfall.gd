extends "res://tests/autoplay_bronze.gd"
## The headless player for Starfall (design-system/16-starfall.md): the era after The Falling Star, played through the game's
## own systems only. It builds the Glyph Wall, sets a guess on every copied mark, builds the Lumen Camp, an Expedition Post and
## the Market when they open, sends parties to the Wreck for the marks the Wall cannot copy, answers the strangers' questions and
## the road cards and puts the ending card away. It never edits trust, a locked set or an answer: everything goes through
## Buildings.place, Starfall.cycle_guess, Starfall.choose and the Post's orders.
## The one liberty is the oracle: it sets each guess by cycling to the word the data holds for that mark, where a player would
## read the word off the lines about where the mark was found. The scripted stage starts (scripts/dev_starts.gd) stay for UI
## tests and are not for balance; this bot makes the earned chain (stone age, Bronze Dawn, Starfall, Ironfall, Livewire) run from
## a fresh map on any seed.
## play_starfall() starts at a game that has just had The Falling Star researched and plays on until the Warning is read and the
## ending card is put away (the era over), or `max_seconds` pass.

const Expedition = preload("res://scripts/expedition.gd")
const Starfall = preload("res://scripts/starfall.gd")
const Bonuses = preload("res://scripts/bonuses.gd")

const LANTERNS_MAX := 3  # Shard Lanterns: the first by the Grove and the Shardwright, the rest by gatherers still in the dark
const GROVES := 1  # Starfruit Groves: one grows the Ward's 60 Starfruit in about 7 minutes
const PACK_ROPE := 12  # rope kept in the stores for the Post: _orders() sends a standard pack at this much

var marks := {}  # milestone -> clock
var _start_at := 0.0


## Play `game` (the Falling Star has fallen) on from clock `at` until the era is over. Returns {"won", "seconds" (the era's length),
## "marks", "log"}.
func play_starfall(game: Sim, at: float, max_seconds: float) -> Dictionary:
	goal_tech = "falling_star"  # researched: nothing to route to, so the base bot asks the stores for nothing on its behalf
	attach(game)
	clock = at
	_start_at = at
	s.tech_tree.clear()
	for tech in s.tech_tree.researched:
		known[tech] = true
	while clock - _start_at < max_seconds and not over():
		step(true)
	return {"won": over(), "seconds": clock - _start_at, "marks": marks, "log": lines}


## True once the Warning is read and the ending card is put away: Ironfall begins on the next tick.
func over() -> bool:
	return s.starfall.ended and s.starfall.pending == ""


func _aim() -> void:
	pass  # nothing to research on purpose: the era's work is the Wall


## The era's buildings cost rope and stone like any other: ask the stores for what the next one lacks, so the Twine Post and the
## huts behind it get built, and keep a pack's rope in hand once the Post stands.
func _goal_wants(list: Dictionary) -> void:
	if not s.starfall.arrived():
		return
	for type in _wanted():
		if _count(type) == 0 and s.town.unlocked(type):
			_want(list, s.town.price(type), 1)
	if Expedition.has_post(s):
		list["rope"] = maxi(list.get("rope", 0), PACK_ROPE)
	_shardwork_wants(list)


## The Shardwright works from Rope and Bronze: keep them coming for the Shardwork the Ward still asks (the base bot makes both).
func _shardwork_wants(list: Dictionary) -> void:
	var f: Starfall = s.starfall
	if not f.opens("craft") or f.ward_stands():
		return
	var need: int = Data.BUILDINGS["lumen_ward"]["cost"]["shardwork"] - int(s.economy.inv.get("shardwork", 0))
	if need > 0:
		_want(list, Data.BUILDINGS["shardwright"]["in"], need)


func _mark(key: String) -> void:
	if not marks.has(key):
		marks[key] = clock - _start_at
		lines.append("%5.0f s  == %s ==" % [clock, key])


func _decide() -> void:
	_flood_reach()
	if _lumen():
		return
	super._decide()


## One thing for the Lumen, true when it was done (the decision is spent). A waiting card comes first: the game stands behind it.
func _lumen() -> bool:
	var f: Starfall = s.starfall
	if not f.arrived():
		return false
	_mark("the strangers came")
	if not f.locked.is_empty():
		_mark("first set read")
	if f.wreck_found:
		_mark("wreck found")
	if f.ended:
		_mark("Warning read")
	if f.pending != "":
		return _answer()
	_guess()
	_orders()
	for type in _wanted():
		if _count(type) < _want_of(type) and s.town.unlocked(type) and _place_lumen(type):
			_mark("%s built" % type)
			lines.append("%5d s    + %s" % [int(clock), Data.BUILDINGS[type]["name"]])
			return true
	return false


## How many of a building the era's bot raises: one of each, but Lanterns follow the dark gatherers and Groves are two.
func _want_of(type: String) -> int:
	match type:
		"shard_lantern":
			return LANTERNS_MAX if _count(type) == 0 or _huts_in_the_dark() > 0 else 0
		"starfruit_grove":
			return GROVES
	return 1


## Gatherers' Huts no shardlight reaches.
func _huts_in_the_dark() -> int:
	var n := 0
	for b in s.town.buildings:
		if b["type"] == "gatherers_hut" and not Bonuses.lit(s, b["pos"]):
			n += 1
	return n


## Place one Lumen building: a Lantern where it lights the most huts still in the dark (the first one near the Hearth, for the Grove
## and the Shardwright), those two only inside shardlight, the rest near the Hearth.
func _place_lumen(type: String) -> bool:
	var hearth := Vector2(s.world.camp_pos)
	match type:
		"shard_lantern":
			return _place_best(
				type,
				func(p):
					var dark := 0
					for b in s.town.buildings:
						if (
							b["type"] == "gatherers_hut"
							and Vector2(b["pos"]).distance_to(Vector2(p)) <= Data.SHARDLIGHT_RADIUS
						):
							dark += 0 if Bonuses.lit(s, b["pos"]) else 1
					if _count(type) > 0 and dark == 0:
						return -INF
					return dark * 4.0 - Vector2(p).distance_to(hearth)
			)
		"starfruit_grove", "shardwright":
			return _place_best(type, func(p): return -Vector2(p).distance_to(hearth) if Bonuses.lit(s, p) else -INF)
	return _place_near_hearth(type)


## The buildings the era asks for, in the order a player would meet them.
func _wanted() -> Array:
	var f: Starfall = s.starfall
	var out: Array = ["glyph_wall"]
	if f.locked.has(Data.GLYPH_SETS[1]["id"]):
		out.append("lumen_camp")
		out.append("expedition_post")
	if f.seen.has("market_open"):
		out.append("lumen_market")
	for id in Data.ROAD_ORDER:
		if f.opens(id):
			out.append(Data.LUMEN["cards"][id]["building"])
	if f.opens("craft"):
		out.append("lumen_ward")
	return out


## Answer the card that waits: the road cards take the gift, a question takes the option that earns most trust, the ending's
## one button puts it away.
func _answer() -> bool:
	var f: Starfall = s.starfall
	var id := f.pending
	var pick := 0
	if id != "ending" and not id.begins_with("road_"):
		var best := -INF
		for i in Data.MOMENTS[id]["options"].size():
			var opt: Dictionary = Data.MOMENTS[id]["options"][i]
			if opt["trust"] > best and _can_pay(opt):
				best = opt["trust"]
				pick = i
	if f.choose(pick):
		lines.append("%5d s  answered %s with option %d" % [int(clock), id, pick])
		return true
	return false


## An option that takes food can only be taken while the stores hold enough of it.
func _can_pay(opt: Dictionary) -> bool:
	if not opt.has("food"):
		return true
	var have := 0.0
	for id in ["berries", "fish", "flour"]:
		have += s.economy.inv.get(id, 0) * Data.FOOD_VALUE[id]
	return have >= opt["food"]


## Set the right word on every mark on the Wall that is not read yet, by cycling it, as a player does with a click.
func _guess() -> void:
	var f: Starfall = s.starfall
	for g in f.copied:
		var set_id := Starfall.set_of(g)
		if set_id == "" or f.locked.has(set_id):
			continue
		var want: String = Data.GLYPHS[g]["word"]
		for i in Data.GLYPH_WORDS.size():
			if f.guesses.get(g, "") == want:
				break
			f.cycle_guess(g)


## The Post sends parties to the Wreck on its own while the Wall still lacks marks (and the stores can pay the pack).
func _orders() -> void:
	var o: Dictionary = s.starfall.orders
	if not Expedition.has_post(s):
		return
	o["target"] = "wreck"
	o["pack"] = "standard" if int(s.economy.inv.get("rope", 0)) >= PACK_ROPE else "light"
	o["keep"] = s.starfall.wreck_has_more() or not s.starfall.wreck_found
