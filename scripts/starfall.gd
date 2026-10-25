extends RefCounted
## The Starfall block: the era after the Falling Star (design-system/16-starfall.md), stage 1. The star comes down in the
## east after a silence, strangers walk out of the fog, and while a Glyph Wall stands the Kith copy the marks the strangers
## show them. The player guesses what each mark means (`guesses`); every CHECK_SECONDS the Kith talk it over, and when all
## three marks of a set are right at once the set is read (`locked`). The first set gives the strangers' name and opens the
## Lumen Camp. A hidden `trust` (0 to 100, never shown) is moved by what is built and read, and shows only in how close the
## strangers stand and how much they say about each mark. It only reads the Buildings block; Sim starts it when the Falling
## Star falls (`begin`), ticks it, and connects its two signals. What it says is in Data (scripts/data/starfall.gd).
## Stage 3 adds three moments the strangers ask (Data.MOMENTS: the Hunger, the Shards, the Warning), each a card with a
## choice that moves trust, and the end of the era: the sixth set, the Warning, ends it with the lean (allies, neighbours or
## enemies, read off trust) and the first Bloom sign in the east.
## Stage 4 adds the Lumen Market (trade, open once the Lumen would trade), the shared shrine and the Guard Post: the first
## two lift trust, the last wears it down and speeds the Kith round it (Bonuses).
## Signals: said(message) is a line for the event log; moment(id) is a story moment (Data.STORY_EVENTS) for Story.

signal said(message: String)
signal moment(id: String)

const Data = preload("res://scripts/data.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Economy = preload("res://scripts/economy.gd")

## The story id a stage 4 building records the first time it stands (the Market has its own: market_open).
const STAND_STORY := {"shared_shrine": "shrine_raised", "guard_post": "guard_raised"}

var stage := ""  # "" before the star falls, then "falling", "landed" and "arrived"
var clock := 0.0  # seconds in the stage (falling and landed)
var guests := false  # a Cairn stood before the star fell: the strangers came as guests
var trust := 0.0  # 0 to Data.TRUST_MAX, hidden
var copied: Array = []  # glyph ids on the Wall, in the order they were copied
var guesses: Dictionary = {}  # glyph id -> the word the player has set on it
var locked: Dictionary = {}  # set id (Data.GLYPH_SETS' "id") -> true once the set is read
var copy_clock := 0.0
var check_clock := 0.0
var camp_seen := false  # the Lumen Camp has been counted once (the one-time trust step)
var seen: Dictionary = {}  # the shrine, Guard Post and Market counted once, and "market_open" once the Lumen would trade
var wreck := Vector2i(-1, -1)  # where the ship came down (set when the star falls): hidden in the fog until a party reaches it
var wreck_found := false
var post_clock := 0.0  # seconds since a standing order last looked for a chance to send (Expedition.auto)
var orders := {"target": "wreck", "pack": "standard", "keep": false}  # the Expedition Post's standing choices
var pending := ""  # a moment (Data.MOMENT_ORDER) or "ending" that waits for the player's answer: the game is paused behind it
var answered: Dictionary = {}  # moment id -> the index of the option chosen
var wait_clock := 0.0  # seconds since the set the next moment follows was read
var dim_left := 0.0  # seconds the Cairn's shardlight is lent away (the Shards)
var dark_left := 0.0  # seconds the workshops keep dark (the Warning)
var ended := false  # the Warning is read: the era is over
var lean := ""  # "allies", "neighbours" or "enemies" once the era ends (Data.LEANS)
var bloom := Vector2i(-1, -1)  # where the first Bloom sign stands
var roads: Dictionary = {}  # gift set id -> "accept" or "refuse": the road taken (Data.ROAD_ORDER); a set read with no entry was taken
var road_queue: Array = []  # gift sets read and waiting for the player's road, one card at a time
var twin_lit: Dictionary = {}  # gift set id -> true while a refused gift's twin has its price paid
var twin_paid: Dictionary = {}  # gift set id -> true once a twin's one-time price is paid
var twin_clock := 0.0  # seconds since the twins' upkeep was last paid (Data.TWIN_EVERY)
var pops: Array = []  # short texts the map floats over the Hearth ("+6 trust"); main takes them every frame
var _stock: Economy  # for the one thing a moment can take: food
var _town: Buildings


func _init(town: Buildings, stock: Economy = null) -> void:
	_town = town
	_stock = stock


## The Falling Star fell: the silence starts. `friendly` is the run flag of a Cairn built first.
func begin(friendly: bool, wreck_tile := Vector2i(-1, -1)) -> void:
	if stage != "":
		return
	wreck = wreck_tile
	stage = "falling"
	clock = 0.0
	guests = friendly
	trust = Data.TRUST_START_GUESTS if friendly else Data.TRUST_START_WARY


func arrived() -> bool:
	return stage == "arrived"


## What the Kith call the strangers now: the name is theirs once the first set is read.
func people_word() -> String:
	return Data.LUMEN_NAME if locked.has(Data.GLYPH_SETS[1]["id"]) else Data.STRANGERS_NAME


## Move trust by `amount`, never out of 0 to Data.TRUST_MAX. A step of a whole point or more floats over the Hearth ("+6 trust").
func nudge(amount: float) -> void:
	var before := trust
	trust = clampf(trust + amount, 0.0, Data.TRUST_MAX)
	if absf(trust - before) >= 1.0 and stage == "arrived":
		pops.append(Data.TRUST_POP % int(roundf(trust - before)))
		if pops.size() > 12:  # nothing draws them in a headless run: keep the list short
			pops.pop_front()


## True once the Lumen can be named (the first set is read): only then is there anyone to show a word for.
func trust_known() -> bool:
	return locked.has(Data.GLYPH_SETS[1]["id"])


## The word for how the Lumen stand with the Kith now (Data.TRUST_WORDS): the hidden number, never shown as a number.
func trust_word() -> String:
	for step in Data.TRUST_WORDS:
		if trust < step[0]:
			return step[1]
	return Data.TRUST_WORDS.back()[1]


func tick(delta: float) -> void:
	match stage:
		"falling":
			clock += delta
			if clock >= Data.LANDING_DELAY:
				stage = "landed"
				clock = 0.0
				said.emit(Data.LANDED_LINE)
				moment.emit("star_landed")
		"landed":
			clock += delta
			if clock >= Data.ARRIVAL_DELAY:
				stage = "arrived"
				clock = 0.0
				said.emit(Data.ARRIVED_GUESTS if guests else Data.ARRIVED_WARY)
				moment.emit("lumen_arrived")
		"arrived":
			_tick_arrived(delta)


func _tick_arrived(delta: float) -> void:
	dim_left = maxf(dim_left - delta, 0.0)
	dark_left = maxf(dark_left - delta, 0.0)
	_tick_roads(delta)
	_tick_moments(delta)
	if has_building("glyph_wall"):
		copy_clock += delta
		if copy_clock >= Data.COPY_SECONDS:
			copy_clock -= Data.COPY_SECONDS
			var next := _next_to_copy()
			if next != "":
				copied.append(next)
				said.emit(Data.COPIED_LINE)
	check_clock += delta
	if check_clock >= Data.CHECK_SECONDS:
		check_clock -= Data.CHECK_SECONDS
		check()
	if has_building("lumen_camp"):
		if not camp_seen:
			camp_seen = true
			nudge(Data.TRUST_CAMP)
			said.emit(Data.CAMP_BUILT_LINE)
		nudge(Data.TRUST_CAMP_PER_MINUTE * delta / 60.0)
	_tick_standing(delta)


## The stage 4 buildings that move trust. The Lumen would trade once the name is read and trust has reached
## Data.MARKET_OPEN_TRUST, which opens the Market card. A standing Market lifts trust only to a ceiling (trade alone
## makes neighbours), the shrine lifts it for good and the Guard Post wears it down.
func _tick_standing(delta: float) -> void:
	if (
		not seen.has("market_open")
		and locked.has(Data.GLYPH_SETS[1]["id"])
		and trust >= Data.MARKET_OPEN_TRUST
		and refusals() < Data.ROAD_ORDER.size()
	):
		seen["market_open"] = true
		said.emit(Data.MARKET_OPEN_LINE)
		moment.emit("market_open")
	_stand("lumen_market", 0.0, Data.MARKET_TRUST_PER_MINUTE, Data.MARKET_BUILT_LINE, delta, Data.MARKET_TRUST_CAP)
	_stand("shared_shrine", Data.TRUST_SHRINE, Data.TRUST_SHRINE_PER_MINUTE, Data.SHRINE_BUILT_LINE, delta)
	_stand("guard_post", Data.TRUST_GUARD, Data.TRUST_GUARD_PER_MINUTE, Data.GUARD_BUILT_LINE, delta)


## A building that moves trust: counted once when it first stands (a step, a line, a story id), then a little each minute.
## A rise stops at `cap`, a fall never does.
func _stand(type: String, step: float, per_minute: float, line: String, delta: float, cap := Data.TRUST_MAX) -> void:
	if not has_building(type):
		return
	if not seen.has(type):
		seen[type] = true
		nudge(step)
		said.emit(line)
		if Data.STORY_EVENTS.has(STAND_STORY.get(type, "")):
			moment.emit(STAND_STORY[type])
	if per_minute < 0.0 or trust < cap:
		nudge(per_minute * delta / 60.0)


## The next moment to ask, "" when none is left (or the era is over).
func next_moment() -> String:
	if ended:
		return ""
	for id in Data.MOMENT_ORDER:
		if not answered.has(id):
			return id
	return ""


## Count down to the next moment once the set it follows is read, and put it up (pending) when the time comes.
func _tick_moments(delta: float) -> void:
	var id := next_moment()
	if pending != "" or id == "" or not locked.has(Data.MOMENTS[id]["after"]):
		return
	wait_clock += delta
	if wait_clock >= Data.MOMENTS[id]["wait"]:
		wait_clock = 0.0
		pending = id
		said.emit(Data.MOMENT_ASKED_LINE % Data.MOMENTS[id]["title"])


## The options of the moment waiting for an answer, [] when none is (the ending has its one button).
func pending_options() -> Array:
	if pending == "ending":
		return [{"label": Data.ENDING_BUTTON, "note": ""}]
	if pending.begins_with("road_"):
		var id := pending.trim_prefix("road_")
		return [
			{
				"label": Data.ROAD_TAKE % Data.LUMEN_GIFTS[id]["name"],
				"note": Data.ROAD_TAKE_NOTE % Data.LUMEN_GIFTS[id]["note"]
			},
			{"label": Data.ROAD_KEEP % Data.TWINS[id]["name"], "note": Data.ROAD_KEEP_NOTE % Data.TWINS[id]["note"]},
		]
	return Data.MOMENTS[pending]["options"] if pending != "" else []


## What the card for the waiting question says: {"title", "text", "says", "note"} (the ending adds a line for the roads taken).
func pending_card() -> Dictionary:
	if pending == "ending":
		var text: String = Data.ENDING_TEXT
		if refusals() > 0:
			text += " " + Data.ROAD_ENDING_LINE % [refusals(), Data.ROAD_ORDER.size()]
		return {"title": Data.ENDING_TITLE, "text": text, "says": Data.ENDING_SAYS, "note": Data.ENDING_NOTE}
	if pending.begins_with("road_"):
		var road: Dictionary = Data.TWINS[pending.trim_prefix("road_")]
		return {"title": Data.ROAD_TITLE, "text": road["ask"], "says": road["says"], "note": ""}
	var m: Dictionary = Data.MOMENTS[pending]
	var text2: String = m["text"]
	if pending == "warning" and refusals() > 0:
		text2 += " " + Data.ROAD_WARNING_LINE
	return {"title": m["title"], "text": text2, "says": m.get("says", ""), "note": ""}


## Answer the waiting moment with option `index`. Moves trust, takes what the option costs, says its line and records its
## story id. The ending's one button only puts the card away. False when nothing waits or the index is wrong.
func choose(index: int) -> bool:
	if pending == "":
		return false
	if pending == "ending":
		pending = ""
		return true
	if pending.begins_with("road_"):
		return _choose_road(index)
	var options: Array = Data.MOMENTS[pending]["options"]
	if index < 0 or index >= options.size():
		return false
	var opt: Dictionary = options[index]
	nudge(opt["trust"])
	if opt.has("food"):
		_take_food(opt["food"])
	dim_left = maxf(dim_left, opt.get("dim", 0.0))
	dark_left = maxf(dark_left, opt.get("dark", 0.0))
	said.emit(opt["line"])
	moment.emit(opt["story"])
	answered[pending] = index
	pending = ""
	return true


## Take food worth about `amount` out of the stockpile: berries first, then fish, then flour. Short stores give what they have.
func _take_food(amount: float) -> void:
	if _stock == null:
		return
	var left := amount
	for id in ["berries", "fish", "flour"]:
		var each: float = Data.FOOD_VALUE[id]
		var n := mini(_stock.inv.get(id, 0), ceili(left / each))
		if n > 0:
			_stock.pay({id: n}, "story")
		left -= n * each
		if left <= 0.0:
			return


## True while the Cairn's light is lent away (the Shards): the shardlight gifts do nothing.
func dimmed() -> bool:
	return dim_left > 0.0


## True while the Kith keep dark (the Warning): workshops run slower.
func dark() -> bool:
	return dark_left > 0.0


## The lean at this trust: allies, neighbours or enemies (Data.LEANS), never a number.
func lean_now() -> String:
	var n := refusals()
	if n >= Data.ROAD_ORDER.size():
		return "enemies"  # every gift refused: no friendship, whatever the trust
	if trust >= Data.LEAN_ALLIES and n == 0:
		return "allies"
	return "neighbours" if trust >= Data.LEAN_NEIGHBOURS else "enemies"


## True while a building of `type` stands.
func has_building(type: String) -> bool:
	for b in _town.buildings:
		if b["type"] == type:
			return true
	return false


## The sets in the order this run's Wall meets them. The Name always leads and the Warning always comes last (the ending waits
## on it); the sets between are shuffled by where the ship came down, so a map keeps its order and gameplay random numbers are never
## touched. Before the star falls (no wreck yet) the order is the one in Data.GLYPH_SETS.
func set_order() -> Array:
	var middle: Array = []
	for n in Data.GLYPH_SETS:
		if n != 1 and Data.GLYPH_SETS[n]["id"] != Data.ENDING_SET:
			middle.append(n)
	if wreck.x >= 0:
		middle.sort_custom(func(a, b): return _scramble(a * 10) < _scramble(b * 10))
	var out: Array = [1] + middle
	for n in Data.GLYPH_SETS:
		if Data.GLYPH_SETS[n]["id"] == Data.ENDING_SET:
			out.append(n)
	return out


## The marks of set `n` in the order the Wall gets them (shuffled like the sets).
func glyph_order(n: int) -> Array:
	var out: Array = Data.GLYPH_SETS[n]["glyphs"].duplicate()
	if wreck.x >= 0:
		out.sort_custom(func(a, b): return _scramble(a.hash() % 997 + n) < _scramble(b.hash() % 997 + n))
	return out


## 1 for the first set the Wall meets, up to the count of sets: the label an unread set wears in place of its name.
func set_number(set_id: String) -> int:
	var order := set_order()
	for i in order.size():
		if Data.GLYPH_SETS[order[i]]["id"] == set_id:
			return i + 1
	return 0


## A fixed scramble of `k` with where the ship came down: the same number every time for a map.
func _scramble(k: int) -> int:
	return absi(((wreck.x + 7) * 73856093) ^ ((wreck.y + 11) * 19349663) ^ (k * 83492791)) % 1000003


## The first glyph of the first unread set that is not on the Wall yet, "" when every mark is copied. Only the sets the
## survivors show are copied by the Wall itself; the rest come home from the Wreck (add_finds).
func _next_to_copy() -> String:
	for n in set_order():
		var gset: Dictionary = Data.GLYPH_SETS[n]
		if locked.has(gset["id"]) or gset["source"] != "survivors":
			continue
		for g in glyph_order(n):
			if not copied.has(g):
				return g
	return ""


## The Kith talk the guesses over: a set is read when all its marks are on the Wall and every guess is right. Never one
## mark at a time. True when a set was read just now.
func check() -> bool:
	var got := false
	for n in Data.GLYPH_SETS:
		var gset: Dictionary = Data.GLYPH_SETS[n]
		if locked.has(gset["id"]):
			continue
		var right := true
		for g in gset["glyphs"]:
			right = right and copied.has(g) and guesses.get(g, "") == Data.GLYPHS[g]["word"]
		if right and gset["id"] == Data.ENDING_SET and not may_end():
			continue
		if right:
			locked[gset["id"]] = true
			got = true
			if Data.TWINS.has(gset["id"]):
				road_queue.append(gset["id"])  # the gift's line and the trust it brings wait for the player's road
			else:
				nudge(Data.TRUST_SET)
			if n == 1:
				said.emit(Data.READ_LINE % Data.LUMEN_NAME)
				said.emit(Data.LEAD_NAMED_LINE % [Data.LEAD_NAME, Data.LEAD_NAME])
			elif gset["id"] == Data.ENDING_SET:
				_end_era()
			moment.emit("%s_read" % gset["id"])
	return got


## How many of the strangers' questions (and road cards) still stand between the Kith and the Warning, at least 1 while
## `may_end` is false and never more than the questions in all.
func questions_left() -> int:
	var left := (
		Data.MOMENT_ORDER.size() - answered.size() + road_queue.size() + (1 if pending.begins_with("road_") else 0)
	)
	return clampi(left, 1, Data.MOMENT_ORDER.size())


## True when every mark of the Warning is on the Wall with its right word set.
func warning_right() -> bool:
	for g in Data.GLYPH_SETS.values().filter(func(x): return x["id"] == Data.ENDING_SET)[0]["glyphs"]:
		if not copied.has(g) or guesses.get(g, "") != Data.GLYPHS[g]["word"]:
			return false
	return true


## The Warning cannot be read until the strangers' three questions are answered and none waits on the player.
func may_end() -> bool:
	return pending == "" and road_queue.is_empty() and answered.size() == Data.MOMENT_ORDER.size()


## The Warning is read: the era ends. The lean is the trust now, a Bloom sign stands at the edge of the fog and the ending
## card goes up (pending "ending"). The game keeps running behind it.
func _end_era() -> void:
	ended = true
	lean = lean_now()
	bloom = _bloom_tile()
	pending = "ending"
	said.emit(Data.WARNING_LINE)
	said.emit(Data.BLOOM_LINE)
	moment.emit(Data.LEANS[lean])
	moment.emit("bloom_seen")


## Where the first Bloom sign grows: a few tiles from the Wreck, north of it (south when that would leave the map).
func _bloom_tile() -> Vector2i:
	if wreck.x < 0:
		return Vector2i(-1, -1)
	var up := wreck.y - Data.BLOOM_DISTANCE
	return Vector2i(wreck.x - 1, up if up >= 1 else wreck.y + Data.BLOOM_DISTANCE)


## True once the set called `set_id` is read: its gift (Data.LUMEN_GIFTS) is in effect.
func gift(set_id: String) -> bool:
	return locked.has(set_id) and roads.get(set_id, "") != "refuse" and not road_queue.has(set_id)


## True once the set called `set_id` is read, whether the Kith took its gift or not (a tech may wait on it).
func read(set_id: String) -> bool:
	return locked.has(set_id)


## True while a refused gift's Kith twin has its price paid and is at work.
func twin(set_id: String) -> bool:
	return roads.get(set_id, "") == "refuse" and twin_lit.has(set_id)


## The gift's help is in effect, from the gift itself or its twin (the Healer's leaves reach the Kith through here).
func boon(set_id: String) -> bool:
	return gift(set_id) or twin(set_id)


## How many gifts the Kith refused.
func refusals() -> int:
	var n := 0
	for id in roads:
		n += int(roads[id] == "refuse")
	return n


## Put the first gift waiting for a road up as a card once nothing else is being asked, and pay the twins' upkeep each minute.
func _tick_roads(delta: float) -> void:
	if pending == "" and not road_queue.is_empty():
		pending = "road_" + String(road_queue[0])
		said.emit(Data.ROAD_ASKED_LINE % Data.LUMEN_GIFTS[road_queue[0]]["name"])
	twin_clock += delta
	if twin_clock >= Data.TWIN_EVERY:
		twin_clock -= Data.TWIN_EVERY
		for id in Data.ROAD_ORDER:
			if roads.get(id, "") == "refuse":
				_feed(id)


## The answer to a gift's card: 0 takes the gift (trust rises, its line is said), 1 keeps to the Kith way (trust falls, the twin starts).
func _choose_road(index: int) -> bool:
	if index < 0 or index > 1:
		return false
	var id := pending.trim_prefix("road_")
	road_queue.erase(id)
	pending = ""
	if index == 0:
		roads[id] = "accept"
		nudge(Data.TRUST_SET)
		said.emit(Data.LUMEN_GIFTS[id]["line"])
	else:
		roads[id] = "refuse"
		nudge(Data.TRUST_REFUSE)
		said.emit(Data.TWINS[id]["line"])
		_feed(id)
	return true


## Pay a refused gift's twin: its price once, or its upkeep for the minute to come. A twin the stores cannot pay for goes out
## (and says so once); one with nothing to burn it for (no Cairn, no Forge) simply waits.
func _feed(id: String) -> void:
	var twin_def: Dictionary = Data.TWINS[id]
	if twin_def.has("once"):
		if not twin_paid.has(id):
			if not _pay(twin_def["once"]):
				if not seen.has("owed_" + id):
					seen["owed_" + id] = true
					said.emit(Data.TWIN_OWED_LINE % [twin_def["name"], twin_def["cost"]])
				return
			twin_paid[id] = true
			said.emit(Data.TWIN_PLANTED_LINE % twin_def["name"])
		twin_lit[id] = true
		return
	var feed: Dictionary = twin_def["feed"]
	var units := 1 if feed["per"] == "" else _count(feed["per"])
	if units == 0:
		twin_lit.erase(id)
		return
	if _pay({feed["good"]: int(feed["n"]) * units}):
		twin_lit[id] = true
	elif twin_lit.has(id):
		twin_lit.erase(id)
		said.emit(Data.TWIN_OUT_LINE % twin_def["name"])


## Take `cost` (good -> count) from the stores if every part is there; false, and nothing taken, if not.
func _pay(cost: Dictionary) -> bool:
	if _stock == null:
		return false
	for good in cost:
		if _stock.inv.get(good, 0) < int(cost[good]):
			return false
	for good in cost:
		_stock.pay({good: int(cost[good])}, "twin")
	return true


## How many buildings of `type` stand.
func _count(type: String) -> int:
	var n := 0
	for b in _town.buildings:
		n += int(b["type"] == type)
	return n


## A party came back from the Wreck: put up to `count` more of its marks on the Wall (the first unread sets first). Returns
## how many were added, 0 once every mark of the sets the Wreck holds is known.
func add_finds(count: int) -> int:
	var added := 0
	for n in set_order():
		var gset: Dictionary = Data.GLYPH_SETS[n]
		if gset["source"] != "wreck" or locked.has(gset["id"]):
			continue
		for g in glyph_order(n):
			if added < count and not copied.has(g):
				copied.append(g)
				added += 1
	return added


## True while the Wreck still holds a mark nobody has copied.
func wreck_has_more() -> bool:
	for n in Data.GLYPH_SETS:
		var gset: Dictionary = Data.GLYPH_SETS[n]
		if gset["source"] == "wreck" and not locked.has(gset["id"]):
			for g in gset["glyphs"]:
				if not copied.has(g):
					return true
	return false


## Move the guess on mark `glyph` to the next word of the list. Only a copied mark in an unread set can be guessed.
## Returns the word it now holds, or "" when nothing changed.
func cycle_guess(glyph: String) -> String:
	if not copied.has(glyph) or set_of(glyph) == "" or locked.has(set_of(glyph)):
		return ""
	var taken := _read_words()
	var at: int = Data.GLYPH_WORDS.find(guesses.get(glyph, ""))
	var word := ""
	for i in range(1, Data.GLYPH_WORDS.size() + 1):
		var next: String = Data.GLYPH_WORDS[(at + i) % Data.GLYPH_WORDS.size()]
		if next not in taken:
			word = next
			break
	if word == "":
		return ""
	guesses[glyph] = word
	return word


## The words of every mark already read: they are settled, so a guess on another mark skips them.
func _read_words() -> Array:
	var out: Array = []
	for n in Data.GLYPH_SETS:
		var gset: Dictionary = Data.GLYPH_SETS[n]
		if locked.has(gset["id"]):
			for g in gset["glyphs"]:
				out.append(Data.GLYPHS[g]["word"])
	return out


## The id of the set `glyph` belongs to, "" for an unknown mark.
static func set_of(glyph: String) -> String:
	for n in Data.GLYPH_SETS:
		if glyph in Data.GLYPH_SETS[n]["glyphs"]:
			return Data.GLYPH_SETS[n]["id"]
	return ""


## Where the mark was found, as lines: the first always, the second for guests, the third once trust is up.
func found_lines(glyph: String) -> Array:
	var all: Array = Data.GLYPHS[glyph]["found"]
	var n := 1 + (1 if guests else 0) + (1 if trust >= Data.CONTEXT_TRUST else 0)
	return all.slice(0, mini(n, all.size()))


## How many marks of the set called `set_id` are on the Wall, and how many it has.
func progress(set_id: String) -> Vector2i:
	for n in Data.GLYPH_SETS:
		var gset: Dictionary = Data.GLYPH_SETS[n]
		if gset["id"] == set_id:
			var have := 0
			for g in gset["glyphs"]:
				have += 1 if copied.has(g) else 0
			return Vector2i(have, gset["glyphs"].size())
	return Vector2i.ZERO


## Where the strangers stand, in tiles: three spots around `hearth` (further off while trust is low), or around the Lumen
## Camp at `camp` once one stands (Vector2i(-1, -1) for none). Pure, so a test can check it.
func survivor_spots(hearth: Vector2i, camp: Vector2i) -> Array:
	var around := Vector2(hearth) + Vector2(0.5, 0.5)
	var radius := lerpf(Data.SURVIVOR_STAND, Data.SURVIVOR_CLOSE, trust / Data.TRUST_MAX)
	if camp.x >= 0:
		around = Vector2(camp) + Vector2(0.5, 0.5)
		radius = Data.SURVIVOR_AT_CAMP
	var out: Array = []
	for i in Data.SURVIVORS:
		out.append(around + Vector2.from_angle(PI * 0.9 + TAU * i / Data.SURVIVORS) * radius)
	return out


func to_dict() -> Dictionary:
	return {
		"stage": stage,
		"clock": snappedf(clock, 0.001),
		"guests": guests,
		"trust": snappedf(trust, 0.001),
		"copied": copied.duplicate(),
		"guesses": guesses.duplicate(),
		"locked": locked.duplicate(),
		"copy_clock": snappedf(copy_clock, 0.001),
		"check_clock": snappedf(check_clock, 0.001),
		"camp_seen": camp_seen,
		"seen": seen.duplicate(),
		"wreck": [wreck.x, wreck.y],
		"wreck_found": wreck_found,
		"orders": orders.duplicate(),
		"pending": pending,
		"answered": answered.duplicate(),
		"wait_clock": snappedf(wait_clock, 0.001),
		"dim_left": snappedf(dim_left, 0.001),
		"dark_left": snappedf(dark_left, 0.001),
		"ended": ended,
		"lean": lean,
		"roads": roads.duplicate(),
		"road_queue": road_queue.duplicate(),
		"twin_lit": twin_lit.duplicate(),
		"twin_paid": twin_paid.duplicate(),
		"twin_clock": snappedf(twin_clock, 0.001),
		"bloom": [bloom.x, bloom.y],
	}


func from_dict(d: Dictionary) -> void:
	stage = String(d.get("stage", ""))
	clock = float(d.get("clock", 0.0))
	guests = bool(d.get("guests", false))
	trust = float(d.get("trust", 0.0))
	copied = []
	for g in d.get("copied", []):
		copied.append(String(g))
	guesses = {}
	for g in d.get("guesses", {}):
		guesses[String(g)] = String(d["guesses"][g])
	locked = {}
	for k in d.get("locked", {}):
		locked[String(k)] = true
	copy_clock = float(d.get("copy_clock", 0.0))
	check_clock = float(d.get("check_clock", 0.0))
	camp_seen = bool(d.get("camp_seen", false))
	seen = {}
	for k in d.get("seen", {}):
		seen[String(k)] = true
	var w: Array = d.get("wreck", [-1, -1])
	wreck = Vector2i(int(w[0]), int(w[1]))
	wreck_found = bool(d.get("wreck_found", false))
	orders = {"target": "wreck", "pack": "standard", "keep": false}
	for k in d.get("orders", {}):
		orders[String(k)] = d["orders"][k]
	pending = String(d.get("pending", ""))
	answered = {}
	for k in d.get("answered", {}):
		answered[String(k)] = int(d["answered"][k])
	wait_clock = float(d.get("wait_clock", 0.0))
	dim_left = float(d.get("dim_left", 0.0))
	dark_left = float(d.get("dark_left", 0.0))
	ended = bool(d.get("ended", false))
	lean = String(d.get("lean", ""))
	roads = {}
	for k in d.get("roads", {}):
		roads[String(k)] = String(d["roads"][k])
	road_queue = []
	for k in d.get("road_queue", []):
		road_queue.append(String(k))
	twin_lit = {}
	for k in d.get("twin_lit", {}):
		twin_lit[String(k)] = true
	twin_paid = {}
	for k in d.get("twin_paid", {}):
		twin_paid[String(k)] = true
	twin_clock = float(d.get("twin_clock", 0.0))
	var b: Array = d.get("bloom", [-1, -1])
	bloom = Vector2i(int(b[0]), int(b[1]))
