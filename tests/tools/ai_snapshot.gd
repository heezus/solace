extends RefCounted
## The AI player's eyes and hands (design-system/25-playtesting.md, part 2). `text` turns a Sim into what a person would read off
## the screen; `apply` runs the moves the player wrote through the same Sim commands the game's own buttons call, and says which
## it refused. Nothing here reaches past the public commands (place, demolish, research, gather_by_hand, the cards' answers), so
## the player cannot do anything a person could not. Read-only on everything else.

const CardText = preload("res://scripts/card_text.gd")
const Data = preload("res://scripts/data.gd")
const Buildings = preload("res://scripts/buildings.gd")
const Fuel = preload("res://scripts/fuel.gd")
const WaitWhy = preload("res://scripts/wait_why.gd")

const ERAS := ["Stone age", "Bronze Dawn", "Starfall", "Ironfall", "Livewire"]
const HELP := """MOVES: write moves_<n>.json, a list. Each move is one of
  {"do":"gather","x":3,"y":4}                      hand-gather the tile (a few harvests in a row: add "times":5)
  {"do":"build","type":"gatherers_hut","x":3,"y":4}  add "focus":"wood" for a hut's item; a road or field goes down one tile at a time
  {"do":"line","type":"road","from":[3,4],"to":[9,4]}   drag a line of roads (or rails, fields...): along x first, then along y
  {"do":"pause","x":3,"y":4,"on":false}            pause or resume the building standing at that spot (use its listed position)
  {"do":"focus","x":3,"y":4,"item":"wood"}         point a gatherer's hut at another item in its reach
  {"do":"trade","x":3,"y":4,"gives":"copper_ore","gets":"coal"}   set what a market (Lumen Market, Trading Post) swaps
  {"do":"demolish","x":3,"y":4}
  {"do":"research","tech":"knapping"}
  {"do":"goal","tech":"bronze_dawn"}               set the research goal; the queue buys the techs on the way
  {"do":"season","choice":0}                       answer a Season card
  {"do":"moment","choice":0}                       answer a story moment card
  {"do":"order","item":"coal","compare":"below","number":40,"verb":"pause","target":"forge"}
                                                   write a standing order on the Order Board (needs one built; compare is below or above;
                                                   verb is pause or bring; number one of 5 10 20 30 40 60 80 100 150 200 300 500)
  {"do":"clear_order","index":0}                   tear an order up
  {"do":"fuel","x":3,"y":4,"mode":"charcoal"}       a Bloomery's or Forge's Fuel button: auto, coal or charcoal
  {"do":"haulers","x":3,"y":4,"change":1}           one more (or -1, one fewer) hauler place at the depot standing at that spot (see DEPOTS)
  {"do":"wait","seconds":30}                       let the game run (15 s when you send none); the moves after it wait for it
Also write diary_<n>.md: two or three lines on what you wanted, and how it felt (bored, pleased, stuck, surprised).
Play to win the era you are in. You see only this page."""

## What a player who reached a later era has already learned in the ones before it. The first page of a run that starts past the
## first era carries it (the run is of that player, not of someone new to the game).
const KNOWN := """WHAT YOUR KITH ALREADY KNOW (you have played the eras before this one; none of it is a hint, all of it is in your hands):
  - Pausing: a paused building stops working and its Kith go to work elsewhere (move "pause"); resume it when you want it back.
  - Standing orders: the Order Board pauses or brings first on a stock level (move "order"), once one stands.
  - Bring first: haulers carry a good to the building you name before they carry anything else.
  - Hauler places: each depot (DEPOTS) wants some haulers; you can raise or lower its count (move "haulers").
  - Storehouses: a depot nearer a far workshop shortens the haul; build one beside it.
  - Roads and carts: haulers serve buildings a road reaches; a building with no road says "Needs road".
  - Trade: a Trading Post or Lumen Market swaps one good for another (move "trade").
  - Fuel: a Bloomery or Forge burns Coal, or Charcoal at half speed (move "fuel"); Auto burns Coal while the stores have plenty.
"""


## The era now, as the name a player would see.
static func era_name(s) -> String:
	var events: Array = s.story.events
	if Data.LIVEWIRE_BEGUN in events:
		return ERAS[4]
	if Data.IRONFALL_EVENT in events:
		return ERAS[3]
	if "star_falling" in events:
		return ERAS[2]
	return ERAS[1] if "bronze_dawn" in events else ERAS[0]


## The page the player reads: `n` is the decision number, `told` what the game said since the last page, `refused` the moves it refused.
static func text(s, n: int, told: Array, refused: Array) -> String:
	var out: Array = []
	out.append("DECISION %d · game time %s · %s" % [n, _clock(s.seasons.time), era_name(s)])
	var goals: Array = s.story.goal_list()
	var at: int = s.story.current_goal()
	out.append(
		(
			"GOAL (%d of %d done): %s"
			% [s.story.done_count(), goals.size(), goals[at]["text"] if at < goals.size() else "all met"]
		)
	)
	out.append_array(_cards(s))
	out.append("")
	out.append_array(_town(s))
	out.append("")
	out.append(_map(s))
	if not told.is_empty():
		out.append("\nTHE GAME SAID: " + " / ".join(told))
	if not refused.is_empty():
		out.append("\nREFUSED LAST TIME: " + " / ".join(refused))
	out.append("\n" + HELP)
	return "\n".join(out)


## Run each move; returns the refusals (empty when all were taken). A `wait` move is read by `play`, not here.
static func apply(s, moves: Array) -> Array:
	var refused: Array = []
	for m in moves:
		if typeof(m) != TYPE_DICTIONARY:
			refused.append("not a move: %s" % str(m))
			continue
		var at := Vector2i(int(m.get("x", -1)), int(m.get("y", -1)))
		var ok := true
		match str(m.get("do", "")):
			"gather":
				for i in clampi(int(m.get("times", 1)), 1, 20):
					ok = s.gather_by_hand(at) != "" and ok
			"build":
				ok = str(m.get("type", "")) in Data.BUILDINGS and s.place(str(m["type"]), at, str(m.get("focus", "")))
				if ok and str(m.get("focus", "")) != "" and _index_at(s, at) >= 0:
					if s.town.buildings[_index_at(s, at)]["focus"] != str(m["focus"]):
						refused.append("%s (built, but it cannot take that focus here)" % JSON.stringify(m))
			"demolish":
				ok = not s.demolish(at).is_empty()
			"line":
				ok = _drag(s, m)
			"pause":
				var i := _index_at(s, at)
				ok = i >= 0
				if ok:
					s.set_paused(i, bool(m.get("on", true)))
			"trade":
				var i := _index_at(s, at)
				ok = i >= 0 and s.town.set_trade(i, str(m.get("gives", "")), str(m.get("gets", "")))
				if not ok and i >= 0:
					var why: String = s.town.trade_refusal(
						s.town.buildings[i]["type"], str(m.get("gives", "")), str(m.get("gets", ""))
					)
					refused.append("%s (%s)" % [JSON.stringify(m), why])
					continue
			"focus":
				var i := _index_at(s, at)
				ok = i >= 0 and s.town.set_focus(i, str(m.get("item", "")))
			"research":
				ok = str(m.get("tech", "")) in Data.TECHS and s.research(str(m["tech"]))
			"goal":
				ok = str(m.get("tech", "")) in Data.TECHS
				if ok:
					s.tech_tree.set_goal(str(m["tech"]))
			"season":
				ok = s.seasons.phase == "pending"
				if ok:
					s.seasons.choose(s, int(m.get("choice", 0)))
			"moment":
				ok = s.starfall.choose(int(m.get("choice", 0)))
			"fuel":
				var i := _index_at(s, at)
				ok = i >= 0 and Fuel.burns(s.town.buildings[i]) and str(m.get("mode", "")) in Data.FUEL_MODES
				if ok:
					Fuel.set_mode(s.economy, s.town.buildings[i], str(m["mode"]))
			"haulers":
				ok = s.hauling.auto.has(at) and int(m.get("change", 0)) != 0
				if ok:
					for step in absi(int(m["change"])):
						s.hauling.nudge(at, signi(int(m["change"])))
			"order":
				ok = _write_order(s, m)
			"clear_order":
				ok = int(m.get("index", -1)) >= 0 and int(m.get("index", -1)) < s.livewire.orders.size()
				if ok:
					s.livewire.clear(int(m["index"]))
			"wait":
				pass
			_:
				ok = false
		if not ok:
			var why := _why(s, m, at)
			refused.append(JSON.stringify(m) + (" (%s)" % why if why != "" else ""))
	return refused


## Why the game refused move `m` at `at`, said as the game says it to a player: a build gives the placement error with what is
## short ("Not enough materials: 12 Stone short", "Must stand on Rocks", "Bloom ground..."), the rest name what is missing.
static func _why(s, m: Dictionary, at: Vector2i) -> String:
	var kind := str(m.get("do", ""))
	var type := str(m.get("type", ""))
	match kind:
		"build":
			if not type in Data.BUILDINGS:
				return "no such building"
			return CardText.refusal(s, type, s.town.placement_error(type, at))
		"demolish":
			return "nothing of yours stands there"
		"gather":
			return "nothing to gather there, or it is out of reach of your hand"
		"fuel":
			if _index_at(s, at) < 0:
				return "no building there"
			return "only a Bloomery or a Forge has a fuel button; the mode is auto, coal or charcoal"
		"haulers":
			return "no depot stands there (see DEPOTS)"
		"pause", "focus":
			if _index_at(s, at) < 0:
				return "no building there"
			return "only a gatherer's hut takes a focus, and only on what is in its reach" if kind == "focus" else ""
	return ""


## The building standing at `at`, as its index in the town, or -1.
static func _index_at(s, at: Vector2i) -> int:
	for i in s.town.buildings.size():
		if s.town.buildings[i]["pos"] == at:
			return i
	return -1


## A dragged line: along x from `from`, then along y to `to`, as the build bar's drag does. True when any tile went down.
static func _drag(s, m: Dictionary) -> bool:
	var a = m.get("from", [])
	var b = m.get("to", [])
	if (
		str(m.get("type", "")) not in Data.BUILDINGS
		or typeof(a) != TYPE_ARRAY
		or typeof(b) != TYPE_ARRAY
		or a.size() < 2
		or b.size() < 2
	):
		return false
	var from := Vector2i(int(a[0]), int(a[1]))
	var to := Vector2i(int(b[0]), int(b[1]))
	var line: Array = []
	var x := from.x
	while x != to.x:
		line.append(Vector2i(x, from.y))
		x += signi(to.x - x)
	var y := from.y
	while y != to.y:
		line.append(Vector2i(to.x, y))
		y += signi(to.y - y)
	line.append(to)
	return s.place_line(str(m["type"]), line) > 0


## An order, written as the Board's panel would: every part picked from the short lists the panel offers.
static func _write_order(s, m: Dictionary) -> bool:
	if not s.livewire.has_board(s) or not s.livewire.add(s):
		return false
	var o: Dictionary = s.livewire.orders[-1]
	var verb := str(m.get("verb", "pause"))
	var item := str(m.get("item", ""))
	var compare := str(m.get("compare", ""))
	var number := int(m.get("number", -1))
	var target := str(m.get("target", ""))
	var ok: bool = (
		item in s.livewire.items_for(s)
		and compare in ["below", "above"]
		and number in Data.ORDER_NUMBERS
		and verb in Data.ORDER_VERB_ORDER
		and target in s.livewire.targets_for(s, verb)
	)
	if not ok:
		s.livewire.clear(s.livewire.orders.size() - 1)
		return false
	o["item"] = item
	o["compare"] = compare
	o["number"] = number
	o["verb"] = verb
	o["target"] = target
	return true


## Play a page's moves in order. A `wait` lets the game run that long (`run` is called with the seconds) before the moves after it are
## made; waits side by side count as the longest. With no `wait` the moves are made and the game runs `fallback` seconds. Returns the
## refusals, as `apply` does.
static func play(s, moves: Array, fallback: float, run: Callable) -> Array:
	var refused: Array = []
	var batch: Array = []
	var pending := 0.0  # a wait read since the last move
	var waited := false
	for m in moves:
		if typeof(m) == TYPE_DICTIONARY and m.get("do", "") == "wait":
			pending = maxf(pending, clampf(float(m.get("seconds", fallback)), 1.0, 120.0))
			continue
		if pending > 0.0:
			refused.append_array(apply(s, batch))
			batch = []
			run.call(pending)
			pending = 0.0
			waited = true
		batch.append(m)
	refused.append_array(apply(s, batch))
	if pending > 0.0:
		run.call(pending)
	elif not waited:
		run.call(fallback)
	return refused


## Seconds the moves ask to wait (the longest `wait`), or `fallback` when none does.
static func wait_of(moves: Array, fallback: float) -> float:
	var out := 0.0
	for m in moves:
		if typeof(m) == TYPE_DICTIONARY and m.get("do", "") == "wait":
			out = maxf(out, clampf(float(m.get("seconds", fallback)), 1.0, 120.0))
	return out if out > 0.0 else fallback


static func _clock(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]


## The cards waiting on an answer.
static func _cards(s) -> Array:
	var out: Array = []
	if s.starfall.pending != "":
		var options: Array = s.starfall.pending_options()
		var labels: Array = []
		for i in options.size():
			labels.append("%d = %s" % [i, options[i]["label"]])
		var title: String = s.starfall.pending_card()["title"] if s.starfall.pending != "ending" else "The end"
		out.append("CARD WAITING (moment): %s. Answer with a moment move: %s" % [title, ", ".join(labels)])
	if s.seasons.phase == "pending":
		var def: Dictionary = Data.SEASONS[s.seasons.kind]
		var labels: Array = []
		for i in def["options"].size():
			labels.append("%d = %s (%s)" % [i, def["options"][i]["label"], def["options"][i]["note"]])
		out.append(
			(
				"CARD WAITING (season, answers itself with 0 after %d s): %s. %s Options: %s"
				% [
					int(Data.SEASON_AUTO),
					def["title"],
					def["text"] % [Data.SEASON_LENGTH, Data.PEOPLE["many"]],
					"; ".join(labels)
				]
			)
		)
	elif s.seasons.phase == "active":
		out.append("SEASON ON: %s, %d s left" % [Data.SEASONS[s.seasons.kind]["title"], int(s.seasons.left)])
	return out


## "(21,9) Hearth 12 of 14": each depot's position and name, the haulers it has and the places it wants.
static func _depots(s) -> Array:
	var out: Array = []
	for depot in s.hauling.auto:
		out.append(
			(
				"(%d,%d) %s %d of %d"
				% [depot.x, depot.y, s.hauling.names.get(depot, ""), s.hauling.have(depot), s.hauling.wanted(depot)]
			)
		)
	return out


## Food, people, stock, buildings, and what can be done now.
static func _town(s) -> Array:
	var out: Array = []
	var idle := 0  # no place at all: haulers are counted as haulers, workers as at work
	var hauling := 0
	var working := 0
	for k in s.people.kith:
		match k["job"]:
			"":
				idle += 1
			"haul":
				hauling += 1
			_:
				working += 1
	out.append(
		(
			"FOOD: %d in store, lasts %s%s"
			% [
				roundi(s.economy.food_total()),
				_clock(minf(s.economy.seconds_of_food(), 3600.0)),
				", FAMINE" if s.economy.famine else ""
			]
		)
	)
	out.append(
		(
			"KITH: %d (%d at work, %d hauling, %d idle), room for %d"
			% [s.people.kith.size(), working, hauling, idle, s.town.housing()]
		)
	)
	var stock: Array = []
	for id in s.economy.inv:
		if s.economy.inv[id] > 0:
			var cap: int = s.economy.caps.get(id, 0)
			stock.append(
				(
					"%s %d%s (%+.1f/s)"
					% [Data.ITEMS[id]["name"], s.economy.inv[id], "/%d" % cap if cap > 0 else "", s.economy.rate(id)]
				)
			)
	out.append("STOCK: " + (", ".join(stock) if not stock.is_empty() else "nothing"))
	if not s.hauling.auto.is_empty():
		out.append("DEPOTS (haulers standing at each against what it wants): " + "; ".join(_depots(s)))
	var groups := {}
	for b in s.town.buildings:
		var key: String = Data.BUILDINGS[b["type"]]["name"]
		if b.get("focus", "") != "":
			key += " for " + b["focus"]
		var note: String = (
			b["alert"] if b.get("alert", "") != "" else str(b.get("status", "")).get_slice(".", 0).left(40)
		)
		if note.begins_with("Needs ") and not note.begins_with("Needs road"):
			note += _wait_note(s, b)  # and why it still waits (scripts/wait_why.gd)
		if note != "":
			key += " [" + note + "]"
		groups[key] = groups.get(key, []) + ["(%d,%d)" % [b["pos"].x, b["pos"].y]]
	var rows: Array = []
	for key in groups:
		rows.append("%s x%d: %s" % [key, groups[key].size(), " ".join(groups[key])])
	out.append("BUILDINGS:\n  " + ("\n  ".join(rows) if not rows.is_empty() else "none"))
	if s.livewire.has_board(s):
		var rules: Array = []
		for i in s.livewire.orders.size():
			rules.append(
				"%d) %s [%s]" % [i, s.livewire.text(s.livewire.orders[i]), s.livewire.last_firing(s.livewire.orders[i])]
			)
		out.append(
			(
				"ORDERS (%d of %d slots): %s"
				% [s.livewire.orders.size(), s.livewire.slots(s), "; ".join(rules) if not rules.is_empty() else "none"]
			)
		)
	var can: Array = []
	for type in Data.BUILDINGS:
		if type != "camp" and s.town.unlocked(type):
			var cost: Array = []
			for id in s.town.price(type):
				cost.append("%d %s" % [s.town.price(type)[id], id])
			can.append("%s (%s)" % [type, ", ".join(cost)])
	out.append("BUILDABLE (type ids): " + ", ".join(can))
	var ready: Array = []
	for t in s.tech_tree.ready_list():
		var cost: Array = []
		for id in s.tech_tree.cost_of(t):
			cost.append("%d %s" % [s.tech_tree.cost_of(t)[id], id])
		ready.append("%s = %s (%s)" % [t, Data.TECHS[t]["name"], ", ".join(cost)])
	out.append("RESEARCHABLE NOW: " + (", ".join(ready) if not ready.is_empty() else "nothing you can pay for"))
	var later: Array = []
	for tech in Data.TECH_ORDER:
		if s.tech_tree.researched.has(tech) or not s.tech_tree.tech_visible(tech) or s.tech_tree.can_research(tech):
			continue
		if not s.tech_tree.enabled(tech) or not s.tech_tree.requirements_met(tech):
			continue
		var short: Array = []
		for id in s.tech_tree.cost_of(tech):
			var want: int = s.tech_tree.cost_of(tech)[id]
			if s.economy.inv.get(id, 0) < want:
				short.append("%d %s (have %d)" % [want, id, s.economy.inv.get(id, 0)])
		later.append("%s = %s, short of %s" % [tech, Data.TECHS[tech]["name"], ", ".join(short)])
	if not later.is_empty():
		out.append("OPEN BUT NOT YET AFFORDABLE: " + "; ".join(later))
	if s.tech_tree.goal != "":
		out.append("RESEARCH GOAL: %s, queue %s" % [s.tech_tree.goal, str(s.tech_tree.queue)])
	return out


## The seen part of the map, one character a tile; the legend comes after it.
static func _map(s) -> String:
	var legend := {}
	var used := {".": true}
	var rows: Array = []
	var built := {}
	for b in s.town.buildings:
		built[b["pos"]] = b["type"]
	for y in s.world.height:
		var row := ""
		for x in s.world.width:
			var p := Vector2i(x, y)
			if not s.fog.is_revealed(p):
				row += " "
				continue
			var key: String = (
				("B:" + built[p]) if built.has(p) else ("road" if s.world.roads.has(p) else s.world.tile_at(p))
			)
			if key == "grass" or key == "":
				row += "."
				continue
			if not legend.has(key):
				var base: String = key.substr(2).to_upper() if key.begins_with("B:") else key
				var ch := ""
				for c in base + "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ":
					if not used.has(c) and c != " ":
						ch = c
						break
				used[ch] = true
				legend[key] = ch
			row += legend[key]
		rows.append(row)
	var key_lines: Array = []
	for k in legend:
		key_lines.append("%s = %s" % [legend[k], k.substr(2) if k.begins_with("B:") else k])
	var ruler := "    "
	for x in s.world.width:
		ruler += str(x % 10)
	for y in rows.size():
		rows[y] = "%2d  %s" % [y, rows[y]]
	return (
		"MAP (x across, y down; the digits are each column's last digit; blank = unseen, . = open grass):\n%s\n%s\nLEGEND: %s"
		% [ruler, "\n".join(rows), ", ".join(key_lines)]
	)


## " · hauler on the way": the short reason a workshop short of an input still waits for it, "" when it is not.
static func _wait_note(s, b: Dictionary) -> String:
	var recipe := Buildings.recipe_in(b)
	var item := WaitWhy.missing(s, b, recipe)
	return "" if item == "" else " · " + WaitWhy.SHORT[WaitWhy.of(s, b, item)["code"]]
