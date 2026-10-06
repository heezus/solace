extends RefCounted
## The Starfall block: the era after the Falling Star (design-system/16-starfall.md), stage 1. The star comes down in the
## east after a silence, strangers walk out of the fog, and while a Glyph Wall stands the Kith copy the marks the strangers
## show them. The player guesses what each mark means (`guesses`); every CHECK_SECONDS the Kith talk it over, and when all
## three marks of a set are right at once the set is read (`locked`). The first set gives the strangers' name and opens the
## Lumen Camp. A hidden `trust` (0 to 100, never shown) is moved by what is built and read, and shows only in how close the
## strangers stand and how much they say about each mark. It only reads the Buildings block; Sim starts it when the Falling
## Star falls (`begin`), ticks it, and connects its two signals. What it says is in Data (scripts/data/starfall.gd).
## Signals: said(message) is a line for the event log; moment(id) is a story moment (Data.STORY_EVENTS) for Story.

signal said(message: String)
signal moment(id: String)

const Data = preload("res://scripts/data.gd")
const Buildings = preload("res://scripts/buildings.gd")

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
var wreck := Vector2i(-1, -1)  # where the ship came down (set when the star falls): hidden in the fog until a party reaches it
var wreck_found := false
var post_clock := 0.0  # seconds since a standing order last looked for a chance to send (Expedition.auto)
var orders := {"target": "wreck", "pack": "standard", "keep": false}  # the Expedition Post's standing choices
var _town: Buildings


func _init(town: Buildings) -> void:
	_town = town


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


## Move trust by `amount`, never out of 0 to Data.TRUST_MAX.
func nudge(amount: float) -> void:
	trust = clampf(trust + amount, 0.0, Data.TRUST_MAX)


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


## True while a building of `type` stands.
func has_building(type: String) -> bool:
	for b in _town.buildings:
		if b["type"] == type:
			return true
	return false


## The first glyph of the first unread set that is not on the Wall yet, "" when every mark is copied. Only the sets the
## survivors show are copied by the Wall itself; the rest come home from the Wreck (add_finds).
func _next_to_copy() -> String:
	for n in Data.GLYPH_SETS:
		var gset: Dictionary = Data.GLYPH_SETS[n]
		if locked.has(gset["id"]) or gset["source"] != "survivors":
			continue
		for g in gset["glyphs"]:
			if not copied.has(g):
				return g
	return ""


## The Kith talk the guesses over: a set is read when all its marks are on the Wall and every guess is right. Never one
## mark at a time. True when a set was read just now.
func check() -> bool:
	var read := false
	for n in Data.GLYPH_SETS:
		var gset: Dictionary = Data.GLYPH_SETS[n]
		if locked.has(gset["id"]):
			continue
		var right := true
		for g in gset["glyphs"]:
			right = right and copied.has(g) and guesses.get(g, "") == Data.GLYPHS[g]["word"]
		if right:
			locked[gset["id"]] = true
			nudge(Data.TRUST_SET)
			read = true
			if n == 1:
				said.emit(Data.READ_LINE % Data.LUMEN_NAME)
			else:
				said.emit(Data.LUMEN_GIFTS[gset["id"]]["line"])
			moment.emit("%s_read" % gset["id"])
	return read


## True once the set called `set_id` is read: its gift (Data.LUMEN_GIFTS) is in effect.
func gift(set_id: String) -> bool:
	return locked.has(set_id)


## A party came back from the Wreck: put up to `count` more of its marks on the Wall (the first unread sets first). Returns
## how many were added, 0 once every mark of the sets the Wreck holds is known.
func add_finds(count: int) -> int:
	var added := 0
	for n in Data.GLYPH_SETS:
		var gset: Dictionary = Data.GLYPH_SETS[n]
		if gset["source"] != "wreck" or locked.has(gset["id"]):
			continue
		for g in gset["glyphs"]:
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
		"wreck": [wreck.x, wreck.y],
		"wreck_found": wreck_found,
		"orders": orders.duplicate(),
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
	var w: Array = d.get("wreck", [-1, -1])
	wreck = Vector2i(int(w[0]), int(w[1]))
	wreck_found = bool(d.get("wreck_found", false))
	orders = {"target": "wreck", "pack": "standard", "keep": false}
	for k in d.get("orders", {}):
		orders[String(k)] = d["orders"][k]
